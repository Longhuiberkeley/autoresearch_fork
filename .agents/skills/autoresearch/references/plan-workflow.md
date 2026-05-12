# Plan Workflow — $autoresearch plan

Convert a textual goal into a validated, ready-to-execute autoresearch configuration.

**Output:** A complete `$autoresearch` invocation with Scope, Metric, Direction, and Verify — all validated before launch.

## Architecture

```
$autoresearch plan
  ├── Phase 1: Capture Goal
  ├── Phase 2: Analyze Context (scan codebase for tooling)
  ├── Phase 3: Define Scope (suggest globs, validate ≥1 file)
  ├── Phase 4: Define Metric (must be mechanical number)
  ├── Phase 4.5: Define Guard (optional regression prevention)
  ├── Phase 5: Define Direction (higher/lower is better)
  ├── Phase 6: Define Verify Command (dry-run validate)
  └── Phase 7: Confirm & Launch
```

## Phase 1: Capture Goal

If no goal provided inline, ask user: "What do you want to improve? Describe your goal in plain language." Offer smart defaults: Code quality, Performance, Content, Refactoring.

## Phase 2: Analyze Context

Read codebase structure (package.json, project files, test config). Identify domain (backend, frontend, ML, content, DevOps). Detect existing tooling (test runner, linter, bundler, benchmark scripts). Infer likely metric candidates.

## Phase 3: Define Scope

Suggest scope globs based on codebase analysis. Validate they resolve to ≥1 file. Warn if >50 files. Warn if scope mixes test files AND source files.

## Phase 4: Define Metric

**Critical:** Metric must be mechanical — extractable from a command output as a single number.

| Check | Pass | Fail |
|-------|------|------|
| Outputs a number | `87.3`, `0.95`, `42` | `PASS`, `looks good` |
| Extractable by command | `grep`, `awk`, `jq` | Requires human judgment |
| Deterministic | Same input → same output | Random, flaky |
| Fast | < 30 seconds | > 2 minutes |

If metric fails validation, explain why and suggest alternatives. **Do not proceed until metric is mechanical.**

### Metric Suggestion Database

| Domain | Metric | Verify Template |
|--------|--------|----------------|
| Test coverage | Coverage % | `{test_runner} --coverage \| grep "All files" \| awk '{print $4}'` |
| Type safety | `any` count | `grep -r ":\s*any" {scope} --include="*.ts" \| wc -l` |
| Bundle size | Bytes | `{build_cmd} \| wc -c` |
| Response time | ms | `{bench_cmd} \| grep "p95" \| awk '{print $2}'` |
| Lighthouse | Score 0-100 | `npx lighthouse {url} --output json \| jq '.categories.performance.score * 100'` |
| Reduce LOC | Line count | `{test_cmd} && find {scope} -name "*.{ext}" \| xargs wc -l \| tail -1 \| awk '{print $1}'` |

## Phase 4.5: Define Guard (Optional)

Ask if user wants a guard. Common options:

- **Tests as guard:** `{test_command}` must pass for every kept change
- **Line count guard:** Prevent bloat — reject changes growing scope lines beyond baseline + 10%
- **Metric-valued guard:** Track a number (e.g. bundle size) and reject if regresses beyond threshold
- **No guard:** Metric alone is sufficient

If metric-valued guard chosen, collect direction + threshold. Dry-run guard to confirm it passes on current codebase.

## Phase 5: Define Direction

Ask: "Higher or lower is better?"
- Higher: coverage %, test pass count, throughput, score
- Lower: error count, response time, bundle size, LOC

## Phase 6: Define Verify Command

Construct the command that runs the tool, extracts the metric as a single number, and exits 0 on success.

**MANDATORY — dry-run before accepting:**
1. Dry-run the verify command on current codebase
2. Confirm exit code 0
3. Extract metric and validate it's a number (must match `^-?[0-9]+\.?[0-9]*$`)
4. If dry-run fails → show error, help user fix pipeline, re-validate

**Common failures and fixes:**

| Extracted Value | Problem | Fix |
|---|---|---|
| `85.2%` | Trailing `%` | Add `\| tr -d '%'` |
| `342ms` | Trailing unit | Add `\| grep -oE '[0-9]+\.?[0-9]*'` |
| *(empty)* | grep matched nothing | Check grep pattern |
| Two numbers | Pipeline too broad | Add `head -1` or tighten grep |

**Verify-command safety screen:** Before dry-run, scan for `rm -rf /`, fork bombs, `curl ... | sh`, embedded credentials. Refuse/re-prompt if found.

## Phase 7: Confirm & Launch

Present complete configuration with baseline value. Ask: Launch unlimited, Launch bounded (ask for N), or Copy config only.

If Launch bounded: invoke `$autoresearch` with `Iterations: N` in inline config.

## Error Recovery

| Error | Recovery |
|---|---|
| No test runner detected | Ask user for test command |
| Verify command fails | Show error, suggest fix, re-validate |
| Metric not parseable | Suggest adding `grep`/`awk` to extract number |
| Scope resolves to 0 files | Show glob result, ask user to fix pattern |
| Scope too broad (>100 files) | Suggest narrowing |

## Flags

| Flag | Purpose |
|------|---------|
| `--chain <targets>` | Chain to downstream tool(s) after completion |

See `references/common-setup.md` for shared flags and `references/common-chains.md` for plan's chain conversion targets (predict, scenario, debug, security, reason, fix, learn, ship, probe).
