#!/usr/bin/env bash
# autopilot.sh — Poll ClickUp for ai-ready tasks, implement, validate, and ship
#
# Usage:
#   bash scripts/autopilot.sh --once              # Process one task and stop
#   bash scripts/autopilot.sh --loop 10m          # Check every 10 minutes
#   bash scripts/autopilot.sh --dry-run           # Show queue without acting
#   bash scripts/autopilot.sh --kill              # Kill background dev servers
#   bash scripts/autopilot.sh --status            # Show recent run log
#
# Requires: Claude Code CLI (`claude`), gh CLI
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR=".pulse/autopilot"
RUN_LOG="$LOG_DIR/run-log.md"
TASK_FILE="$LOG_DIR/current-task.json"
MAX_FIX_ATTEMPTS=3
DEV_SERVER_PID=""

# Client folder name → local repo path mapping
get_repo() {
  case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
    s40s|"south 40"*)       echo "/Users/jakes1/Documents/claude-code/S40S/s40s-odoo" ;;
    dcc|"dcc market"*)      echo "/Users/jakes1/Documents/claude-code/DCC" ;;
    gaapp)                  echo "/Users/jakes1/Documents/claude-code/GAAPP" ;;
    swg|"strategic wealth"*) echo "/Users/jakes1/Documents/claude-code/SWG" ;;
    pulse|"internal"*)      echo "/Users/jakes1/Documents/claude-code/Pulse" ;;
    *)                      return 1 ;;
  esac
}

# --- Logging ---

log() {
  local msg="$1"
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$timestamp] $msg"
  echo "- **$timestamp** — $msg" >> "$RUN_LOG"
}

init_log() {
  mkdir -p "$LOG_DIR"
  if [ ! -f "$RUN_LOG" ]; then
    echo "# Autopilot Run Log" > "$RUN_LOG"
    echo "" >> "$RUN_LOG"
  fi
}

# --- Cleanup ---

cleanup() {
  if [ -n "$DEV_SERVER_PID" ]; then
    kill "$DEV_SERVER_PID" 2>/dev/null || true
    log "Stopped dev server (PID $DEV_SERVER_PID)"
    DEV_SERVER_PID=""
  fi
  rm -f "$TASK_FILE"
}
trap cleanup EXIT

# --- Load phase functions ---

source "$SCRIPT_DIR/autopilot-phases.sh"

# --- Process One Task ---

process_one_task() {
  init_log
  log "=== Autopilot run started ==="

  # Phase 1: Poll
  local poll_result
  poll_result=$(poll_tasks)

  # Parse first task from JSON
  local task_count
  task_count=$(echo "$poll_result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get(\"tasks\",[])))" 2>/dev/null || echo "0")

  if [ "$task_count" = "0" ]; then
    log "No ai-ready tasks found. Nothing to do."
    return 0
  fi

  # Extract first task fields
  local task_id task_name task_desc client_folder task_url
  task_id=$(echo "$poll_result" | python3 -c "import sys,json; print(json.load(sys.stdin)[\"tasks\"][0][\"id\"])")
  task_name=$(echo "$poll_result" | python3 -c "import sys,json; print(json.load(sys.stdin)[\"tasks\"][0][\"name\"])")
  task_desc=$(echo "$poll_result" | python3 -c "import sys,json; print(json.load(sys.stdin)[\"tasks\"][0][\"description\"])")
  client_folder=$(echo "$poll_result" | python3 -c "import sys,json; print(json.load(sys.stdin)[\"tasks\"][0][\"client_folder\"])")
  task_url=$(echo "$poll_result" | python3 -c "import sys,json; print(json.load(sys.stdin)[\"tasks\"][0].get(\"url\",\"\"))")

  log "Found task: $task_name ($task_id) — Client: $client_folder"

  # Map client folder to repo
  local repo_path
  if ! repo_path=$(get_repo "$client_folder"); then
    fail_task "$task_id" "Unknown client folder: $client_folder. Cannot map to a local repo."
    return 1
  fi

  if [ ! -d "$repo_path" ]; then
    fail_task "$task_id" "Repo not found at $repo_path"
    return 1
  fi

  # Phase 2: Claim
  local claim_result
  claim_result=$(claim_task "$task_id" "$task_name")
  if echo "$claim_result" | grep -q "FAILED"; then
    log "Failed to claim task: $claim_result"
    return 1
  fi

  # Phase 3: Implement
  implement_task "$repo_path" "$task_id" "$task_name" "$task_desc"

  # Phase 4: Start dev server
  local url
  url=$(start_dev_server "$repo_path")

  # Phase 5: Validate (with build-fix loop)
  local attempt=1
  local validate_result=""

  while [ $attempt -le $MAX_FIX_ATTEMPTS ]; do
    log "Validation attempt $attempt of $MAX_FIX_ATTEMPTS"
    validate_result=$(validate_task "$repo_path" "$url" "$task_name" "$task_desc")

    if echo "$validate_result" | grep -q "VALIDATE_PASS"; then
      log "Validation PASSED"
      break
    fi

    local failure_reason
    failure_reason=$(echo "$validate_result" | grep "VALIDATE_FAIL" | sed 's/VALIDATE_FAIL: //')

    if [ $attempt -eq $MAX_FIX_ATTEMPTS ]; then
      log "Validation failed after $MAX_FIX_ATTEMPTS attempts"
      fail_task "$task_id" "Validation failed after $MAX_FIX_ATTEMPTS attempts. Last failure: $failure_reason"
      return 1
    fi

    # Fix and retry
    fix_and_revalidate "$repo_path" "$url" "$task_name" "$task_desc" "$failure_reason"
    attempt=$((attempt + 1))
  done

  # Phase 6: Ship
  local pr_url
  pr_url=$(ship_task "$repo_path" "$task_id" "$task_name")

  log "=== Task complete: $task_name -> $pr_url ==="
}

