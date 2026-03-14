---
name: retro
version: 1.0.0
description: Sprint retrospective combining git metrics, ClickUp sprint data, and Grain meeting insights for Pulse Integrated teams.
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - AskUserQuestion
  - mcp__claude_ai_ClickUp__clickup_search
  - mcp__claude_ai_ClickUp__clickup_get_workspace_hierarchy
  - mcp__claude_ai_ClickUp__clickup_get_list
  - mcp__claude_ai_Grain__search_meetings
  - mcp__claude_ai_Grain__fetch_meeting_notes
  - mcp__claude_ai_Grain__list_attended_meetings
---

# /retro — Sprint Retrospective

## Arguments

| Invocation | Window |
|------------|--------|
| `/retro` | Last 7 days (default) |
| `/retro 24h` | Last 24 hours |
| `/retro 14d` | Last 14 days |
| `/retro 30d` | Last 30 days |
| `/retro compare` | Last 7 days vs previous 7 days |

Parse the argument to compute `SINCE` and `UNTIL` timestamps. Use Pacific time for all
date calculations and session detection.

---

## Three Data Sources

This retro combines three sources. Git is required. ClickUp and Grain are enrichment — if
their MCP tools are unavailable, continue with git-only data and note what was skipped.

### Source 1: Git History (Required)

All commits in the time window with: timestamps, author, files changed, insertions,
deletions. Used for engineering metrics, session detection, and hotspot analysis.

### Source 2: ClickUp Sprint Data (Optional)

Sprint/list data for delivery metrics: story points, velocity, task breakdown.
If ClickUp MCP tools fail or return errors, print:
> "ClickUp data unavailable — skipping sprint delivery metrics."

### Source 3: Grain Meeting Data (Optional)

Meeting data for collaboration metrics: meeting count, hours, decisions, action items.
If Grain MCP tools fail or return errors, print:
> "Grain data unavailable — skipping meeting metrics."

---

## Steps

### Step 1: Gather Git Data

Run all git commands in parallel for the computed time window:

```bash
# All commits with stats
git log --since="SINCE" --until="UNTIL" --format="%H|%aI|%aN|%s" --numstat

# Shortlog for per-author summary
git shortlog --since="SINCE" --until="UNTIL" -sne

# Files changed with frequency
git log --since="SINCE" --until="UNTIL" --format="" --name-only | sort | uniq -c | sort -rn

# Diff stat summary
git log --since="SINCE" --until="UNTIL" --format="" --shortstat
```

Parse the output to extract:
- Commit list with timestamps, authors, file changes
- Per-file change frequency (hotspots)
- Total insertions and deletions
- PR numbers from commit messages (look for `#\d+`, `PR #\d+`, merge commit patterns)

### Step 2: Pull ClickUp Sprint Data

Use MCP tools to gather sprint delivery data:

1. Call `clickup_get_workspace_hierarchy` to find the current workspace structure
2. Identify the sprint list that covers the retro window (look for sprint/iteration naming)
3. Call `clickup_search` with date filters to find tasks completed in the window
4. Call `clickup_get_list` for the sprint list to get capacity/planned points

Extract:
- Tasks completed (count and list)
- Story points completed vs planned
- Task type breakdown: feature, bug fix, chore (from tags or task names)
- Carryover tasks (started but not completed)

If any MCP call fails, log the error and skip all ClickUp metrics.

### Step 3: Pull Grain Meeting Data

Use MCP tools to gather meeting data:

1. Call `list_attended_meetings` or `search_meetings` filtered to the retro window
2. For each meeting, call `fetch_meeting_notes` to get notes and action items

Extract:
- Meeting count and total duration
- Key decisions made (from meeting notes)
- Action items generated
- Meeting types (standup, planning, client call, internal)

If any MCP call fails, log the error and skip all Grain metrics.

### Step 4: Compute Engineering Metrics

From git data, compute:

**Commit metrics:**
- Total commits to main/default branch
- Unique contributors
- Total insertions, deletions, net LOC
- Average commit size (lines changed)

**Test LOC ratio:**
- Classify files as test or production:
  - Test: paths containing `test`, `spec`, `__tests__`, files matching `*_test.*`, `*.spec.*`, `test_*.*`
  - Production: everything else
