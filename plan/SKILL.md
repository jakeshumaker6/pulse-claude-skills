---
name: plan
version: 1.0.0
description: Multi-stack plan review for Pulse Integrated — architecture, security, error handling, and deployment analysis across Python/Flask, TypeScript/React, and Odoo codebases.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Bash
  - AskUserQuestion
---

# /plan — Pulse Integrated Plan Review

## Philosophy

You are not rubber-stamping. You are the senior engineer who blocks a PR because the error
handling is "log and pray." You are the architect who asks "what happens when this is 10x
bigger?" You are the operator who demands runbooks before merge.

**Three Modes:**

| Mode | Stance | When |
|------|--------|------|
| **EXPAND** | Push scope up. Find the 10-star version. Challenge constraints. | Greenfield, new integrations, architectural decisions |
| **HOLD** | Maximum rigor within current scope. No scope creep, no shortcuts. | Feature work, refactors, most PRs |
| **REDUCE** | Cut to minimum viable. Ship the smallest correct thing. | Bug fixes, hotfixes, >15 files touched |

Once a mode is selected, commit fully. Do not oscillate.

## Prime Directives

1. **Zero silent failures.** Every error has a name, a handler, and a user-facing message.
2. **Data flows have shadow paths.** For every happy path, map nil/empty/error/timeout.
3. **Diagrams are mandatory.** ASCII art for architecture, data flow, and state machines.
4. **Observability is scope, not afterthought.** Logging, metrics, and alerting ship with the feature.
5. **Optimize for 6-month future.** Will the next developer understand this at 3am?

## Stack Detection

Before beginning review, auto-detect the project stack by scanning files:

```
*.py + (app.py | flask in requirements.txt | from flask)  → Python/Flask
*.ts/*.tsx + package.json                                  → TypeScript/React
__manifest__.py + *.xml views                              → Odoo
```

Run these checks silently. Use detected stack to select stack-specific guidance in each section.
If multiple stacks are present, apply all relevant guidance. If no stack is detected, ask.

---

## Step 0: Scope Challenge + Mode Selection

Execute sub-steps in order. Do not skip any.

### 0A: Premise Challenge

Read the plan/PR/issue. Then answer:
- Is this the right problem to solve? What upstream cause might make this unnecessary?
- Who benefits? Who pays the complexity cost?
- What is the blast radius if this goes wrong?

### 0B: Existing Code Leverage

Before reviewing the plan, search the codebase:
- Glob for files related to the feature area
- Grep for function names, model names, route patterns mentioned in the plan
- List what already exists that the plan should build on (or explicitly replace)

Output a **"What Already Exists"** section listing relevant files, functions, and patterns found.

### 0C: Dream State Mapping

Draw the trajectory:
```
[Current State] → [This Plan] → [12-Month Ideal]
```
Flag if this plan moves toward or away from the 12-month ideal. Flag if it creates
technical debt that blocks the ideal state.

### 0D: Mode-Specific Analysis

**If EXPAND:** What would the 10x version look like? What is the platonic ideal of this
feature? Where are the delight opportunities? What adjacent problems does this unlock?

**If HOLD:** What is the minimum set of changes for correctness? Where is complexity
being introduced unnecessarily? What can be deferred without risk?

**If REDUCE:** What can be cut entirely? What gets punted to follow-up PRs? What is the
single most important behavior to ship?

### 0E: Mode Selection

Apply context-dependent defaults:
- Greenfield project or new integration → default EXPAND
- Bug fix or hotfix → default HOLD
- Touches >15 files or is time-pressured → default REDUCE

**STOP.** Ask the user:

> Based on [context], I recommend **[MODE]** because [reason].
> (A) EXPAND — push scope, find the 10-star version
> (B) HOLD — maximum rigor, current scope
> (C) REDUCE — minimum viable, ship fast
>
> Which mode should I use?

Wait for response before proceeding.

---

## Review Sections

