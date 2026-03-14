---
name: meeting-prep
version: 1.0.0
description: |
  Pre-call briefing generator. Pulls past meeting notes from Grain,
  current task status from ClickUp, and recent email threads from Gmail
  to prepare talking points, action item status, and open questions.
allowed-tools:
  - Read
  - Bash
  - AskUserQuestion
  - mcp__claude_ai_Grain__search_meetings
  - mcp__claude_ai_Grain__fetch_meeting
  - mcp__claude_ai_Grain__fetch_meeting_notes
  - mcp__claude_ai_Grain__fetch_meeting_transcript
  - mcp__claude_ai_ClickUp__clickup_search
  - mcp__claude_ai_ClickUp__clickup_get_task
  - mcp__claude_ai_ClickUp__clickup_get_workspace_hierarchy
  - mcp__claude_ai_ClickUp__clickup_get_task_comments
  - mcp__claude_ai_ClickUp__clickup_get_list
  - mcp__claude_ai_Gmail__gmail_search_messages
  - mcp__claude_ai_Gmail__gmail_read_message
  - mcp__claude_ai_Gmail__gmail_read_thread
---

# /meeting-prep — Pre-Call Briefing

You are preparing for a client meeting. Pull context from past meetings, current project status, and recent communications to generate a comprehensive briefing with talking points.

## Arguments

- `/meeting-prep` — prompts for client name
- `/meeting-prep Acme Corp` — generates briefing for Acme Corp
- `/meeting-prep Acme Corp tomorrow 2pm` — includes meeting time in header

## Step 1: Client Selection

If the user provided a client name, use it. Otherwise, use AskUserQuestion: "Which client are you meeting with?"

If a meeting time was provided, include it in the briefing header.

## Phase 1: Past Meeting History (Grain)

Pull context from the last 3 meetings with this client.

1. Use `search_meetings` with the client name to find recent meetings (last 60 days)
2. For each of the 3 most recent meetings, use `fetch_meeting_notes` to get structured notes
3. For the most recent meeting only, optionally use `fetch_meeting_transcript` for detailed context if notes are sparse
4. Extract from each meeting:
   - **Date and title**
   - **Action items** — who committed to what, with any deadlines mentioned
   - **Decisions made** — what was agreed upon
   - **Client concerns** — any issues, frustrations, or risks raised
   - **Commitments by Pulse** — what we said we'd deliver
   - **Client mood/tone** — positive, neutral, concerned, frustrated

**If Grain MCP is unavailable:** Note "Meeting history unavailable" and continue.

## Phase 2: Action Item Status Check (ClickUp)

Cross-reference meeting action items with ClickUp task status.

1. Take the action items extracted from Grain (Phase 1)
2. Use `clickup_search` to find corresponding tasks in ClickUp
3. For each action item, determine status:
   - **COMPLETE** — task is done
   - **IN PROGRESS** — actively being worked on
   - **NOT STARTED** — task exists but hasn't been picked up
   - **OVERDUE** — past due date and not complete
   - **NOT FOUND** — no corresponding ClickUp task (flag as a gap)
4. Flag overdue or not-started items from previous meetings — these are critical talking points that need addressing

**If ClickUp MCP is unavailable:** Note "Task status unavailable" and continue.

## Phase 3: Recent Communications (Gmail)

Check for any email context that should inform the meeting.

1. Use `gmail_search_messages` with the client name or domain (last 14 days)
2. For each relevant thread:
   - Is there a pending question from the client we haven't answered?
   - Did we make any commitments via email?
   - Is there any new information or context shared via email?
3. Flag threads where the client is waiting on us

**If Gmail MCP is unavailable:** Note "Email history unavailable" and continue.

## Phase 4: Current Project Status (ClickUp)

Get the current state of the client's projects.

1. Use `clickup_get_workspace_hierarchy` to find the client's folder/space
2. Use `clickup_search` or `clickup_get_list` to get current tasks
3. Summarize:
   - **Shipped since last meeting** — completed tasks since last meeting date
   - **Currently in progress** — what's being worked on now, with assignees
   - **Blocked** — what's stuck and why
   - **Upcoming milestones** — next deadlines or deliverables

**If ClickUp MCP is unavailable:** Skip this phase.

## Phase 5: Generate Briefing

Compile all data into the output format. Focus on what's actionable for the meeting.

## Output Format

```
==================================================================
MEETING PREP: [Client Name]
Meeting: [Date/Time if provided]
Generated: [Date]
Last meeting: [Date from Grain] — [Title]
==================================================================

## Action Items from Previous Meetings

| Action Item | From Meeting | Owner | Status |
|-------------|-------------|-------|--------|
| Finalize homepage design | Feb 28 | Jake | COMPLETE |
| Send analytics report | Feb 28 | Sarah | OVERDUE |
| Approve color palette | Feb 28 | Client | NOT FOUND |

ALERT: 1 overdue item — "Send analytics report" was due Mar 5

## What We Shipped Since Last Meeting

- [Task name] — completed [date] by [assignee]
- [Task name] — completed [date] by [assignee]

## Currently In Progress

- [Task name] — [assignee], due [date]
- [Task name] — [assignee], due [date]

## Blockers to Discuss

- [Blocker description] — needs client input on [what specifically]
- [Blocker description] — waiting for [dependency]

## Client's Open Questions (from email)

- [Question from email thread] — sent [date], unanswered
- [Question from email thread] — sent [date], answered [date]

## Previous Meeting Key Points

### [Date] — [Title]
- Decisions: ...
- Client concerns: ...
- Our commitments: ...
- Client mood: [positive/neutral/concerned]

### [Date] — [Title]
- Decisions: ...
- Client concerns: ...
- Our commitments: ...

## Suggested Talking Points

1. ADDRESS: [Overdue action item] — explain status, propose new timeline
2. PRESENT: [Recently shipped work] — demo or walkthrough
3. DISCUSS: [Blocker needing client input] — get decision today
4. UPDATE: [Upcoming milestones] — confirm timeline and expectations
5. ASK: [Open question for client] — clarify requirements or priorities

## Open Questions to Ask the Client

1. [Based on gaps in ClickUp — missing requirements, unclear priorities]
2. [Based on unresolved items from previous meetings]
3. [Based on upcoming work that needs client direction]

## Watch Out For

- [Any negative sentiment from recent meetings]
- [Any unanswered client emails]
- [Any at-risk deadlines]
==================================================================
```

## Important Rules

- The briefing should be scannable in 2 minutes before the meeting
- Lead with action items and overdue work — this is what the client will ask about
- Never fabricate meeting notes or task data — if unavailable, say so
- Flag items needing immediate attention with ALERT prefix
- Keep talking points to 3-5 items — don't overwhelm
- If no data is available from any source, say so clearly rather than generating empty sections
- Sort talking points by priority: address overdue → present wins → discuss blockers → update plans
