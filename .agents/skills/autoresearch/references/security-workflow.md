# Security Workflow

Autonomous security auditing using the autoresearch loop. Combines STRIDE threat modeling, OWASP Top 10 sweeps, and red-team adversarial analysis.

## Architecture

```
SETUP PHASE (once):
  1. Scan codebase (tech stack, frameworks, APIs)
  2. Map assets (data stores, auth, external services)
  3. Identify trust boundaries (client/server, API/DB, user/admin, CI/CD/prod)
  4. Generate STRIDE threat model
  5. Build attack surface map
  6. Create security-audit-results.tsv log

AUTONOMOUS LOOP:
  Each iteration: pick ONE attack vector, validate vulnerability,
  log result, move to next vector.
```

## Setup Phase: Threat Model Generation

### Step 1: Codebase Reconnaissance
Scan dependencies, config files, Dockerfiles, API routes, auth/middleware, DB schemas, CI/CD configs.

### Step 2: Asset Identification
Catalog: Data stores (Critical), Authentication (Critical), API endpoints (High), External services (High), User input surfaces (High), Configuration (Medium), Static assets (Low).

### Step 3: Trust Boundary Mapping
Identify trust level changes: Browser-Server, Server-Database, Server-External APIs, Public-Authenticated routes, User-Admin roles, CI/CD-Production, Container-Host.

### Step 4: STRIDE Threat Model

| Threat | Focus | Check For |
|--------|-------|-----------|
| Spoofing | Identity | Weak auth, missing MFA, token forgery |
| Tampering | Data integrity | Unsigned data, missing checksums, SQL injection |
| Repudiation | Non-repudiation | Missing audit logs, unsigned transactions |
| Information Disclosure | Confidentiality | Unencrypted data, verbose errors, exposed secrets |
| Denial of Service | Availability | Missing rate limits, unbounded allocations |
| Elevation of Privilege | Authorization | Missing role checks, privilege escalation paths |

### Step 5: Attack Surface Map
Map every entry point (URLs, form inputs, API params, headers, file uploads, webhooks), data flow (how data moves through trust boundaries), and abuse paths (how an attacker would chain vulnerabilities).

## The Security Loop

Each iteration:
1. Review threat model + past findings + results log
2. Select next untested attack vector
3. Deep-dive into target code
4. Validate with proof (code path + input + expected output)
5. Classify: severity + OWASP category + STRIDE category
6. Log to security-audit-results.tsv
7. Repeat

Every N iterations, print OWASP + STRIDE coverage summary.

## Red-Team Adversarial Lenses

Rotate through 4 adversarial perspectives:
- Security Adversary (external attacker)
- Supply Chain Attacker (dependency/CI compromise)
- Insider Threat (malicious or compromised employee)
- Infra Attacker (network/container/host access)

## OWASP Top 10 Coverage

Must test for: Broken Access Control, Cryptographic Failures, Injection, Insecure Design, Security Misconfiguration, Vulnerable Components, Auth Failures, Software/Data Integrity Failures, Logging/Monitoring Failures, SSRF.

## Output Directory

Creates `security/{YYMMDD}-{HHMM}-{audit-slug}/` with:
- `overview.md` (executive summary)
- `threat-model.md` (STRIDE model)
- `attack-surface-map.md` (entry points + data flows)
- `findings.md` (severity-ranked with code evidence)
- `owasp-coverage.md` (coverage matrix)
- `dependency-audit.md` (tool output)
- `recommendations.md` (prioritized mitigations)
- `security-audit-results.tsv` (iteration log)

## Flags

| Flag | Purpose |
|------|---------|
| `--diff` | Delta mode — only audit files changed since last audit |
| `--fix` | Auto-fix confirmed Critical/High findings after audit |
| `--fail-on <severity>` | Exit non-zero for CI/CD gating (critical, high, medium) |

## Composite Metric

```
security_score = (owasp_tested/10)*50 + (stride_tested/6)*30 + min(findings, 20)
```

See `references/common-setup.md` for shared setup/flags/chains.
