#!/usr/bin/env bash
# code-and-qa.sh — Run a coding agent and QA agent in parallel
#
# The coding agent works on your feature. The QA agent continuously tests
# the running app and reports issues back.
#
# Usage:
#   bash scripts/code-and-qa.sh                          # Auto-detect URL
#   bash scripts/code-and-qa.sh http://localhost:5173     # Specify URL
#   bash scripts/code-and-qa.sh --kill                    # Kill the session
#
# Requires: Claude Code CLI (`claude`), tmux
set -e

SESSION_NAME="pulse-code-qa"
TARGET_URL="${1:-}"

# --- Functions ---

kill_sessions() {
  if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux kill-session -t "$SESSION_NAME"
    echo "Killed tmux session: $SESSION_NAME"
  else
    echo "No active session: $SESSION_NAME"
  fi
}

detect_url() {
  # Try common local dev ports
  for port in 5173 3000 5000 8000 8080 4000; do
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$port" 2>/dev/null | grep -q "200\|301\|302"; then
      echo "http://localhost:$port"
      return 0
    fi
  done
  return 1
}

# --- Main ---

if ! command -v tmux &>/dev/null; then
  echo "Error: tmux is required. Install with: brew install tmux"
  exit 1
fi

if ! command -v claude &>/dev/null; then
  echo "Error: 'claude' CLI not found. Install Claude Code first."
  exit 1
fi

if [ "$TARGET_URL" = "--kill" ]; then
  kill_sessions
  exit 0
fi

# Auto-detect URL if not provided
if [ -z "$TARGET_URL" ]; then
  echo "No URL provided. Detecting running app..."
  if TARGET_URL=$(detect_url); then
    echo "Found app at: $TARGET_URL"
  else
    echo "No running app detected. The QA agent will wait for a URL."
    echo "Start your dev server, then tell the QA agent the URL."
    TARGET_URL="PENDING"
  fi
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Kill existing session
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  tmux kill-session -t "$SESSION_NAME"
fi

echo "Launching code + QA parallel session..."
echo "  Repo: $REPO_ROOT"
echo "  QA target: $TARGET_URL"
echo ""

# Window 1: Coding agent (interactive Claude)
tmux new-session -d -s "$SESSION_NAME" -c "$REPO_ROOT" -n "code"
tmux send-keys -t "$SESSION_NAME:code" "claude" Enter

# Window 2: QA agent (interactive Claude with QA context)
tmux new-window -t "$SESSION_NAME" -n "qa" -c "$REPO_ROOT"

if [ "$TARGET_URL" = "PENDING" ]; then
  tmux send-keys -t "$SESSION_NAME:qa" "claude" Enter
else
  tmux send-keys -t "$SESSION_NAME:qa" "claude" Enter
  # Give Claude a moment to start, then send the QA prompt
  sleep 2
  tmux send-keys -t "$SESSION_NAME:qa" "/qa --quick $TARGET_URL" Enter
fi

echo "tmux session '$SESSION_NAME' ready."
echo ""
echo "Windows:"
echo "  [code] — Your main coding session. Work on features here."
echo "  [qa]   — QA agent testing $TARGET_URL. Reports issues as found."
echo ""
echo "Commands:"
echo "  tmux attach -t $SESSION_NAME          # Connect"
echo "  Ctrl+B then N                          # Switch between code/qa"
echo "  Ctrl+B then W                          # Window picker"
echo "  bash $0 --kill                         # Kill session"
echo ""
echo "Workflow:"
echo "  1. Code in the [code] window"
echo "  2. Switch to [qa] to check for issues"
echo "  3. Tell the QA agent: '/qa --quick $TARGET_URL' to re-test after changes"
echo "  4. When done: '/qa $TARGET_URL' for a full QA pass"
echo ""

if [ -t 0 ]; then
  tmux attach -t "$SESSION_NAME"
fi
