# pulse-claude-skills

Custom Claude Code skills for Pulse Integrated. Eight slash commands that follow the cognitive mode workflow: **plan → review → QA → ship → retro** — plus agency operations tools for client management, campaigns, and meeting prep.

All skills are tailored to Pulse's multi-stack environment (Python/Flask, TypeScript/React, Odoo) and integrate with the team's tools (ClickUp, Grain, Gmail, Instantly).

## Skills

### Core Engineering Workflow

#### `/plan` — Architect / Tech Lead

Architecture-first plan review before you write a single line of code. Auto-detects your stack (Flask, React, or Odoo) and runs through 7 review sections: scope challenge, architecture, error handling, security, data flow, test coverage, and performance.

**Three modes:**
- **EXPAND** — Push scope up. What's the 10-star version? Think bigger before building.
- **HOLD** — Maximum rigor within stated scope. Make it bulletproof.
- **REDUCE** — Cut to minimum viable. Ship the smallest useful thing.

**When to use:** Before starting any non-trivial feature. Run `/plan` when you're about to build something that touches multiple files, introduces a new pattern, or changes data flow. Especially useful when you're unsure about the right approach.

---

#### `/review` — Paranoid Staff Engineer

Two-pass pre-PR code review against your branch diff. Pass 1 catches critical issues (SQL injection, auth bypass, trust boundary violations). Pass 2 flags informational items (dead code, test gaps, CLAUDE.md compliance). Includes a stack-specific checklist for Flask, React, and Odoo.

**When to use:** Before opening a PR. Run `/review` on your feature branch to catch structural issues that tests miss — SQL safety, missing auth decorators, Odoo `sudo()` without justification, React hooks violations, and more. Each critical finding gives you a choice: fix it, acknowledge it, or mark it as a false positive.

---

#### `/qa` — QA Lead