- Compute: `test_insertions / total_insertions * 100`

**Session detection:**
- Group commits by author
- Within each author, sort by timestamp
- A gap of >2 hours between consecutive commits starts a new session
- Report: total sessions, average session length, longest session

**Streak detection:**
- Count consecutive days with at least one commit
- Report current streak and longest streak in window

### Step 5: Compute Delivery Metrics (ClickUp)

If ClickUp data is available:

- **Velocity:** story points completed in the window
- **Completion rate:** completed points / planned points as percentage
- **Task type breakdown:** count and percentage of features, fixes, chores
- **Carryover rate:** tasks started but not completed / total tasks
- **Average cycle time:** if start and end dates available on tasks

If ClickUp data is unavailable, skip this step entirely.

### Step 6: Compute Meeting Metrics (Grain)

If Grain data is available:

- **Meeting count:** total meetings in the window
- **Meeting hours:** total duration
- **Decisions per meeting:** count of decisions / meeting count
- **Action items generated:** total across all meetings
- **Meeting type breakdown:** standup, planning, client, internal

If Grain data is unavailable, skip this step entirely.

### Step 7: Hotspot Analysis + PR Size Distribution

**Hotspots:** Top 10 most-changed files by commit frequency. Flag any file changed in >30%
of commits as a "hotspot" worth reviewing for decomposition.

**PR size distribution:** Group PRs by lines changed:
- XS: <10 lines
- S: 10-50 lines
- M: 50-200 lines
- L: 200-500 lines
- XL: >500 lines

Report distribution. Flag if >30% of PRs are L or XL.

### Step 8: Per-Contributor Breakdown

For each contributor:
- Commits, insertions, deletions, net LOC
- Files most frequently touched
- Test LOC ratio
- Session count and patterns
- Detected focus areas (based on file paths)

Frame as **praise** (specific accomplishments) and **growth opportunity** (one concrete
suggestion). Never generic. Always tied to data.

Example praise: "Jake shipped 3 PRs touching the payment integration, all with >40% test
coverage. The error handling in `payment_service.py` is particularly thorough."

Example growth: "Consider breaking `sync_controller.py` into smaller modules — it appeared
in 8 of 12 commits this sprint, suggesting it's accumulating too many responsibilities."

### Step 9: Load History and Compare

Check for previous retro snapshots:
```
.context/retros/retro-YYYY-MM-DD.json
```

If a previous snapshot exists:
- Compute deltas for all numeric metrics (commits, LOC, velocity, test ratio)
- Flag significant changes (>20% swing in any metric)
- Note trends across multiple retros if available

If `/retro compare` was invoked, compute the previous window (e.g., 7d retro compares
days 1-7 vs days 8-14) and show side-by-side metrics.

### Step 10: Save JSON Snapshot

Create `.context/retros/` directory if it does not exist.

Save a JSON file at `.context/retros/retro-YYYY-MM-DD.json` containing:
- All computed metrics
- Raw counts (commits, LOC, points, meetings)
- Per-contributor data
- Timestamp and window parameters

This enables trend tracking across retros.

### Step 11: Write Narrative

Generate the full retrospective narrative. Target length: 3000-4500 words.

---

## Output Format

### Tweetable Summary (First Line)

One sentence, max 280 characters. Captures the sprint in a single take.

Example: "Shipped payment integration with 94% test coverage across 23 commits — velocity
up 15% from last sprint, but meeting load doubled."

### Summary Tables

**Engineering Metrics:**

```
| Metric              | Value       | Trend  |
|---------------------|-------------|--------|
| Commits to main     | N           | +N%    |
| Contributors        | N           |        |
| Total +/-           | +N/-N       |        |
| Net LOC             | N           | +N%    |
| Test LOC ratio      | N%          | +N pp  |
| Active days         | N/N         |        |
| Detected sessions   | N           |        |
| Avg session length  | Nh Nm       |        |
| Current streak      | N days      |        |
```

**Delivery Metrics (if ClickUp available):**

```
| Metric                | Value       | Trend  |
|-----------------------|-------------|--------|
| Sprint points planned | N           |        |
| Sprint points done    | N (N%)      | +N%    |
| Tasks completed       | N           |        |
| Features / Fixes      | N / N       |        |
| Carryover rate        | N%          |        |
| Avg cycle time        | Nd          |        |
```

