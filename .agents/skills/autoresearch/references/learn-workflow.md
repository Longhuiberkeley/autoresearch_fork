# Learn Workflow — $autoresearch learn

Autonomous codebase documentation engine. Scouts codebase structure, learns patterns and architecture, generates/updates comprehensive documentation — then validates and iteratively improves until docs match codebase reality.

## Modes

| Mode | Purpose | Loop? |
|------|---------|-------|
| `init` | Learn codebase from scratch, generate all docs | Yes — validate-fix cycle |
| `update` | Learn what changed, refresh existing docs | Yes — validate-fix cycle |
| `check` | Read-only health/staleness assessment | No — diagnostic only |
| `summarize` | Quick codebase summary with file inventory | Minimal — size check only |

## Architecture

```
$autoresearch learn
  ├── Phase 1: Scout — Parallel codebase reconnaissance
  ├── Phase 2: Analyze — Structure detection + project type classification
  ├── Phase 3: Map — Dynamic doc discovery + gap analysis
  ├── Phase 4: Generate — Spawn docs-manager with structured prompt
  ├── Phase 5: Validate — Mechanical verification (refs, links, completeness)
  ├── Phase 6: Fix — Re-generate failed docs with feedback (max 3 retries)
  ├── Phase 7: Finalize — Size check, inventory, git diff summary
  └── Phase 8: Log — Record to learn-results.tsv
```

## Phase 1: Scout

Scale-aware parallel codebase exploration. Exclude `.git`, `node_modules`, `__pycache__`, `dist`, `build`, `.next`, `coverage`, `vendor`. Test directories are NOT excluded (needed for testing-guide.md).

If >5000 files: increase scout parallelism. If >10000 files: warn, suggest `--scope`.

Monorepo detection: check for `workspaces` in package.json, `lerna.json`, `pnpm-workspace.yaml`.

Update mode optimization: use `git diff --name-only HEAD~10` to prioritize changed areas.

## Phase 2: Analyze

Detect: project type (library, web app, CLI, API server, monorepo), tech stack (languages, frameworks, build tools, test runners), existing doc structure, staleness gap (last code commit vs last docs commit).

## Phase 3: Map — Doc Discovery + Gap Analysis

### Init Mode — Always create:
- `docs/project-overview-pdr.md`
- `docs/codebase-summary.md`
- `docs/code-standards.md`
- `docs/system-architecture.md`
- `README.md` (create/update, max 300 lines)

### Conditional creation:
- `docs/deployment-guide.md` — if Dockerfile, CI config, deploy scripts detected
- `docs/design-guidelines.md` — if UI components or frontend framework detected
- `docs/api-reference.md` — if API routes, controllers, or OpenAPI specs detected
- `docs/testing-guide.md` — if test directories or test config detected
- `docs/configuration-guide.md` — if `.env.example`, `config/` dir, or feature flags detected
- `docs/changelog.md` — generated from `git log`, init mode only

### Update Mode
Read existing `docs/*.md` in parallel via Explore subagents. Map changed source files to affected docs (e.g., `src/api/**` → prioritize `api-reference.md`).

### Check Mode
List all docs with LOC and last modified dates. Report standard doc types present vs missing.

## Phase 4: Generate

Spawn `docs-manager` subagent with: merged scout reports, project type + tech stack, explicit file list, constraints (each doc ≤800 lines, README ≤300 lines), Mermaid diagram instructions for system-architecture.md, dependency section for codebase-summary.md, cross-reference links between docs.

## Phase 5: Validate

Mechanical checks: code references resolve to existing files, internal links are valid, required sections present, file sizes within limits. Output validation report.

## Phase 6: Fix Loop

Re-generate failed docs with validation feedback. Max 3 retries. Escalate to user if unresolved.

## Phase 7: Finalize

Inventory check, git diff summary, size compliance verification.

## Flags

| Flag | Purpose |
|------|---------|
| `--mode <mode>` | init, update, check, summarize (default: auto-detect) |
| `--scope <glob>` | Limit learning to specific dirs |
| `--depth <level>` | quick, standard, deep |
| `--scan` | Force fresh scout in summarize mode |
| `--topics <list>` | Focus summarize on specific topics |
| `--file <name>` | Selective update — target single doc |
| `--no-fix` | Skip validation-fix loop |

## Composite Metric

```
learn_score = validation%×0.5 + coverage%×0.3 + size_compliance%×0.2
```

See `references/common-setup.md` for shared setup/flags/chains.
