"""
sync-grain-ci.py — Pull Grain meetings and update client meeting logs.

Designed to run in GitHub Actions (no Claude Code CLI or MCP needed).
Uses the Grain REST API directly + Anthropic API for client matching.

Required env vars:
  GRAIN_API_TOKEN   — Grain API token (Settings → API in Grain)
  ANTHROPIC_API_KEY — Anthropic API key for Claude

Usage:
  python scripts/sync-grain-ci.py              # Sync last 1 day
  python scripts/sync-grain-ci.py --days 3     # Sync last 3 days
  python scripts/sync-grain-ci.py --dry-run    # Preview without writing
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import anthropic
import requests

REPO_ROOT = Path(__file__).resolve().parent.parent
CLIENTS_DIR = REPO_ROOT / "context" / "clients"
GRAIN_API_BASE = "https://api.grain.com/v1"


def get_grain_headers():
    token = os.environ.get("GRAIN_API_TOKEN")
    if not token:
        print("Error: GRAIN_API_TOKEN not set")
        sys.exit(1)
    return {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }


def fetch_grain_meetings(days: int) -> list[dict]:
    """Fetch recent meetings from Grain API."""
    headers = get_grain_headers()
    after = (datetime.now(timezone.utc) - timedelta(days=days)).isoformat()

    resp = requests.get(
        f"{GRAIN_API_BASE}/meetings",
        headers=headers,
        params={"after": after, "limit": 50},
    )
    resp.raise_for_status()
    return resp.json().get("meetings", resp.json().get("list", []))


def fetch_meeting_notes(meeting_id: str) -> str:
    """Fetch AI-generated notes for a meeting."""
    headers = get_grain_headers()
    resp = requests.get(
        f"{GRAIN_API_BASE}/meetings/{meeting_id}/notes",
        headers=headers,
    )
    if resp.status_code == 200:
        data = resp.json()
        return data.get("notes", data.get("content", ""))
    return ""


def load_client_overviews() -> dict[str, str]:
    """Load all client overview files for context."""
    overviews = {}
    for client_dir in CLIENTS_DIR.iterdir():
        if client_dir.is_dir():
            overview = client_dir / "overview.md"
            if overview.exists():
                overviews[client_dir.name] = overview.read_text()
    return overviews


def load_existing_meetings(client_name: str) -> str:
    """Load existing meetings file content."""
    meetings_file = CLIENTS_DIR / client_name / "meetings.md"
    if meetings_file.exists():
        return meetings_file.read_text()
    return ""


def match_and_format_meetings(
    meetings: list[dict], overviews: dict[str, str]
) -> dict[str, list[str]]:
    """Use Claude to match meetings to clients and format entries."""
    client = anthropic.Anthropic()

    meetings_json = json.dumps(meetings, indent=2, default=str)
    overviews_json = json.dumps(overviews, indent=2)

    # Load existing meetings to avoid duplicates
    existing = {}
    for client_name in overviews:
        existing[client_name] = load_existing_meetings(client_name)

    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=4096,
        messages=[
            {
                "role": "user",
                "content": f"""You are a meeting sync agent for Pulse Integrated.

## Client Overviews
{overviews_json}

## Existing Meeting Logs (check for duplicates)
{json.dumps(existing, indent=2)}

## New Meetings from Grain
{meetings_json}

## Task

For each meeting:
1. Match it to a client folder based on title, attendees, and content
2. Skip internal-only meetings (all @pulsemarketing.co attendees, standups)
3. Skip meetings that already appear in existing logs (match by date + similar title)
4. Format matched meetings as markdown entries

Return a JSON object where keys are client folder names (s40s, swg, dcc, gaapp, national-concerts, other-clients) and values are arrays of formatted markdown strings.

Each markdown entry should follow this exact format:

---

### [Meeting Title]
**Date:** YYYY-MM-DD
**Attendees:** Name, Name, Name

**Key Decisions:**
- Decision 1
- Decision 2

**Action Items:**
- [ ] Action item — Owner
- [ ] Action item — Owner

**Context & Notes:**
Brief summary focusing on decisions, blockers, and timeline changes.

Return ONLY the JSON object, no other text. If no meetings match, return {{}}.
Use the folder name "skip" for meetings that should be skipped, with a brief reason as the entry.""",
            }
        ],
    )

    text = response.content[0].text.strip()
    # Extract JSON from response (handle markdown code blocks)
    if text.startswith("```"):
        text = re.sub(r"^```\w*\n?", "", text)
        text = re.sub(r"\n?```$", "", text)

    return json.loads(text)


def update_meetings_file(client_name: str, new_entries: list[str], dry_run: bool):
    """Append new meeting entries to a client's meetings.md file."""
    meetings_file = CLIENTS_DIR / client_name / "meetings.md"
    if not meetings_file.exists():
        print(f"  Warning: {meetings_file} does not exist, skipping")
        return

    content = meetings_file.read_text()
    today = datetime.now().strftime("%Y-%m-%d")

    # Update last_synced timestamp
    content = re.sub(
        r"<!-- last_synced: .* -->",
        f"<!-- last_synced: {today} -->",
        content,
    )

    # Insert new entries after the header (after the last_synced comment)
    header_end = content.find("-->") + 3
    header = content[:header_end]
    existing_entries = content[header_end:]

    new_content = header + "\n"
    for entry in new_entries:
        new_content += "\n" + entry.strip() + "\n"
    new_content += existing_entries

    if dry_run:
        print(f"\n  Would write to {meetings_file}:")
        for entry in new_entries:
            title_match = re.search(r"### (.+)", entry)
            if title_match:
                print(f"    + {title_match.group(1)}")
    else:
        meetings_file.write_text(new_content)
        for entry in new_entries:
            title_match = re.search(r"### (.+)", entry)
            if title_match:
                print(f"    + {title_match.group(1)}")


def main():
    parser = argparse.ArgumentParser(description="Sync Grain meetings to client logs")
    parser.add_argument("--days", type=int, default=1, help="Days to look back")
    parser.add_argument(
        "--dry-run", action="store_true", help="Preview without writing"
    )
    args = parser.parse_args()

    print(f"Syncing Grain meetings from the last {args.days} day(s)...")
    if args.dry_run:
        print("(dry run — no files will be written)")

    # Fetch meetings from Grain
    meetings = fetch_grain_meetings(args.days)
    print(f"Found {len(meetings)} meetings in Grain")

    if not meetings:
        print("No meetings to sync.")
        return

    # Load client context
    overviews = load_client_overviews()
    print(f"Loaded {len(overviews)} client overviews")

    # Match and format using Claude
    print("Matching meetings to clients...")
    result = match_and_format_meetings(meetings, overviews)

    # Process results
    matched = 0
    skipped = 0
    for client_name, entries in result.items():
        if client_name == "skip":
            skipped += len(entries)
            if args.dry_run:
                print(f"\n  Skipped {len(entries)} meetings:")
                for reason in entries:
                    print(f"    - {reason}")
            continue

        if not entries:
            continue

        matched += len(entries)
        print(f"\n  {client_name}: {len(entries)} meeting(s)")
        update_meetings_file(client_name, entries, args.dry_run)

    print(f"\nDone. {matched} matched, {skipped} skipped.")


if __name__ == "__main__":
    main()