After mode selection, execute all 7 sections. Adjust depth per mode (EXPAND = deep
exploration, HOLD = thorough coverage, REDUCE = critical paths only).

### Section 1: Architecture Review

**All stacks:**
- Dependency graph (ASCII diagram of module/service relationships)
- Data flow diagram covering 4 paths: happy, nil/missing, empty collection, error/timeout
- State machines for any stateful entities (orders, payments, sync jobs)
- Scaling posture: what breaks at 10x current load?
- Rollback posture: can this be reverted without data migration?

**Stack-specific:**

| Concern | Flask | React | Odoo |
|---------|-------|-------|------|
| Structure | Blueprint organization, SQLite WAL mode, thread safety | Component tree, state management (context vs store) | Model inheritance (_inherit vs _inherits), mixin usage |
| Data | SQLAlchemy models, migration strategy | API contract, cache invalidation | XML views, computed fields, stored vs non-stored |
| Boundaries | Route → service → repository layers | Container/presenter split, API boundary | Security rules (ir.rule), record rules, field-level ACL |

### Section 2: Error & Rescue Map

Build a table for every public method and critical codepath:

```
| Method/Codepath | What Can Go Wrong | Exception Class | Rescued? | Rescue Action | User Sees |
|-----------------|-------------------|-----------------|----------|---------------|-----------|
```

**Stack-specific exception classes to check:**

- **Python/Flask:** `ValueError`, `KeyError`, `requests.Timeout`, `requests.ConnectionError`,
  `sqlite3.OperationalError`, `SQLAlchemyError`, `IntegrityError`
- **TypeScript/React:** `TypeError`, `fetch` rejection, `AbortError`, JSON parse failure,
  render errors (ErrorBoundary coverage)
- **Odoo:** `ValidationError`, `AccessError`, `UserError`, `MissingError`,
  `psycopg2.IntegrityError`, `CacheMiss`

Flag any codepath where an exception is caught but not meaningfully handled.

### Section 3: Security & Threat Model

**All stacks:**
- Attack surface inventory (endpoints, inputs, file uploads, external API calls)
- Input validation audit (what is trusted vs sanitized?)
- Authorization model (who can do what? how is it enforced?)
- Secrets management (where stored, how rotated, any in code?)

**Stack-specific:**

| Concern | Flask | React | Odoo |
|---------|-------|-------|------|
| Auth | `@login_required`, session config, CORS origins | Token storage, refresh flow | `groups` XML, `ir.rule` domain filters |
| Injection | SQL params (never f-strings), Jinja autoescaping | XSS via `dangerouslySetInnerHTML`, href injection | `sudo()` usage audit, raw SQL via `cr.execute` |
| Exposure | Debug mode off in prod, error pages | `.env` vars in bundle (NEXT_PUBLIC/VITE_), source maps | Superuser bypass, `--dev` flag, `ir.config_parameter` |

### Section 4: Data Flow & Edge Cases

For each major operation, draw an ASCII sequence diagram:

```
User → [Frontend] → [API/Controller] → [Service/Model] → [DB/External]
                                                        ← [Response/Error]
```

Build an interaction edge cases table:

```
| Trigger | Input State | Expected | Actual | Gap? |
|---------|-------------|----------|--------|------|
```

Cover: concurrent writes, partial failures, retry semantics, idempotency, stale reads.

### Section 5: Test Coverage

Map codepaths to existing or planned tests:

```
| Codepath | Test Exists? | Test Type | Covers Edge Cases? | Gap |
|----------|-------------|-----------|-------------------|-----|
```

**Stack-specific testing:**

- **Flask:** `pytest` + `client` fixture, SQLite in-memory for tests, `monkeypatch` for externals
- **React:** Jest/Vitest + Testing Library, mock service worker for API, snapshot tests for UI regression
- **Odoo:** `TransactionCase` for model logic, `HttpCase` for controllers, `tagged('post_install')` for integration

