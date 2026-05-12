# Context Rotation Protocol

Protocol for running the autoresearch loop with fresh-context subagent workers per iteration. Prevents context window bloat and model degradation during long unbounded runs.

## When to Use

Enable when:
- Unbounded runs exceed ~30 iterations (context exceeding ~100k tokens)
- Working with large files where each read adds significant context
- Using models known to degrade after large context windows (many open-source models)
- Running overnight or multi-hour autonomous sessions

## Architecture

```
┌──────────────────────────────────────────────────┐
│  ORCHESTRATOR (persistent, stays ~5k tokens)      │
│  - SKILL.md + common-setup.md loaded once          │
│  - Manages state.json + results.tsv                │
│  - Reads git log to learn patterns                 │
│  - Ideates next experiment (Phase 2)               │
│  - Spawns worker subagent per iteration            │
│  - Keep/discard/log/repeat (Phases 6-8)            │
│                                                     │
│  ┌─────────────────────────────────────┐           │
│  │  WORKER SUBAGENT (fresh per iter)   │  × N     │
│  │  Receives: experiment description +  │           │
│  │    file paths + verify command       │           │
│  │  Reads in-scope files fresh          │           │
│  │  Makes ONE atomic change, commits    │           │
│  │  Runs verify, extracts metric        │           │
│  │  Runs guard (if configured)          │           │
│  │  Returns structured result           │           │
│  └─────────────────────────────────────┘           │
└──────────────────────────────────────────────────┘
```

## Enabling

Add to inline config:

```
Context-Mode: fresh
```

Or via environment:

```bash
export AUTORESEARCH_CONTEXT_MODE=fresh
```

Default is `inline` (current behavior — orchestrator does everything in one session).

## Orchestrator Responsibilities

The orchestrator is the decision engine. It NEVER reads in-scope files directly. Instead:

### Phase 0: Precondition Checks
Same as inline mode — verify git repo, clean tree, no detached HEAD.
Additionally: verify worker subagent is available (Agent/Task tool exists).

### Phase 0.5: Initialize State
Create `autoresearch-state.json` (committed to git). This is the **canonical schema** referenced by `results-logging.md` and `autonomous-loop-protocol.md`:

```json
{
  "config": {
    "goal": "<user goal>",
    "scope": "<file globs>",
    "metric": "<metric name>",
    "verify": "<shell command>",
    "guard": "<shell command or null>",
    "guard_direction": "lower|higher|null",
    "guard_threshold": "<percent or null>",
    "direction": "higher|lower",
    "max_iterations": "<int or null>",
    "plateau_patience": "<int or \"off\">",
    "noise_floor": "<number or null>"
  },
  "state": {
    "iteration": 0,
    "baseline_metric": "<number>",
    "best_metric": "<number>",
    "best_iteration": 0,
    "iterations_since_best": 0,
    "consecutive_discards": 0,
    "context_mode": "fresh"
  },
  "patterns": {
    "successes": [],
    "failures": []
  }
}
```

**Field notes:**
- `config.max_iterations` — `null` for unbounded mode; integer N when `Iterations: N` is set.
- `config.plateau_patience` — defaults to 15; `"off"` disables plateau detection (unbounded mode only).
- `config.noise_floor` — minimum absolute delta to treat as a real change (avoids noise-driven discards). `null` means use the per-metric default.
- All `config.*` fields are write-once at Phase 0.5 and immutable for the rest of the run.
- All `state.*` fields are updated every iteration in Phase 7.

### Phase 1: Review
The orchestrator does NOT read in-scope files. Instead it reads:
1. `autoresearch-state.json` — current iteration, best metric, patterns
2. `autoresearch-results.tsv` — last 10-20 entries for pattern recognition
3. `git log --oneline -20` — experiment sequence (kept vs reverted)
4. `git log --oneline -20 --diff-filter=M --name-only | sort | uniq -c | sort -rn` — which files drive improvements

This is ~1-2k tokens of reading, not ~20-50k as in inline mode.

### Phase 2: Ideate
Based on patterns from git history and results log:
- Exploit successes (same file, similar pattern)
- Avoid reverted approaches (query git log for prior reverts)
- Try new approaches when success patterns stall

Write the experiment description in ONE sentence.

### Phase 3: Dispatch Worker (replaces inline Modify)
Spawn worker subagent with a structured prompt (see Worker Prompt Template below).
The worker prompt is ~500-800 tokens plus the experiment description.

