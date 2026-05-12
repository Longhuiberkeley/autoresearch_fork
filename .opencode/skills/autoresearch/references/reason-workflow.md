# Reason Workflow — /autoresearch_reason

Isolated multi-agent adversarial refinement loop. Generates, critiques, synthesizes, and blind-judges outputs through repeated rounds until convergence. Extends autoresearch to subjective domains where no objective metric exists — the blind judge panel IS the fitness function.

## Modes

| Mode | Behavior |
|------|----------|
| `convergent` (default) | Stop when incumbent wins `--convergence` consecutive rounds |
| `creative` | Never auto-stop — generate diverse candidates, no convergence gate |
| `debate` | No synthesis step, judges evaluate A vs B directly |

## Architecture

```
/autoresearch_reason
  ├── Phase 1: Setup — Config validation + output directory
  ├── Phase 2: Generate-A — Author-A produces first candidate (cold-start)
  ├── Phase 3: Critic — Adversarial attack on A (min 3 weaknesses)
  ├── Phase 4: Generate-B — Author-B sees task+A+critique, produces B
  ├── Phase 5: Synthesize-AB — Synthesizer produces AB from task+A+B (skipped in debate mode)
  ├── Phase 6: Judge Panel — N blind judges pick winner (randomized labels X/Y/Z)
  ├── Phase 7: Convergence Check — Stop if incumbent wins N consecutive rounds
  └── Phase 8: Handoff — Write lineage files, optional --chain
```

## Context Isolation (Critical)

Every agent is a cold-start fresh invocation:
- Author-A: sees only the task (Round 1) or task + incumbent (Round 2+)
- Critic: sees only candidate A — NOT the task, NOT prior rounds
- Author-B: sees task + A + critique only — NOT prior rounds
- Synthesizer: sees task + A + B only — NOT critique, NOT judge history
- Judges: see randomized labels (X/Y/Z), never A/B/AB

No shared session between agents. Prevents sycophancy and anchoring.

## Phase 2: Generate-A

Round 1: cold-start from task only. Round 2+: receives incumbent, role is to BUILD ON and IMPROVE it.

## Phase 3: Critic

Receives ONLY candidate A. Must find minimum 3 distinct weaknesses, each rated FATAL/MAJOR/MINOR, with specific references. No fixes offered — only attack.

## Phase 4: Generate-B

Receives task + A + critique. Produces BETTER candidate, addressing FATAL and MAJOR weaknesses while preserving A's strengths. Must be substantively different from A.

## Phase 5: Synthesize-AB

Receives task + A + B (no critique). Produces AB: identifies strengths of each, combines best elements, resolves contradictions. Must read as a single coherent response. Skipped in `--mode debate`.

## Phase 6: Judge Panel — Blind Evaluation

N judges (default 3, range 3-7, odd preferred). Candidates get randomized labels (X, Y, Z) each round — prevents "synthesis is always better" anchoring. Judges pick winner; majority vote wins.

## Phase 7: Convergence Check

- Incumbent wins N consecutive rounds (default: 3) → converged → stop
- Oscillation detection: incumbent changes 5+ times without consecutive wins → forced stop + flag
- Bounded mode: stop after `--iterations N` rounds regardless

## Phase 8: Handoff

Write `reason/{YYMMDD}-{HHMM}-{slug}/` with: `overview.md`, `lineage.md`, `candidates.md`, `judge-transcripts.md`, `reason-results.tsv`, `reason-lineage.jsonl`, `handoff.json`.

## Flags

| Flag | Purpose |
|------|---------|
| `--iterations N` | Bounded rounds |
| `--judges N` | Judge count (3-7, odd preferred, default: 3) |
| `--convergence N` | Consecutive wins to converge (2-5, default: 3) |
| `--mode <mode>` | convergent (default), creative, debate |
| `--domain <type>` | software, product, business, security, research, content |
| `--chain <targets>` | Chain to downstream tools |
| `--judge-personas <list>` | Override default judge personas |
| `--no-synthesis` | Skip synthesis (A vs B only, alias for `--mode debate`) |

## Composite Metric

```
reason_score = quality_delta*30 + rounds_survived*5 + judge_consensus*20
             + critic_fatals_addressed*15 + convergence*10 + no_oscillation*5
```

See `references/common-setup.md` for shared setup/flags/chains.
