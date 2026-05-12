# Debug Workflow — /autoresearch_debug

Autonomous bug-hunting loop applying the scientific method iteratively. Hypothesize → Test → Prove/Disprove → Log → Repeat. Every finding needs code evidence.

## Architecture

```
/autoresearch_debug
  ├── Phase 1: Gather (symptoms + context)
  ├── Phase 2: Reconnaissance (scan codebase, map error surface)
  ├── Phase 3: Hypothesize (form falsifiable hypothesis)
  ├── Phase 4: Test (run experiment to prove/disprove)
  ├── Phase 5: Classify (bug found / hypothesis disproven / inconclusive)
  ├── Phase 6: Log (record finding or elimination)
  └── Phase 7: Repeat (next hypothesis, next vector)
```

## Phase 1: Gather — Symptoms & Context

Collect everything known before investigating.

**If user provides symptoms:** Expected vs actual behavior, error messages, stack traces, reproduction steps, environment.

**If no symptoms (autonomous hunting):** Run existing test suite, linter, type checker, build — collect all failures as the initial error surface.

## Phase 2: Reconnaissance — Map the Error Surface

Run all available error detection:
```bash
npm test 2>&1 | grep -E "FAIL|Error"    # test failures
npx tsc --noEmit 2>&1 | grep "error"    # type errors
npx eslint src/ 2>&1 | grep "error"     # lint errors
npm run build 2>&1 | grep "error"       # build errors
```

Prioritize errors by: frequency × user impact × fixability.

## Phase 3: Hypothesize — Form Falsifiable Hypothesis

**Format:** "I think [ROOT CAUSE] because [EVIDENCE]. If I [TEST ACTION], I should see [EXPECTED RESULT]."

**Cognitive bias guards:**
- Confirmation bias: Actively search for evidence that DISPROVES the hypothesis
- Anchoring: Don't lock onto the first plausible cause — generate 2+ hypotheses
- Survivorship: Check eliminated hypotheses too — combining a near-miss with new evidence often works

## Phase 4: Test — Run Experiment

Apply a minimal change to test the hypothesis (add logging, change one condition, add assertion). Run the specific test/scenario that reproduces the bug. Record actual vs expected output.

## Phase 5: Classify — What Did We Learn?

| Outcome | Meaning | Next Step |
|---------|---------|-----------|
| **Confirmed** | Bug root cause identified with code evidence | Log finding, move to next bug |
| **Disproven** | Hypothesis wrong — valuable elimination | Log elimination, try alternative hypothesis |
| **Inconclusive** | Can't reproduce or need more data | Narrow scope, add instrumentation, try different technique |

## Phase 6: Log — Record Everything

Every finding needs: file:line evidence, reproduction steps, severity (Critical/High/Medium/Low), OWASP/STRIDE category if security-related.

Every elimination needs: hypothesis stated, what disproved it, what was learned.

## Phase 7: Repeat — Next Investigation

If bugs remain: pick next highest-priority error, form new hypothesis, repeat.
If error surface exhausted: print summary, stop.
If bounded iterations reached: print findings, stop.

## Flags

| Flag | Purpose |
|------|---------|
| `--fix` | After finding bugs, auto-switch to fix mode (equivalent to `--chain fix`) |
| `--scope <glob>` | Limit investigation to specific files |
| `--symptom "<text>"` | Pre-fill symptom |
| `--severity <level>` | Minimum severity to report (critical/high/medium/low) |
| `--technique <name>` | Force specific technique: binary-search, differential, minimal-reproduction, trace, pattern-search, working-backwards, rubber-duck |
| `--chain <targets>` | Chain to downstream commands |

## Composite Metric

```
debug_score = bugs_found * 15
            + hypotheses_tested * 3
            + (files_investigated / files_in_scope) * 40
            + (techniques_used / 7) * 10
```

Higher = more thorough.

## Investigation Techniques (Quick Reference)

| Technique | How |
|-----------|-----|
| Binary Search | Comment out half the suspicious code. Bug disappears → in that half. Repeat. |
| Differential | Compare working vs broken: `git stash` / `git bisect` |
| Minimal Reproduction | Strip away everything until smallest case reproduces bug |
| Trace Execution | Add strategic logging at data flow points |
| Pattern Search | Found one bug → grep for same anti-pattern across codebase |
| Working Backwards | Start from error output, trace backward to divergence point |
| Rubber Duck | Explain code line by line — the act of explaining reveals bad assumptions |

See `references/common-setup.md` for shared setup/flags/chains. See `references/common-chains.md` for debug→fix pipeline.