# --- Dry Run ---

dry_run() {
  init_log
  echo "Checking ClickUp for ai-ready tasks (dry run)..."
  echo ""
  local poll_result
  poll_result=$(poll_tasks)
  echo "$poll_result" | python3 <<'PYEOF'
import sys, json
data = json.load(sys.stdin)
tasks = data.get("tasks", [])
if not tasks:
    print("No ai-ready tasks found.")
else:
    print("Found %d ai-ready task(s):" % len(tasks))
    print()
    for t in tasks:
        print("  [%s] %s" % (t["id"], t["name"]))
        print("    Client: %s" % t["client_folder"])
        print("    Project: %s" % t.get("project_list", "unknown"))
        print("    Description: %s..." % t["description"][:120])
        print()
PYEOF
}

# --- Status ---

show_status() {
  if [ -f "$RUN_LOG" ]; then
    echo "=== Recent Autopilot Activity ==="
    tail -20 "$RUN_LOG"
  else
    echo "No autopilot runs yet."
  fi
}

# --- Entry Point ---

case "${1:-}" in
  --dry-run)
    dry_run
    ;;
  --status)
    show_status
    ;;
  --kill)
    echo "Killing any background dev servers..."
    pkill -f "autopilot-dev-server" 2>/dev/null || true
    echo "Done."
    ;;
  --once)
    process_one_task
    ;;
  --loop)
    INTERVAL="${2:-10m}"
    case "$INTERVAL" in
      *m) SECONDS_INTERVAL=$(( ${INTERVAL%m} * 60 )) ;;
      *h) SECONDS_INTERVAL=$(( ${INTERVAL%h} * 3600 )) ;;
      *)  SECONDS_INTERVAL=600 ;;
    esac
    echo "Autopilot loop started. Checking every $INTERVAL."
    echo "Press Ctrl+C to stop."
    while true; do
      process_one_task || true
      echo "Next check in $INTERVAL..."
      sleep "$SECONDS_INTERVAL"
    done
    ;;
  *)
    echo "Usage: bash scripts/autopilot.sh [--once|--loop 10m|--dry-run|--status|--kill]"
    echo ""
    echo "Modes:"
    echo "  --once              Process one ai-ready task and stop"
    echo "  --loop <interval>   Check every interval (e.g., 10m, 1h)"
    echo "  --dry-run           Show queue without acting"
    echo "  --status            Show recent run log"
    echo "  --kill              Kill background dev servers"
    ;;
esac
