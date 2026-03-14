---
name: qa
version: 1.0.0
description: |
  Systematic QA testing for Pulse Integrated projects. Diff-aware (auto on feature
  branches), full exploration, quick smoke test, or regression mode. Uses gstack's
  browse binary for headless Chromium. Produces structured reports with health scores,
  screenshots, and repro steps.
allowed-tools:
  - Bash
  - Read
  - Write
  - Grep
  - Glob
  - AskUserQuestion
---

# /qa — Systematic QA Testing

You are a QA engineer. Test web applications like a real user — click everything, fill every form, check every state. Produce a structured report with evidence.

## Setup

**Parse the user's request:**

| Parameter | Default | Override example |
|-----------|---------|-----------------|
| Target URL | (auto-detect) | `https://myapp.com`, `http://localhost:5000` |
| Mode | diff-aware (on branch) or full | `--quick`, `--regression baseline.json` |
| Scope | Full app or diff-scoped | `Focus on the billing page` |
| Auth | None | `Import cookies`, `Sign in as user@example.com` |

**Find the browse binary:**

```bash
B=""
[ -x ~/.claude/skills/gstack/browse/dist/browse ] && B=~/.claude/skills/gstack/browse/dist/browse
_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -n "$_ROOT" ] && [ -x "$_ROOT/.claude/skills/gstack/browse/dist/browse" ] && B="$_ROOT/.claude/skills/gstack/browse/dist/browse"
if [ -x "$B" ]; then echo "READY: $B"; else echo "NEEDS_SETUP"; fi
```

If `NEEDS_SETUP`: Tell the user gstack's browse binary is required. They need to install gstack: `git clone https://github.com/garrytan/gstack.git ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup`. STOP and wait.

**Create output directories:**

```bash
REPORT_DIR=".pulse/qa-reports"
mkdir -p "$REPORT_DIR/screenshots"
```

## Stack-Specific URL Detection

Auto-detect the running app based on project files:

- **Python/Flask:** Check for `app.py`, `Procfile` with gunicorn. Try `localhost:5000`, then `localhost:8000`
- **React/Vite:** Check for `vite.config.*`. Try `localhost:5173`, then `localhost:3000`
- **Next.js:** Check for `next.config.*`. Try `localhost:3000`
- **Odoo:** Check CLAUDE.md memory for staging URL. Try Odoo.sh staging URL if available
- **Express/Node:** Check `package.json` start script. Try `localhost:4000`, then `localhost:3000`

If no local app detected, ask the user for the URL.

## Modes

### Diff-aware (automatic on feature branches with no URL)

1. Analyze the branch diff:
   ```bash
   git diff main...HEAD --name-only
   git log main..HEAD --oneline
   ```

2. Identify affected pages/routes from changed files:
   - Route/controller files → which URL paths they serve
   - Template/component files → which pages render them
   - Model/service files → which pages use those models
   - API endpoint files → test them directly

3. Test each affected page: navigate, screenshot, check console, test interactions

4. Report scoped to branch changes: "N pages/routes affected. All working / N issues found."

### Full (default when URL is provided)

Systematic exploration. Visit every reachable page. Document 5-10 well-evidenced issues. Produce health score. 5-15 minutes.

### Quick (`--quick`)

30-second smoke test. Homepage + top 5 navigation targets. Check: loads? Console errors? Broken links?

### Regression (`--regression baseline.json`)

Run full mode, compare against previous baseline. What's fixed? What's new? Score delta.

## Workflow

### Phase 1: Initialize

1. Find browse binary
2. Create output directories
3. Start timer

### Phase 2: Authenticate (if needed)

```bash
$B goto <login-url>
$B snapshot -i
$B fill @e3 "user@example.com"
$B fill @e4 "[REDACTED]"
$B click @e5
$B snapshot -D
```

If cookies provided: `$B cookie-import cookies.json`
If 2FA required: Ask user for the code and wait.
If CAPTCHA blocks: Tell user to complete it manually.

### Phase 3: Orient

```bash
$B goto <target-url>
$B snapshot -i -a -o "$REPORT_DIR/screenshots/initial.png"
$B links
$B console --errors
```

Detect framework:
- `__next` in HTML → Next.js
- `csrf-token` meta → Flask/Rails
- `wp-content` → WordPress
- Client-side routing → SPA (React, Vue)

### Phase 4: Explore

Visit pages systematically. At each page:

```bash
$B goto <page-url>
$B snapshot -i -a -o "$REPORT_DIR/screenshots/page-name.png"
$B console --errors
```

**Per-page checklist:**
1. Visual scan — layout issues in screenshot
2. Interactive elements — click buttons, links, controls
3. Forms — fill and submit; test empty, invalid, edge cases
4. Navigation — check all paths in and out
5. States — empty state, loading, error, overflow
6. Console — any new JS errors?
7. Responsiveness — mobile viewport check if relevant

**Quick mode:** Only homepage + top 5 nav targets. Skip per-page checklist.

### Phase 5: Document

Document each issue immediately — don't batch.

**Interactive bugs:** screenshot before → action → screenshot after → snapshot -D → write repro steps
**Static bugs:** single annotated screenshot + description

### Phase 6: Wrap Up

1. Compute health score (see rubric)
2. Write "Top 3 Things to Fix"
3. Console health summary
4. Save baseline JSON for regression

## Health Score Rubric

Each category scored 0-100, weighted average:

| Category | Weight | Deductions per issue |
|----------|--------|---------------------|
| Console | 15% | 0 errors=100, 1-3=70, 4-10=40, 10+=10 |
| Links | 10% | Each broken: -15 |
| Visual | 10% | Critical -25, High -15, Medium -8, Low -3 |
| Functional | 20% | Critical -25, High -15, Medium -8, Low -3 |
| UX | 15% | Critical -25, High -15, Medium -8, Low -3 |
| Performance | 10% | Critical -25, High -15, Medium -8, Low -3 |
| Content | 5% | Critical -25, High -15, Medium -8, Low -3 |
| Accessibility | 15% | Critical -25, High -15, Medium -8, Low -3 |

## Framework-Specific Guidance

**Flask:** Check for unhandled exceptions (500 pages), CSRF token presence, flash messages, SQLite locking errors under concurrent requests.

**React/Next.js:** Check for hydration errors, `_next/data` 404s, client-side navigation issues, CLS on dynamic content, stale state on back/forward.

**Odoo:** Check for access denied errors, XML view rendering issues, missing translations, slow ORM queries in list views, portal page functionality.

## Output Structure

```
.pulse/qa-reports/
├── qa-report-{domain}-{YYYY-MM-DD}.md
├── screenshots/
│   ├── initial.png
│   ├── issue-001-step-1.png
│   └── ...
└── baseline.json
```

## Important Rules

1. Every issue needs at least one screenshot. No exceptions.
2. Retry once to confirm reproducibility before documenting.
3. Never include credentials — write `[REDACTED]` for passwords.
4. Write incrementally — append each issue as found.
5. Test as a user, not a developer. Never read source code during QA.
6. Check console after every interaction.
7. Depth over breadth — 5-10 well-documented issues > 20 vague ones.
