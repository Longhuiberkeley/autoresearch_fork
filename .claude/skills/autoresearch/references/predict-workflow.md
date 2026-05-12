# Predict Workflow — /autoresearch:predict

Multi-perspective code analysis using swarm intelligence. Simulates 3-5 expert personas that independently analyze code, debate findings, and reach consensus. Zero external dependencies.

## Architecture

```
/autoresearch:predict
  ├── Phase 1: Setup — Configuration
  ├── Phase 2: Reconnaissance — Build knowledge files (codebase analysis, dependency map, component clusters)
  ├── Phase 3: Persona Generation — Create 3-5 expert personas from codebase context
  ├── Phase 4: Independent Analysis — Each persona analyzes from their unique perspective
  ├── Phase 5: Debate — 1-2 rounds of structured cross-examination
  ├── Phase 6: Consensus — Synthesizer aggregation with anti-herd check
  ├── Phase 7: Report — Generate output files
  └── Phase 8: Handoff — Write handoff.json for optional --chain
```

## Phase 2: Reconnaissance — Knowledge Files

Build these .md files as the knowledge graph (zero external deps):

| File | Content |
|------|---------|
| Functions | Function signatures, responsibilities, complexity |
| Classes & Types | Class hierarchy, interfaces, type relationships |
| Routes / Endpoints | Endpoint catalog with method, path, handler |
| Models / Database | Schema, relationships, migrations |
| Import Graph | Module dependencies and coupling |
| Call Graph | Function call relationships |
| Data Flows | How data moves through the system |
| Clusters | Related component groups |

Git-hash stamping: every output embeds commit SHA for staleness detection. Incremental: only re-analyze files changed since last run.

## Phase 3: Persona Generation

Default persona set (3-5 from these):
- **Architecture Reviewer** — structure, coupling, SOLID principles
- **Security Analyst** — vulnerabilities, attack surface, auth flows
- **Performance Engineer** — bottlenecks, memory, I/O
- **Reliability Engineer** — error handling, edge cases, failover
- **Devil's Advocate** — mandatory, challenges every finding, prevents groupthink

Adversarial set (`--adversarial`): Red Team, Blue Team, Insider Threat, Supply Chain, Judge.

## Phase 4: Independent Analysis

Each persona analyzes knowledge files cold-start (no shared context). Finds issues in their domain, assigns severity (Critical/High/Medium/Low) and confidence (High/Medium/Low). Every finding needs code evidence (file:line).

## Phase 5: Debate

1-2 rounds of cross-examination. Each persona reviews all others' findings. Challenges with counter-evidence. Devil's Advocate must challenge at least one finding per persona.

## Phase 6: Consensus

Synthesizer aggregates findings with confidence scores:
- Confirmed: ≥4/5 personas agree
- Probable: 3/5 agree
- Contested: split vote
- Minority preserved: solo dissenter findings kept (anti-herd)

Anti-herd check: flip rate + entropy tracked across rounds. Groupthink detected if zero challenges in a round.

## Phase 7: Report

Output: `predict/{YYMMDD}-{HHMM}-{slug}/` containing:
- `overview.md` — executive summary
- `codebase-analysis.md` — full analysis
- `dependency-map.md` — dependency graph
- `component-clusters.md` — related groups
- `persona-debates.md` — debate transcripts
- `hypothesis-queue.md` — ranked hypotheses for investigation
- `findings.md` — all findings with severity and evidence
- `predict-results.tsv` — iteration log
- `handoff.json` — structured output for --chain

## Phase 8: Handoff

`handoff.json` contains: all confirmed/probable findings with location, severity, confidence, personas agreed, and structured hypotheses. Used by chain targets.

## Flags

| Flag | Purpose |
|------|---------|
| `--chain <targets>` | Chain to downstream tools |
| `--personas N` | Persona count (default: 5, range: 3-8) |
| `--rounds N` | Debate rounds (default: 2, range: 1-3) |
| `--depth <level>` | shallow (3p, 1r), standard (5p, 2r), deep (8p, 3r) |
| `--adversarial` | Use adversarial persona set |
| `--budget <N>` | Max total findings (default: 40) |
| `--fail-on <severity>` | Exit non-zero at severity threshold (CI/CD) |
| `--scope <glob>` | Limit analysis scope |

## Composite Metric

```
predict_score = findings_confirmed*15 + findings_probable*8 + minority_preserved*3
              + (personas/total)*20 + (rounds/planned)*10 + anti_herd_passed*5
```

See `references/common-setup.md` for shared setup/flags. See `references/common-chains.md` for chain patterns.
