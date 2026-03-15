---
name: qa
version: 2.0.0
description: |
  Systematic QA testing for Pulse Integrated projects. Diff-aware (auto on feature
  branches), full exploration, quick smoke test, or regression mode. Uses Puppeteer MCP
  for headless browser testing. Produces structured reports with health scores,
  screenshots, and repro steps.
allowed-tools:
  - Bash
  - Read
  - Write
  - Grep
  - Glob
  - AskUserQuestion
  - mcp__puppeteer__puppeteer_navigate
  - mcp__puppeteer__puppeteer_screenshot
  - mcp__puppeteer__puppeteer_click
  - mcp__puppeteer__puppeteer_fill
  - mcp__puppeteer__puppeteer_select
  - mcp__puppeteer__puppeteer_hover
  - mcp__puppeteer__puppeteer_evaluate
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
| Auth | None | `Sign in as user@example.com` |

**Verify Puppeteer MCP is available:**

Call `puppeteer_navigate` with a test URL (e.g., `about:blank`). If it fails, tell the user:

> Puppeteer MCP server is required. Add it to `~/.claude/settings.json` under `mcpServers`.

STOP and wait.

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

To verify a port is running, use `puppeteer_navigate` — if it fails with a connection error, try the next port.

If no local app detected, ask the user for the URL.

## Modes

### Diff-aware (automatic on feature branches with no URL)

1. Analyze the branch diff:
   ```bash
   git diff main...HEAD --name-only
   ```
   ```bash
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

Systematic exploration. Visit every reachable page. Document 5-10 well-evidenced issues. Produce health score.

### Quick (`--quick`)

30-second smoke test. Homepage + top 5 navigation targets. Check: loads? Console errors? Broken links? Returns PASS/FAIL with summary.

### Regression (`--regression baseline.json`)

Run full mode, compare against previous baseline. What's fixed? What's new? Score delta.

## Workflow

### Phase 1: Initialize

1. Verify Puppeteer MCP
2. Create output directories
3. Start timer

### Phase 2: Authenticate (if needed)

```
puppeteer_navigate → login URL
puppeteer_screenshot → capture login page
puppeteer_fill → email field
puppeteer_fill → password field (use [REDACTED] in reports)
puppeteer_click → submit button
puppeteer_screenshot → verify login success
```

If 2FA required: Ask user for the code and wait.
If CAPTCHA blocks: Tell user to complete it manually.

### Phase 3: Orient

1. `puppeteer_navigate` to the target URL
2. `puppeteer_screenshot` (name: `initial`, width: 1440, height: 900)
3. `puppeteer_evaluate` to gather page state:

```javascript
(() => {
  return {
    title: document.title,
    url: window.location.href,
    links: Array.from(document.querySelectorAll('a[href]'))
      .map(a => ({ text: a.textContent.trim().slice(0, 50), href: a.href }))
      .filter(l => l.text.length > 0)
      .slice(0, 50),
    consoleErrors: [],
    framework: (() => {
      if (window.__NEXT_DATA__) return 'Next.js';
      if (document.querySelector('[data-reactroot]')) return 'React';
      if (document.querySelector('meta[name="csrf-token"]')) return 'Flask/Rails';
      if (document.querySelector('link[href*="wp-content"]')) return 'WordPress';
      if (document.querySelector('.o_main_navbar')) return 'Odoo';
      return 'Unknown';
    })()
  };
})()
```

### Phase 4: Explore

Visit pages systematically. At each page:

1. `puppeteer_navigate` to the page URL
2. `puppeteer_screenshot` (name: page slug, width: 1440, height: 900)
3. `puppeteer_evaluate` to check for errors:

```javascript
(() => {
  return {
    title: document.title,
    url: window.location.href,
    h1: document.querySelector('h1')?.textContent?.trim(),
    brokenImages: Array.from(document.querySelectorAll('img'))
      .filter(i => !i.naturalWidth && i.src).map(i => i.src),
    emptyLinks: Array.from(document.querySelectorAll('a'))
      .filter(a => !a.href || a.href === '#' || a.href === window.location.href + '#')
      .map(a => a.textContent.trim()).slice(0, 10),
    is404: document.title.toLowerCase().includes('404') ||
      document.body?.innerText?.includes('Page not found') ||
      document.body?.innerText?.includes('Not Found')
  };
})()
```

**Per-page checklist:**
1. Visual scan — layout issues in screenshot
2. Interactive elements — click buttons, links, controls using `puppeteer_click`
3. Forms — fill with `puppeteer_fill` and submit; test empty, invalid, edge cases
4. Navigation — check all paths in and out
5. States — empty state, loading, error, overflow
6. Console — check for JS errors via `puppeteer_evaluate`
7. Responsiveness — `puppeteer_screenshot` at mobile width (375px)

**Quick mode:** Only homepage + top 5 nav targets. Skip per-page checklist. Just check loads + no errors.

### Phase 5: Document

Document each issue immediately — don't batch.

**Interactive bugs:**
1. `puppeteer_screenshot` (before state)
2. Perform action (`puppeteer_click`, `puppeteer_fill`, etc.)
3. `puppeteer_screenshot` (after state)
4. Write repro steps

**Static bugs:** single screenshot + description

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

### Quick Mode Output

When running `--quick` (including from `/ship`), output a compact summary:

```
QA SMOKE TEST: PASS ✓
URL: https://myapp.com
Pages checked: 6 | Console errors: 0 | Broken links: 0 | 404s: 0
Screenshot: .pulse/qa-reports/screenshots/quick-check.png
```

Or on failure:

```
QA SMOKE TEST: FAIL ✗
URL: https://myapp.com
Pages checked: 6 | Console errors: 3 | Broken links: 1 | 404s: 0
Issues:
  - Console: TypeError in /dashboard (see screenshot)
  - Broken link: /pricing → 404
Screenshot: .pulse/qa-reports/screenshots/quick-check.png
```

## Important Rules

1. Every issue needs at least one screenshot. No exceptions.
2. Retry once to confirm reproducibility before documenting.
3. Never include credentials — write `[REDACTED]` for passwords.
4. Write incrementally — append each issue as found.
5. Test as a user, not a developer. Never read source code during QA.
6. Check console after every interaction.
7. Depth over breadth — 5-10 well-documented issues > 20 vague ones.