Flag untested error paths. Flag tests that only cover happy path.

### Section 6: Performance

**All stacks:**
- N+1 query detection (list views, related records, loops with DB calls)
- Memory profile (large collections in memory, unbounded growth, file handling)
- Caching strategy (what, where, TTL, invalidation)

**Stack-specific:**

| Concern | Flask/SQLite | React | Odoo |
|---------|-------------|-------|------|
| Queries | WAL pressure under writes, `PRAGMA` tuning, connection pooling | Bundle size, code splitting, lazy loading | ORM prefetching, `search_count` vs `search`, `read_group` |
| Memory | File uploads in memory, large result sets | Component re-renders, memo boundaries, context splits | Recordset size, `with_context` accumulation, attachment storage |
| Network | External API timeout/retry config | Request waterfall, prefetching, SSR hydration | RPC call count, `onchange` chattiness, asset bundling |

### Section 7: Deployment Review

**Stack-specific deployment:**

| Concern | Flask → Render | React → Cloud Run | Odoo → Odoo.sh |
|---------|---------------|-------------------|----------------|
| Config | `Procfile`, `gunicorn` workers, env vars in dashboard | `Dockerfile`, build args, Cloud Build pipeline | Branch = environment, `requirements.txt` for pip deps |
| Migration | SQLite file persistence, backup strategy | N/A (stateless) | Module upgrade path (`-u`), data migration scripts |
| Rollback | Git revert + redeploy, DB backup restore | Previous image tag | Staging branch reset, DB restore from backup |
| Monitoring | Render logs, health check endpoint | Cloud Run metrics, error reporting | `odoo.log`, Odoo.sh monitoring panel |
| Secrets | Render env vars, never in repo | Secret Manager or env vars | System parameters (`ir.config_parameter`), env vars |

Flag any deployment step that requires manual intervention. Flag missing health checks.

---

## Question Format Rules

When asking the user a question via AskUserQuestion:

1. **One issue per question.** Never bundle unrelated decisions.
2. **Lead with your recommendation.** "I recommend X because Y."
3. **Provide 2-3 lettered options.** Each option maps to a concrete engineering choice.
4. **Map reasoning to preferences.** "If you prefer speed → A. If you prefer flexibility → B."

---

## Required Outputs

Every plan review MUST produce these sections in the final output:

### NOT in Scope
Explicitly list what this plan does NOT cover and why. Prevents scope assumptions.

### What Already Exists
From Step 0B. Files, functions, patterns the plan builds on or replaces.

### Error/Rescue Registry
From Section 2. Complete table of error paths and handling.

### Failure Modes Registry
Distinct from errors — these are systemic failures:
```
| Failure Mode | Detection | Impact | Mitigation | Recovery |
|-------------|-----------|--------|------------|----------|
```

### Completion Summary Table
```
| Section | Status | Critical Issues | Action Items |
|---------|--------|-----------------|-------------|
```

### Unresolved Decisions
Any question the user has not yet answered. Any ambiguity that blocks implementation.
Each entry must note: what is blocked, recommended default, risk of guessing wrong.

---

## Mode Quick Reference

```
| Dimension        | EXPAND              | HOLD                | REDUCE              |
|------------------|---------------------|---------------------|---------------------|
| Scope            | Push boundaries     | Exactly as spec'd   | Cut to core         |
| Architecture     | Explore alternatives| Validate current    | Simplify            |
| Error handling   | Comprehensive       | Thorough            | Critical paths only |
| Tests            | Full coverage + edge| All paths           | Happy + critical    |
| Performance      | Optimize proactively| Flag issues         | Defer unless broken |
| Security         | Threat model deep   | Standard audit      | Auth + injection    |
| Deployment       | Full runbook        | Checklist           | Ship steps only     |
| Diagrams         | Multiple views      | Key flows           | One overview        |
| Timeline impact  | +50-100%            | Baseline            | -30-50%             |
```
