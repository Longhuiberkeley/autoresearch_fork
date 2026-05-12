# Common Setup — Shared Protocol for All Subcommands

Extracted boilerplate referenced by all 10 subcommand workflow files. Load this first when executing any subcommand.

## Trigger Detection

Commands are activated when the user:
- Invokes the slash command directly (`/autoresearch:<command>`)
- Uses trigger phrases matching the command's domain (e.g., "debug this", "audit security")
- Provides inline config with Goal/Scope/Metric fields

## Loop Support

All subcommands support two modes:

- **Unbounded (default):** Loop until interrupted, plateau detected, or goal achieved
- **Bounded:** `Iterations: N` or `--iterations N` runs exactly N iterations then stops

When bounded, track `current_iteration` against `max_iterations`. Print final summary at end.

## Interactive Setup Gate

**CRITICAL — BLOCKING:** If a subcommand is invoked without sufficient inline context (Goal/Scope/Metric or their command-specific equivalents), you MUST collect missing context via batched `AskUserQuestion` (Claude) or `question` (OpenCode) calls BEFORE proceeding to any execution phase. Each reference file defines its command-specific questions. Never skip this gate.

## Common Flags

| Flag | Applies To | Purpose |
|------|-----------|---------|
| `--scope <glob>` | All | Limit operation to specific files |
| `--iterations N` | All | Bounded mode — exactly N iterations |
| `--chain <targets>` | All | Chain to downstream tool(s) after completion. Comma-separated (e.g., `--chain debug,fix,ship`). Spaces after commas tolerated. |

## Chain Conversion Rules

When `--chain` is specified, the current command hands off validated output to downstream commands sequentially. Each stage's output feeds the next. See `references/common-chains.md` for the full chain pattern library.

**Key rules:**
- `--fix` is equivalent to `--chain fix`
- Empirical evidence from downstream loops ALWAYS overrides upstream findings
- Chain targets receive: goal, scope, metric, direction, verify command, and any command-specific handoff artifacts

## Output Directory Convention

Most subcommands create an output directory under `{command}/{YYMMDD}-{HHMM}-{slug}/` containing structured reports, TSV logs, and summary files. The directory is printed to the user at completion:

```
{command} complete. Report saved to:
{command}/{YYMMDD}-{HHMM}-{slug}/overview.md
```

## Composite Metric

For bounded loops, each subcommand defines a composite metric that scores thoroughness. Format:

```
{command}_score = <component1> + <component2> + ...
```

Higher = more thorough. This metric is calculated and printed at loop completion, not used for keep/discard decisions (the primary metric handles that).

## Anti-Patterns (All Loops)

These shortcuts break the loop but don't fix the problem:

| Anti-Pattern | Why It's Wrong | Do This Instead |
|--------------|----------------|-----------------|
| Skip verification | No data to decide keep/discard | Always run Verify after every change |
| Make multiple unrelated changes | Can't attribute metric delta | Split into separate iterations |
| Ignore git history | Repeats known failures | Read `git log` before every ideation phase |
| Subjective evaluation | "Looks good" kills autonomy | Only mechanical metrics count |
| Modify guard/test files | Defeats the safety net | Adapt implementation, never the tests |
| Silent failures | `catch {}` hides problems | Log at minimum; handle or re-throw |

## Context Rotation

For long unbounded runs where context window pressure degrades model performance, enable fresh-context mode:

```
Context-Mode: fresh    # spawns subagent worker per iteration (default: inline)
```

See `references/context-rotation-protocol.md` for the full orchestrator/worker protocol.
