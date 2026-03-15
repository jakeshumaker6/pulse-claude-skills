#!/usr/bin/env bash
# sync-grain.sh — Pull recent Grain recordings and update client meeting logs
#
# Usage:
#   bash scripts/sync-grain.sh              # Sync today's meetings
#   bash scripts/sync-grain.sh 3            # Sync last 3 days
#   bash scripts/sync-grain.sh --dry-run    # Preview without writing
#
# Requires: Claude Code CLI (`claude`) with Grain MCP connected
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CLIENTS_DIR="$REPO_DIR/context/clients"
DAYS="${1:-1}"
DRY_RUN=""

if [ "$1" = "--dry-run" ]; then
  DRY_RUN="Do NOT write any files. Instead, print what you would write and to which file."
  DAYS="1"
elif [ "$2" = "--dry-run" ]; then
  DRY_RUN="Do NOT write any files. Instead, print what you would write and to which file."
fi

# Verify claude CLI exists
if ! command -v claude &>/dev/null; then
  echo "Error: 'claude' CLI not found. Install Claude Code first."
  exit 1
fi

# Verify clients directory exists
if [ ! -d "$CLIENTS_DIR" ]; then
  echo "Error: Clients directory not found at $CLIENTS_DIR"
  exit 1
fi

echo "Syncing Grain meetings from the last $DAYS day(s)..."
if [ -n "$DRY_RUN" ]; then
  echo "(dry run — no files will be written)"
fi

claude -p "$(cat <<PROMPT
You are a meeting sync agent for Pulse Integrated. Your job is to pull recent Grain recordings and update the correct client meeting log.

## Step 1: Learn the clients

Read every overview.md file in ${CLIENTS_DIR}/*/overview.md to understand which clients exist, their project names, key contacts, and company names. Build a lookup table of keywords that identify each client.

## Step 2: Fetch recent meetings from Grain

Use the Grain MCP tools to:
1. Call list_meetings or list_attended_meetings to find meetings from the last ${DAYS} day(s)
2. For each meeting found, call fetch_meeting_notes to get the AI-generated notes
3. If notes are thin, call fetch_meeting_transcript to get more context

## Step 3: Match each meeting to a client

For each meeting, determine which client it belongs to by checking:
- Meeting title (often contains client name or project name)
- Attendee names and emails (match against contacts in overview.md files)
- Meeting content (mentions of project names, products, or company names)

If a meeting matches multiple clients, pick the strongest match.
If a meeting doesn't match any client (e.g., an internal Pulse meeting), skip it.
If a meeting could be for a client in "other-clients", use the other-clients folder.

## Step 4: Update meeting logs

For each matched meeting, append an entry to that client's meetings.md file at ${CLIENTS_DIR}/<client>/meetings.md.

Use this exact format for each entry (newest entries go at the TOP, right after the header):

---

### <Meeting Title>
**Date:** YYYY-MM-DD
**Attendees:** Name, Name, Name

**Key Decisions:**
- Decision 1
- Decision 2

**Action Items:**
- [ ] Action item 1 — Owner
- [ ] Action item 2 — Owner

**Context & Notes:**
Brief summary of what was discussed, any important context that would help the team understand the client's current state. Focus on business decisions, project updates, blockers, and timeline changes.

---

Also update the <!-- last_synced: --> comment at the top of each file you modify with today's date.

## Rules

- Only add NEW meetings. Check existing entries in meetings.md to avoid duplicates (match by date + title).
- Keep entries concise — 5-10 bullet points max per meeting, not full transcripts.
- Focus on actionable information: decisions, action items, blockers, timeline changes.
- Do not modify overview.md files — only meetings.md files.
${DRY_RUN}

## After completion

Print a summary:
- Total meetings found in Grain
- How many matched to clients (and which ones)
- How many skipped (and why)
PROMPT
)" \
  --allowedTools "Read,Write,Edit,Glob,Grep,mcp__claude_ai_Grain__list_meetings,mcp__claude_ai_Grain__list_attended_meetings,mcp__claude_ai_Grain__fetch_meeting,mcp__claude_ai_Grain__fetch_meeting_notes,mcp__claude_ai_Grain__fetch_meeting_transcript,mcp__claude_ai_Grain__search_meetings"

echo ""
echo "Grain sync complete."

# Auto-commit if files changed and not dry run
if [ -z "$DRY_RUN" ]; then
  cd "$REPO_DIR"
  if ! git diff --quiet context/clients/; then
    echo "Meeting logs updated. Committing..."
    git add context/clients/*/meetings.md
    git commit -m "Auto-sync Grain meetings ($(date +%Y-%m-%d))"
    echo "Committed. Run 'git push' to share with the team."
  else
    echo "No new meetings to sync."
  fi
fi
