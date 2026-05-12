# Scenario Workflow — /autoresearch_scenario

Autonomous scenario exploration engine. Generates, expands, and stress-tests use cases from a seed scenario across 12 dimensions. Discovers edge cases and failure modes manual analysis misses.

## Architecture

```
/autoresearch_scenario
  ├── Phase 1: Seed Analysis (parse scenario, identify actors/goals/preconditions)
  ├── Phase 2: Decomposition (12 exploration dimensions)
  ├── Phase 3: Situation Generation (one concrete situation per iteration)
  ├── Phase 4: Classification (new/variant/duplicate/out-of-scope/low-value)
  ├── Phase 5: Expansion (derive edge cases, what-ifs, failure modes)
  ├── Phase 6: Logging (scenario-results.tsv)
  └── Phase 7: Repeat (next unexplored dimension)
```

## The 12 Exploration Dimensions

| # | Dimension | Explores |
|---|-----------|----------|
| 1 | Happy Path | Baseline flow with all preconditions met |
| 2 | Error Path | Expected failures: invalid input, missing data, auth failures |
| 3 | Edge Case | Boundary conditions: empty, max, min, null, zero, negative |
| 4 | Abuse | Malicious: injection, brute force, privilege escalation, data tampering |
| 5 | Scale | Load: 0 users, 1 user, 1000 users, spike, sustained |
| 6 | Concurrent | Race conditions: simultaneous actions, conflicting writes |
| 7 | Temporal | Time: timezone, DST, leap year, expiration, ordering |
| 8 | Data Variation | Data: encoding, size, format, special chars, unicode |
| 9 | Permission | Access: no auth, wrong role, expired token, cross-tenant |
| 10 | Integration | Dependencies: timeout, error response, malformed data from externals |
| 11 | Recovery | Resilience: retry, rollback, partial failure, idempotency |
| 12 | State Transition | Lifecycle: invalid transitions, stuck states, skipped steps |

## Phase 3: Situation Generation

Every situation must have: **concrete trigger**, **specific flow**, **expected outcome**. No vague "something goes wrong."

Template:
```
TRIGGER: <specific action or event>
FLOW: <step-by-step what happens>
OUTCOME: <what the system should do>
```

## Phase 4: Classification

| Class | Criteria | Action |
|-------|----------|--------|
| **New** | Novel situation not in prior iterations | Keep, expand derivatives |
| **Variant** | Similar to existing but meaningfully different | Keep, note relationship |
| **Duplicate** | Same trigger/flow/outcome as existing | Discard |
| **Out-of-scope** | Beyond scope boundaries | Discard |
| **Low-value** | Trivial, obvious, or unrealistic | Discard |

## Domain Templates

Priority dimensions per domain:

| Domain | Priority Dimensions | Default Format |
|--------|--------------------|----------------|
| Software/API | error_path, edge_case, concurrent, integration, data_variation | test-scenarios |
| Product/UX | happy_path, error_path, permission, temporal, state_transition | user-stories |
| Business | happy_path, error_path, permission, temporal, recovery | use-cases |
| Security | abuse, permission, data_variation, integration, concurrent | threat-scenarios |
| Marketing | happy_path, data_variation, temporal, scale, state_transition | user-stories |

## Composite Metric

```
scenario_score = scenarios_generated*10 + edge_cases_found*15
               + (dimensions_covered/12)*30 + unique_actors*5
```

## Flags

| Flag | Purpose |
|------|---------|
| `--domain <type>` | software, product, business, security, marketing |
| `--depth <level>` | shallow (10), standard (25), deep (50+) |
| `--scope <glob>` | Limit to specific files/features |
| `--format <type>` | use-cases, user-stories, test-scenarios, threat-scenarios, mixed |
| `--focus <area>` | Prioritize: edge-cases, failures, security, scale |

See `references/common-setup.md` for shared setup/flags/chains.