### Phase 6: Decide
Worker returns structured result:
```
METRIC: <number>
GUARD: pass|fail|<number if metric-valued>
COMMIT: <hash or "none">
NOTE: <one sentence explanation>
```

The orchestrator applies the same decision logic as inline mode:
- Metric improved + guard passes → KEEP → update state.json
- Metric improved + guard fails → rework (max 2 attempts)
- Metric same/worse → DISCARD → `git revert`
- Worker crashed → retry (max 3) or log crash

### Phase 7: Log
Update `autoresearch-results.tsv` AND `autoresearch-state.json`.
State.json is committed to git so fresh sessions can resume.

### Phase 8: Repeat
If bounded and `current_iteration >= max_iterations`, stop.
If plateau detected (15 iterations without new best), pause and ask user.
Otherwise, continue to Phase 1.

## Worker Subagent Specification

### Claude Code Worker

Defined in `.claude/agents/autoresearch-worker.md` with:
- `tools`: Read, Write, Edit, Bash
- `model`: inherit (uses parent session's model)
- `maxTurns`: 15 (enough for read → edit → commit → verify → guard → report)
- `background`: false (orchestrator waits for result)

### OpenCode Worker

Defined in `.opencode/agents/autoresearch-worker.md` with:
- `mode: subagent`, `hidden: true`
- `tools: bash, read, write, edit`
- Spawned via `task(subagent_type="general")`

### Worker Prompt Template

The orchestrator constructs this prompt for each iteration:

```
You are an autoresearch worker agent. Make exactly ONE atomic change.

CONFIGURATION:
Goal: {goal}
Scope: {file paths comma-separated}
Verify: {verify_command}
Guard: {guard_command or "none"}
Direction: {higher|lower} is better

EXPERIMENT:
{one-sentence experiment description}

STEPS:
1. Read the specified scope files
2. Make exactly ONE change to implement the experiment
3. Run: git add <files> && git commit -m "experiment(<scope>): <description>"
4. Run the verify command and extract the metric number
5. If guard is set, run the guard command (exit 0 = pass)
6. Return EXACTLY this format (no other text):

METRIC: <number>
GUARD: pass|fail
COMMIT: <short hash>
NOTE: <one sentence>
```

## Context Budget Analysis

| Component | Inline Mode (tokens) | Fresh Mode (tokens) |
|-----------|---------------------|---------------------|
| SKILL.md + refs | 8,000 | 8,000 (orchestrator only) |
| Per-iteration file reads | 10,000-30,000 | 0 (orchestrator) |
| Git log review | 500 | 500 |
| Results log review | 500 | 500 |
| Worker prompt | 0 | 800 per iteration |
| Worker file reads | 0 | 5,000-15,000 (worker context) |
| **Total after 50 iterations** | **400,000-800,000** | **~12,000 (orchestrator)** |

The orchestrator stays under ~12k tokens permanently. Worker context is 500-15k tokens per invocation and is discarded after each iteration.

## State File Persistence

`autoresearch-state.json` is committed to git (unlike `autoresearch-results.tsv` which is gitignored). This enables:

- **Session resume**: Fresh Claude/OpenCode session reads state.json + git log, reconstructs situational awareness, continues from last iteration
- **Crash recovery**: If the orchestrator session dies, state.json captures the last known-good state
- **Human inspection**: User can read state.json to understand loop progress without parsing TSV

Update state.json after every iteration (Phase 7). The file is always append-updated (fields change, structure stays the same).

## Resume Protocol

When the user starts a new session and wants to resume:

```
$autoresearch --resume
```

The orchestrator:
1. Reads `autoresearch-state.json` to get config + current state
2. Reads `git log --oneline -20` to see experiments since last state update
3. Reads `autoresearch-results.tsv` tail for iteration context
4. Reconstructs: current iteration, best metric, patterns, plateau tracking
5. Continues loop from Phase 1

If state.json is missing or corrupted, fall back to git-only reconstruction (readable but less precise).

## Platform Compatibility Notes

### Claude Code
- Worker invoked via Codex subagent: `Agent(description="...", prompt="...", subagent_type="autoresearch-worker")`
- Subagent `.claude/agents/autoresearch-worker.md` must be present
- Agent tool passes structured output back to orchestrator

### OpenCode
- Worker invoked via `task` tool: `task(description="...", prompt="...", subagent_type="general")`
- Subagent `.opencode/agents/autoresearch-worker.md` defines tool permissions
- Worker returns text output; orchestrator parses the structured format
