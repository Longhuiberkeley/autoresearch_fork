# Probe Workflow — $autoresearch probe

Adversarial multi-persona requirement & assumption interrogation engine. Probes user and codebase through 8 personas until net-new constraints per round drop below a threshold (mechanical saturation), then emits the 5 autoresearch primitives ready to feed any other autoresearch command.

## Architecture

```
$autoresearch probe
  ├── Phase 1:  Seed Capture (parse topic, tokenize actors/actions/scope hints)
  ├── Phase 2:  Persona Activation (pick N personas from 8 defaults)
  ├── Phase 3:  Codebase Grounding (scan --scope for prior art)
  ├── Phase 4:  Round Generation (each persona drafts 1-2 questions)
  ├── Phase 5:  Question Synthesis (dedupe + batch ≤5 q/round)
  ├── Phase 6:  Answer Capture (single batched user input)
  ├── Phase 7:  Constraint Extraction (classify into 7 atom types)
  ├── Phase 8:  Cross-Check (validate vs codebase + prior answers)
  ├── Phase 9:  Saturation Check (net-new < threshold for K rounds)
  └── Phase 10: Synthesize & Handoff (emit config + optional --chain)
```

## The 8 Personas

| # | Persona | Focus |
|---|---------|-------|
| 1 | Skeptic | "What if the opposite is true?" |
| 2 | Edge-Case Hunter | Boundaries, null/empty/max, off-by-one |
| 3 | Scope Sentinel | Forces explicit in/out-of-scope boundaries |
| 4 | Ambiguity Detective | Surfaces vague terms needing atomic definition |
| 5 | Contradiction Finder | Detects internal inconsistencies |
| 6 | Prior-Art Investigator | "Has this been tried? What broke?" |
| 7 | Success-Criteria Auditor | Forces mechanical success definitions |
| 8 | Constraint Excavator | Non-obvious constraints (perf, compliance, infra) |

`--adversarial` rotates Skeptic + Contradiction Finder + Edge-Case Hunter to front.

## Phase 1: Seed Capture

Parse topic. Tokenize: actor, action, object, scope hints. Topics with <2 scope hints → Constraint Excavator asks about implicit constraints first.

## Phase 3: Codebase Grounding

Scan --scope glob. Build prior-art ledger: data model constraints, API contracts, implicit design decisions, known limitations (TODOs/FIXMEs), performance envelopes. Each persona reads ledger before generating questions. MANDATORY — prevents asking already-answered questions.

## Phase 4-5: Round Generation + Synthesis

Each persona drafts 1-2 candidate questions (cold-start, no cross-persona visibility). Synthesis: semantic dedupe → drop already-answered → ledger filter → cap at ≤5 questions per round.

## Phase 6: Answer Capture

Single batched direct prompting with ≤5 synthesized questions. Interactive mode (default) or autonomous mode (`--mode autonomous` — self-answers with confidence levels: high/med/low).

## Phase 7: Constraint Extraction

Classify atoms into 7 types: Requirement, Assumption, Constraint, Risk, Out-of-scope, Ambiguity, Contradiction. Ambiguities are re-queued to next round with sharper prompts.

## Phase 9: Saturation Check

Net-new constraint count windowed over K=3 rounds. If net-new < threshold (default 2) for K consecutive rounds → SATURATED.

## Phase 10: Synthesize & Handoff

Emit: `probe-spec.md`, `constraints.tsv`, `autoresearch-config.yml`, `summary.md`, `handoff.json`. If `--chain`, sequential downstream invocations.

## Stop Conditions

- SATURATED (net-new < threshold for K rounds)
- BOUNDED (Iterations exhausted)
- USER_INTERRUPT (Ctrl+C — persists completed round atoms)
- SCOPE_LOCKED (all atoms classified out-of-scope for 2 rounds)

## Flags

| Flag | Purpose |
|------|---------|
| `--depth <level>` | shallow (5), standard (15), deep (30) |
| `--personas N` | Active persona count (3-8, default: 6) |
| `--saturation-threshold N` | Net-new atoms threshold (default: 2) |
| `--scope <glob>` | Codebase glob for Phase 3 grounding |
| `--chain <targets>` | Downstream commands |
| `--mode <mode>` | interactive (default) or autonomous |
| `--adversarial` | Rotate adversarial personas to front |

## Composite Metric

```
probe_score = constraints_extracted*10 + contradictions_resolved*25
            + hidden_assumptions_surfaced*20 + ambiguities_clarified*15
            + (dimensions_covered/total)*30 + (saturated?100:0) + (config_complete?50:0)
```

See `references/common-setup.md` for shared setup/flags/chains.
