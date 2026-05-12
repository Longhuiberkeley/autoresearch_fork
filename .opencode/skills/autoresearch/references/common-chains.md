# Common Chains — Centralized Chain Pattern Library

Referenced by all subcommands. Contains every documented chain pattern. Individual reference files no longer duplicate these.

## Quick Reference Table

| Chain | When to Use |
|-------|-------------|
| `plan → loop` | Starting a new metric improvement |
| `debug → fix` | Bug is known, needs finding and fixing |
| `debug → fix → ship` | Production issue: find, fix, deploy |
| `predict → debug` | Intermittent failures, compound issues |
| `predict → security` | Pre-deployment security review |
| `predict → scenario,debug,fix` | Full quality pipeline |
| `scenario → debug` | Feature works but want edge case coverage |
| `scenario → security` | Threat modeling from user scenarios |
| `scenario → loop` | Discover use cases, then optimize |
| `security → fix → security` | Harden, fix, verify fixes |
| `loop → ship` | Optimization complete, time to deploy |
| `plan → loop → security → ship` | Full feature lifecycle |
| `fix → loop → ship` | Fix blockers, then improve, then deploy |
| `learn → security` | New codebase: document it, then audit it |
| `learn → predict` | Document, then get multi-expert analysis |
| `learn:check → learn:update` | Check health first, update if stale |
| `learn → scenario` | Document, then stress-test edge cases |
| `reason → predict` | Converge on design, then get multi-expert validation |
| `reason → plan,fix` | Debate approach, then plan and implement |
| `reason → scenario` | Converge on design, then stress-test edge cases |
| `reason → debug,fix,ship` | Full subjective pipeline: debate → validate → fix → deploy |
| `predict → reason` | Identify issues, then debate solutions |
| `scenario → reason` | Discover edge cases, then debate how to handle them |
| `probe → plan,autoresearch` | Interrogate → config → loop |
| `probe → reason` | Interrogate → debate → converge |

## How Chains Work

Each `--chain` target is a comma-separated subcommand name:

```
/autoresearch_predict --chain scenario,debug,fix
```

Execution order:
1. Current command runs to completion
2. Output artifacts (findings, handoff.json, TSV logs) are written
3. First chain target launches with prior command's output as context
4. Each subsequent target receives accumulated context from all prior stages
5. The final target's output is the pipeline's end state

## Empirical Evidence Rule

**Downstream loop results ALWAYS override upstream findings.** If a subsequent command disproves or revises a prior command's conclusion:
- Log: `[Upstream finding] REVISED by [downstream command] — [evidence]`
- Do NOT revert to the pre-loop conclusion
- The downstream loop's empirical data is authoritative

## Command-Specific Chain Handoffs

### debug → fix
```
/autoresearch_debug --fix
# Debug findings → fix --from-debug reads from latest debug/ session
```

### predict → debug
```
/autoresearch_predict --chain debug
# Predict's handoff.json contains hypothesis-queue → debug investigates each
```

### predict → security
```
/autoresearch_predict --chain security
# Predict's findings (especially Security Analyst persona) → security audit scope
```

### reason → plan
```
/autoresearch_reason --chain plan
# Converged output → plan's Goal context
```

### reason → predict
```
/autoresearch_reason --chain predict
# Converged design → multi-persona validation
```

### probe → plan
```
/autoresearch_probe --chain plan
# probe-spec.md + constraints.tsv → plan's Goal and Scope
```

### learn → predict
```
/autoresearch_learn --chain predict
# Documentation → predict's knowledge base for analysis
```