Systematic QA testing using a headless browser (gstack's browse binary). Four modes: diff-aware (automatic on feature branches), full exploration, quick smoke test, and regression comparison. Takes screenshots, checks console errors, and generates a health score report.

**When to use:** After your code is running locally and you want to verify it works like a real user would. On a feature branch, just type `/qa` — it analyzes your diff, finds the affected pages, and tests them automatically. Use `--quick` for a 30-second smoke test, or run on a staging URL for full-app coverage.

**Requires:** gstack browse binary (see install instructions below).

---

#### `/ship` — Release Engineer

Fully automated release workflow. Merges main into your branch, runs tests (auto-detects pytest for Flask, npm/bun test for React), runs the `/review` checklist, bumps the version, generates a changelog from your commits, creates bisectable commits, pushes, and opens a PR.

**When to use:** When your feature is done and you want to ship it. Type `/ship` and the next thing you see is a PR URL. Only stops for: test failures, critical review findings, or merge conflicts. Deploy target is auto-detected and noted in the PR body (Render for Flask, Cloud Run for DCC, Odoo.sh for S40S).

---

#### `/retro` — Engineering Manager

Sprint retrospective that combines three data sources: git history (always available), ClickUp sprint data (via MCP), and Grain meeting insights (via MCP). Computes engineering metrics (commits, LOC, test ratio, session patterns), delivery metrics (velocity, point completion), and meeting effectiveness.

**When to use:** At the end of a sprint or work period. Supports time windows: `24h`, `7d`, `14d`, `30d`, or `compare` (this period vs last). Run `/retro 7d` for a weekly summary or `/retro compare` to see trends. Generates per-contributor breakdowns with praise and growth opportunities. Gracefully degrades if ClickUp or Grain MCP aren't available — you still get git metrics.

---

### Agency Operations

#### `/client-brief` — Account Manager

Generates a client status report by pulling from three sources: ClickUp (task status, blockers, upcoming work), Grain (recent meeting notes, action items, key decisions), and Gmail (recent threads, pending questions, sentiment). Produces a Red/Yellow/Green health assessment with reasoning.

**When to use:** Before a client check-in, when a stakeholder asks "how's Project X going?", or during weekly status reviews. Run `/client-brief <client name>` to get a consolidated view across all tools. Each data source degrades gracefully — if Gmail MCP isn't connected, you still get ClickUp + Grain data.

---

#### `/campaign-check` — Marketing Ops

Email campaign analytics dashboard from Instantly. Shows all active campaigns with key metrics, analyzes performance against thresholds (open rate, reply rate, bounce rate), checks account warmup status and deliverability, reviews lead list verification, and identifies 7-day trends.

**Performance thresholds:**
- Open rate: >30% good, <20% needs attention
- Reply rate: >3% good, <2% needs attention
- Bounce rate: <3% good, >5% critical

**When to use:** During weekly marketing reviews or when you need a quick health check on email campaigns. Run `/campaign-check` to see which campaigns need optimization and get rule-based recommendations for improvement.

---

#### `/meeting-prep` — Client Success

Pre-call briefing that pulls from Grain (past meeting notes, action items), ClickUp (action item completion status, current project state), and Gmail (recent emails, pending questions). Generates talking points, flags overdue action items, and surfaces open questions.

**When to use:** 15-30 minutes before a client call. Run `/meeting-prep <client name>` to get a briefing with everything you need: what was discussed last time, which action items are done (and which aren't), what's been happening in email, and suggested talking points. Never walk into a call unprepared again.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- MCP integrations configured in Claude Code:
  - **ClickUp** — used by `/retro`, `/client-brief`, `/meeting-prep`
  - **Grain** — used by `/retro`, `/client-brief`, `/meeting-prep`
  - **Gmail** — used by `/client-brief`, `/meeting-prep`
  - **Instantly** — used by `/campaign-check`
- (Optional) [gstack](https://github.com/garrytan/gstack) installed for `/browse` binary — required by `/qa`

## Getting Started (Pulse Team)

### 1. Install Claude Code

If you haven't already, install [Claude Code](https://docs.anthropic.com/en/docs/claude-code) and authenticate with your Anthropic account.

### 2. Clone and install the skills

```bash
git clone https://github.com/pulse-integrated/pulse-claude-skills.git ~/.claude/skills/pulse-claude-skills
cd ~/.claude/skills/pulse-claude-skills
chmod +x setup
./setup
```

That's it. The `setup` script creates symlinks so Claude Code can find each skill:

```
~/.claude/skills/plan              → pulse-claude-skills/plan/
~/.claude/skills/review            → pulse-claude-skills/review/
~/.claude/skills/qa                → pulse-claude-skills/qa/
~/.claude/skills/ship              → pulse-claude-skills/ship/
~/.claude/skills/retro             → pulse-claude-skills/retro/
~/.claude/skills/client-brief      → pulse-claude-skills/client-brief/
~/.claude/skills/campaign-check    → pulse-claude-skills/campaign-check/
~/.claude/skills/meeting-prep      → pulse-claude-skills/meeting-prep/
```

### 3. Restart Claude Code

Skills are loaded at startup. If Claude Code is already running, exit and relaunch it. Then type `/` — you should see all 8 skills in the autocomplete.

### 4. Connect MCP integrations (optional but recommended)

Some skills pull data from Pulse's tools via MCP. Configure these in your Claude Code settings:

- **ClickUp** — used by `/retro`, `/client-brief`, `/meeting-prep`
- **Grain** — used by `/retro`, `/client-brief`, `/meeting-prep`
- **Gmail** — used by `/client-brief`, `/meeting-prep`
- **Instantly** — used by `/campaign-check`

Skills degrade gracefully — if an MCP isn't connected, the skill skips that data source and continues with what's available. You don't need all of them to get started.

### 5. (Optional) Install gstack for browser automation

The `/qa` skill uses gstack's browse binary for headless Chromium testing. Without it, `/qa` won't work — but all other skills are unaffected.

```bash
curl -fsSL https://bun.sh/install | bash
git clone https://github.com/garrytan/gstack.git ~/.claude/skills/gstack
cd ~/.claude/skills/gstack
./setup
```

### Verify it works

Open a terminal, `cd` into any Pulse project repo (e.g., `agile-dashboard`, `DCC`, `S40S`), and start Claude Code. Try:

```
/retro 7d
```

This runs a 7-day sprint retro using git history — no MCP needed. If you see a metrics report, you're all set.

## Updating

When skills are updated, pull the latest and re-run setup:

```bash
cd ~/.claude/skills/pulse-claude-skills
git pull
./setup
```

## Adding a new skill

1. Create a new directory: `my-skill/`
2. Add `my-skill/SKILL.md` with YAML frontmatter (see existing skills for the pattern)
3. Run `./setup` to create the symlink
4. Restart Claude Code and type `/my-skill` to test

## Uninstalling

```bash
cd ~/.claude/skills/pulse-claude-skills && ./setup --uninstall
rm -rf ~/.claude/skills/pulse-claude-skills
```

## License

MIT
