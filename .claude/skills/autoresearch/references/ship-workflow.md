# Ship Workflow

Universal shipping workflow. Ship anything through an 8-phase process that applies autoresearch loop principles to the last mile.

## Shipment Types

| Type | Example Ship Actions |
|------|---------------------|
| `code-pr` | `gh pr create` with full description |
| `code-release` | Git tag + GitHub release |
| `deployment` | CI/CD trigger, `kubectl apply`, push to deploy branch |
| `content` | Publish via CMS, commit to content branch |
| `marketing-email` | Send via ESP (SendGrid, Mailchimp) |
| `marketing-campaign` | Activate ads, launch landing page |
| `sales` | Send proposal, share deck |
| `research` | Upload to repository, submit paper |
| `design` | Export assets, share with stakeholders |

## Architecture

```
/autoresearch:ship
  ├── Phase 1: Identify (what are we shipping?)
  ├── Phase 2: Inventory (current state assessment)
  ├── Phase 3: Checklist (domain-specific pre-ship gates)
  ├── Phase 4: Prepare (autoresearch loop to fix failing checklist items)
  ├── Phase 5: Dry-run (simulate without side effects)
  ├── Phase 6: Ship (execute the actual delivery)
  ├── Phase 7: Verify (post-ship health check)
  └── Phase 8: Log (record to ship-log.tsv)
```

## Phase 1: Identify

Auto-detect shipment type from context, or ask user. Detection: staged changes + Dockerfile/k8s → deployment, staged changes + PR → code-pr, target *.md in content/ → content, mentions of email/campaign → marketing-email, etc.

## Phase 2: Inventory

Assess current state. Gather type-specific readiness: changed files, test status, lint status for code; word count, links, images for content; subject line, preview text, unsubscribe for email; etc.

## Phase 3: Checklist

Generate mechanical checklist. Every item must be verifiable (pass/fail). Examples:

**Code PR:** tests pass, lint clean, type check passes, PR description explains why, no secrets in diff, no TODO/FIXME in new code, breaking changes documented.

**Deployment:** all code checks pass, build succeeds in CI, env vars set, health check responds, rollback plan documented, monitoring configured.

**Content:** title present, no broken links, images have alt text, meta description present, no placeholder text, grammar check passes.

## Phase 4: Prepare

Autoresearch loop to fix failing checklist items until 100% pass. Same keep/discard/revert pattern as the core loop.

## Phase 5: Dry-run

Simulate the ship action without side effects. For code: `gh pr create --dry-run`. For deployment: validate manifests. For email: send test to self.

## Phase 6: Ship

Execute the actual delivery. **REQUIRES EXPLICIT USER CONFIRMATION** — never auto-ship without approval. After confirmation, execute the ship action.

## Phase 7: Verify

Post-ship health check. For code: check CI status, deployment health. For email: check delivery metrics. For content: verify published URL loads correctly.

## Phase 8: Log

Record to `ship/{YYMMDD}-{HHMM}-{ship-slug}/ship-log.tsv` with: timestamp, type, target, checklist score, dry-run result, ship status, verify result.

## Composite Metric

```
ship_score = (checklist_passing / checklist_total) * 80
           + (dry_run_passed ? 15 : 0)
           + (no_blockers ? 5 : 0)
```

Score 100 = fully ready. Below 80 = not shippable.

## Flags

| Flag | Purpose |
|------|---------|
| `--dry-run` | Validate without shipping (stop at Phase 5) |
| `--auto` | Auto-approve dry-run gate if no errors |
| `--force` | Skip non-critical checklist items |
| `--rollback` | Undo last ship action |
| `--monitor N` | Post-ship monitoring for N minutes |
| `--type <type>` | Override auto-detection |
| `--checklist-only` | Only generate and evaluate checklist (stop at Phase 3) |

See `references/common-setup.md` for shared setup/flags/chains.
