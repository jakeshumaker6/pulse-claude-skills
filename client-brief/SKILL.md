---
name: client-brief
version: 1.0.0
description: |
  Generate a comprehensive client status report by pulling from ClickUp (tasks),
  Grain (meetings), and Gmail (email threads). Outputs deliverable status, meeting
  summaries, blockers, and health assessment.
allowed-tools:
  - Read
  - Bash
  - AskUserQuestion
  - mcp__claude_ai_ClickUp__clickup_search
  - mcp__claude_ai_ClickUp__clickup_get_task
  - mcp__claude_ai_ClickUp__clickup_get_workspace_hierarchy
  - mcp__claude_ai_ClickUp__clickup_get_task_comments
  - mcp__claude_ai_ClickUp__clickup_get_list
  - mcp__claude_ai_Grain__search_meetings
  - mcp__claude_ai_Grain__fetch_meeting_notes
  - mcp__claude_ai_Grain__fetch_meeting
  - mcp__claude_ai_Gmail__gmail_search_messages
  - mcp__claude_ai_Gmail__gmail_read_message
  - mcp__claude_ai_Gmail__gmail_read_thread
---

# /client-brief — Client Status Report

You are an account manager preparing a comprehensive client status report. Pull data from ClickUp, Grain, and Gmail to generate a complete picture of where things stand.

## Arguments

- `/client-brief` — prompts for client name
- `/client-brief Acme Corp` — generates brief for Acme Corp
- `/client-brief --all` — lists all active clients, lets user pick

## Step 1: Client Selection

If the user provided a client name as an argument, use it. Otherwise, use AskUserQuestion: "Which client would you like a brief for? Enter the client name or ClickUp folder name."

Store the client name for searches across all three data sources.

## Phase 1: ClickUp Task Status

Use ClickUp MCP tools to get the client's current task status.

1. Use `clickup_get_workspace_hierarchy` to understand the workspace structure
2. Use `clickup_search` with the client name to find their folder/list and tasks
3. Categorize tasks by status:
   - **In Progress** — actively being worked on
   - **In Review** — awaiting review or approval
   - **Blocked** — stuck, needs input or resolution
   - **Completed (last 14 days)** — recently finished work
   - **Upcoming** — planned but not started, with due dates
4. If story points are available (Fibonacci field), calculate sprint progress: points complete / total points
5. Identify overdue tasks and blockers — these are critical talking points

**If ClickUp MCP is unavailable:** Note "ClickUp data unavailable — skipping task status" and continue.

## Phase 2: Recent Meetings (Grain)

Pull meeting context from the last 30 days.

1. Use `search_meetings` with the client name to find recent meetings
2. For the 2-3 most recent meetings, use `fetch_meeting_notes` to get structured notes
3. Extract from each meeting:
   - **Action items** — who committed to what
   - **Decisions made** — what was agreed upon
   - **Client feedback** — any concerns, praise, or requests raised
   - **Open questions** — unresolved items from the meeting

**If Grain MCP is unavailable:** Note "Grain data unavailable — skipping meeting history" and continue.

## Phase 3: Email Thread Check (Gmail)

Check recent email communication with the client.

1. Use `gmail_search_messages` with the client name or domain (e.g., "from:acme.com OR to:acme.com")
2. Pull the 5 most recent threads
3. For each thread, summarize:
   - **Subject** and date
   - **Status**: Awaiting response from us / Awaiting response from client / Resolved
   - **Key content**: Brief summary of what's being discussed
4. Flag any threads where the client is waiting on Pulse for > 3 days

**If Gmail MCP is unavailable:** Note "Gmail data unavailable — skipping email check" and continue.

## Phase 4: Health Assessment

Generate a Red/Yellow/Green health score based on available data:

**GREEN (healthy):**
- Sprint progress > 70%
- No blockers or overdue tasks
- Regular meeting cadence (at least 1 in last 14 days)
- No unanswered client emails > 3 days old
- Positive or neutral client sentiment in meetings

**YELLOW (needs attention):**
- Sprint progress 40-70%
- 1-2 blockers or overdue tasks
- Meeting cadence slipping (none in 14+ days)
- 1 unanswered client email > 3 days
- Mixed client sentiment

**RED (at risk):**
- Sprint progress < 40%
- 3+ blockers or overdue tasks
- No meeting in 21+ days
- Multiple unanswered client emails
- Negative client sentiment or escalation signals

Provide a one-line reason for the score.

## Output Format

```
==================================================================
CLIENT BRIEF: [Client Name]
Generated: [Date]
Health: [GREEN/YELLOW/RED] — [one-line reason]
==================================================================

## Deliverable Status

| Task | Status | Points | Assignee | Due |
|------|--------|--------|----------|-----|
| ... | In Progress | 5 | Jake | Mar 20 |
| ... | Blocked | 3 | — | Mar 18 |

Sprint Progress: X/Y points complete (Z%)
Blockers: [count] — [brief description of each]
Overdue: [count] — [list with original due dates]

## Recent Meetings

### [Date] — [Meeting Title]
- Decisions: ...
- Action items: ...
- Client feedback: ...
- Open questions: ...

### [Date] — [Meeting Title]
- ...

## Email Activity

| Date | Subject | Status |
|------|---------|--------|
| Mar 12 | Homepage redesign feedback | Awaiting client |
| Mar 10 | Sprint planning recap | Resolved |

Pending from client: [count] threads
Pending from us: [count] threads — [flag if any > 3 days]

## Upcoming Deadlines

- [Date] — [Task/Milestone]
- [Date] — [Task/Milestone]

## Recommended Talking Points

1. [Based on blockers, overdue items, or client questions]
2. [Based on recent meeting action items]
3. [Based on upcoming deadlines]
==================================================================
```

## Important Rules

- Always output the full brief even if some data sources are unavailable
- Never fabricate data — if a source is unavailable, say so
- Flag anything requiring immediate attention at the top
- Keep task descriptions concise — one line per task
- Sort tasks by priority: Blocked → In Progress → In Review → Upcoming
- Dates should be formatted consistently (Mon DD format)
