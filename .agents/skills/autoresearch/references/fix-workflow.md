# Fix Workflow — $autoresearch fix

Autonomous fix loop that takes a broken state and iteratively repairs it until everything passes. One fix per iteration. Atomic, committed, verified, auto-reverted on failure.

## Architecture

```
$autoresearch fix
  ├── Phase 1: Detect (what's broken?)
  ├── Phase 2: Prioritize (fix order)
  ├── Phase 3: Fix ONE thing (atomic change)
  ├── Phase 4: Commit (before verification)
  ├── Phase 5: Verify (did error count decrease?)
  ├── Phase 6: Guard (did anything else break?)
  ├── Phase 7: Decide (keep / revert / rework)
  └── Phase 8: Log & Repeat
```

## Phase 1: Detect — What's Broken?

Auto-detect the failure domain. Run available error detection:
- Test runner (jest, pytest, vitest, go test, cargo test)
- Type checker (tsc --noEmit, mypy, pyright)
- Linter (eslint, ruff, clippy)
- Build command
- Debug findings (if debug/{latest}/findings.md exists)
- CI failures (if .github/workflows/ exists)

Run build first — if build fails, type/test/lint results are unreliable.

## Phase 2: Prioritize — Fix Order

| Priority | Category | Why First |
|----------|----------|-----------|
| 1 | Build failures | Nothing works if it doesn't compile |
| 2 | Critical/High bugs | From debug findings — data loss, security |
| 3 | Type errors | Type safety prevents cascading bugs |
| 4 | Test failures | Tests verify correctness |
| 5 | Medium/Low bugs | From debug findings |
| 6 | Lint errors | Code quality |
| 7 | Warnings | Polish |

Within a category: cascading impact → simplicity → file locality.

## Phase 3: Fix ONE Thing — Atomic Change

One fix per iteration. Fix the IMPLEMENTATION, not the test (unless the test is genuinely wrong).

**Never do:**
- Add `@ts-ignore`, `eslint-disable`, `# type: ignore`
- Use `any` type escape hatch
- Delete or skip failing tests
- `catch (e) {}` empty catch blocks
- Comment out broken code

**Fix strategies by category:**
| Category | Strategy |
|----------|----------|
| Build failure | Fix the exact line/import/config causing failure |
| Type error | Add proper types, fix signatures, handle null cases |
| Test failure | Read test + implementation, find mismatch |
| Lint error | Apply the rule — auto-fix where possible |
| Bug (from debug) | Apply suggested fix from findings.md |

## Phase 4: Commit — Before Verification

```bash
git add <modified-files>
git commit -m "fix: [what was fixed] — [file:line]"
```

## Phase 5: Verify — Did It Help?

Re-run Phase 1 detection and compare:
```
delta = previous_error_count - current_error_count
```
Expected: `delta > 0` (fewer errors).

## Phase 6: Guard — Did Anything Else Break?

If guard command specified, run it. Guard prevents regressions (e.g. fixing a type error shouldn't break tests).

## Phase 7: Decide — Keep, Revert, or Rework

| Condition | Action | TSV Status |
|-----------|--------|-----------|
| `delta > 0` AND guard passes | **KEEP** | fixed |
| `delta > 0` AND guard fails | **REWORK** (max 2) | rework |
| `delta == 0` | **DISCARD** | discard |
| `delta < 0` | **DISCARD** immediately | discard |
| Crash during fix | **RECOVER** (max 3) | recover |
| 3rd attempt fails | **SKIP** → blocked.md | blocked |

## Phase 8: Log & Repeat

Log to `fix-results.tsv` format:
```tsv
iteration	category	target	delta	guard	status	description
```

**Stop conditions:**
- Zero errors remaining → "All Clear — Zero Errors"
- All items fixed or blocked → print summary
- Bounded iterations exhausted → print summary

## Fix Session State Machine

```
DETECTING → PRIORITIZING → FIXING → VERIFYING → DECIDING → [DONE | LOOP]
```

## Flags

| Flag | Purpose |
|------|---------|
| `--target <command>` | Explicit verify command |
| `--guard <command>` | Safety command |
| `--scope <glob>` | Limit fixes to specific files |
| `--category <type>` | Only fix: test, type, lint, build, bug |
| `--skip-lint` | Don't fix lint errors |
| `--from-debug` | Read findings from latest debug/ session |

## Composite Metric

```
fix_score = reduction_score + quality_score + bonus_score
reduction_score = ((baseline_errors - current_errors) / baseline_errors) * 60
quality_score = +25 for zero anti-patterns, -5 per anti-pattern used
bonus_score = +10 zero lint, +5 guard never failed
```

See `references/common-setup.md` for shared setup/flags/chains.