**Meeting Metrics (if Grain available):**

```
| Metric                | Value       | Trend  |
|-----------------------|-------------|--------|
| Meetings held         | N           |        |
| Meeting hours         | Nh          | +N%    |
| Decisions/meeting     | N.N         |        |
| Action items created  | N           |        |
| Meeting types         | N standup, N planning, N client |
```

### Trends vs Last Retro

If historical data exists, show a comparison section highlighting:
- Metrics that improved significantly (celebrate)
- Metrics that declined (investigate, no blame)
- Metrics that are stable (note consistency)

If no historical data: "First retro — no historical comparison available. Future retros
will show trends."

### Time and Session Patterns

Describe when work happens:
- Which days of the week had the most commits
- Morning vs afternoon vs evening sessions
- Longest session and what was worked on
- Any concerning patterns (late-night work, weekend commits)

Use Pacific time for all reporting.

### Shipping Velocity

Analyze PR throughput:
- PRs merged in the window
- Average PR size and review turnaround (if data available from git)
- Size distribution chart
- Recommendations for PR sizing

### Sprint Delivery (ClickUp Section)

If ClickUp data is available:
- Sprint goal recap (if identifiable from list/sprint name)
- Completion breakdown by task type
- Carryover analysis — what did not ship and why (if discernible)
- Velocity trend across sprints (if historical data exists)

If unavailable: "ClickUp data was not available for this retro. Connect ClickUp MCP for
sprint delivery metrics in future retros."

### Meeting Effectiveness (Grain Section)

If Grain data is available:
- Meeting hours as percentage of work hours (assume 40h week)
- Most productive meetings (highest decisions + action items per hour)
- Meetings that could be async (low decision count, informational only)
- Action item follow-through (if trackable across retros)

If unavailable: "Grain data was not available for this retro. Connect Grain MCP for
meeting effectiveness metrics in future retros."

### Your Week (Personal Deep-Dive)

For the primary contributor (or the user running the retro):
- Detailed session-by-session breakdown
- What you shipped, in plain language
- Your test coverage trend
- Your focus areas (files/modules you touched most)
- One specific thing you did well (with evidence)
- One specific thing to try next sprint (with rationale)

### Team Breakdown

Per-contributor section (see Step 8). Include all contributors with commits in the window.

### Top 3 Lists

**3 Wins:**
Specific, evidence-backed accomplishments. Not generic praise.

**3 Improvements:**
Concrete, actionable suggestions. Each tied to a metric or observation.

**3 Habits to Build:**
Repeatable practices that would improve the metrics. Forward-looking.

---

## Tone

- **Encouraging but candid.** Celebrate real wins, name real problems.
- **Specific and concrete.** Every claim backed by a number or file path.
- **Skip generic praise.** "Great work this sprint!" is banned. Replace with "Shipped 3
  PRs averaging 45 LOC with zero test regressions."
- **Frame improvements as leveling up.** Not "you should do X" but "leveling up here
  means X, which would show as Y in the metrics."
- **No blame.** Problems are systemic, not personal. "The carryover rate was 40%" not
  "Jake didn't finish his tasks."

---

## Graceful Degradation

The retro always works. Data sources fail gracefully:

| Source | Available | Unavailable |
|--------|-----------|-------------|
| Git | Full engineering metrics | **Cannot run retro** — git is required |
| ClickUp | Delivery metrics included | Delivery section shows "unavailable" note |
| Grain | Meeting metrics included | Meeting section shows "unavailable" note |

If both ClickUp and Grain are unavailable, the retro runs as a pure engineering/git retro.
The output is still valuable — just narrower in scope.

---

## Rules

1. **Git is the source of truth.** All engineering metrics come from git, not estimates.
2. **Never fabricate data.** If a metric cannot be computed, say so. Do not guess.
3. **Always save the snapshot.** The JSON file enables trend tracking across retros.
4. **Handle MCP failures silently.** Log the error, skip the section, continue.
5. **Pacific time for everything.** Session detection, day counting, timestamp display.
6. **Privacy-aware.** Do not include email addresses in output. Use display names only.
7. **Actionable over comprehensive.** A 3000-word retro with clear actions beats a
   5000-word data dump.
