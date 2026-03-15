#!/usr/bin/env bash
# multi-client.sh — Run parallel Claude sessions scoped to different client repos
#
# Usage:
#   bash scripts/multi-client.sh                    # Interactive: pick clients
#   bash scripts/multi-client.sh s40s dcc           # Launch specific clients
#   bash scripts/multi-client.sh --list             # Show available clients
#   bash scripts/multi-client.sh --kill             # Kill all agent sessions
#
# Requires: Claude Code CLI (`claude`), tmux
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
CLIENTS_DIR="$REPO_DIR/context/clients"
SESSION_NAME="pulse-agents"

# Client → repo path mapping
# Add entries here as you onboard new client repos
declare -A CLIENT_REPOS
CLIENT_REPOS=(
  ["s40s"]="/Users/jakes1/Documents/claude-code/S40S/s40s-odoo"
  ["dcc"]="/Users/jakes1/Documents/claude-code/DCC"
  ["gaapp"]="/Users/jakes1/Documents/claude-code/GAAPP"
  ["swg"]="/Users/jakes1/Documents/claude-code/SWG"
  ["pulse"]="/Users/jakes1/Documents/claude-code/Pulse"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Functions ---

list_clients() {
  echo "Available clients:"
  echo ""
  for client in "${!CLIENT_REPOS[@]}"; do
    repo="${CLIENT_REPOS[$client]}"
    if [ -d "$repo" ]; then
      echo -e "  ${GREEN}${client}${NC} → ${repo}"
    else
      echo -e "  ${RED}${client}${NC} → ${repo} (NOT FOUND)"
    fi
  done
  echo ""
  echo "Edit CLIENT_REPOS in this script to add/change mappings."
}

kill_sessions() {
  if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    tmux kill-session -t "$SESSION_NAME"
    echo "Killed tmux session: $SESSION_NAME"
  else
    echo "No active session: $SESSION_NAME"
  fi
}

launch_client_pane() {
  local client="$1"
  local repo="${CLIENT_REPOS[$client]}"
  local context_file="$CLIENTS_DIR/$client/overview.md"

  if [ ! -d "$repo" ]; then
    echo -e "${RED}Skipping $client — repo not found at $repo${NC}"
    return 1
  fi

  # Build the system prompt with client context
  local context=""
  if [ -f "$context_file" ]; then
    context="$(cat "$context_file")"
  fi

  local prompt="You are working on the ${client^^} client project for Pulse Integrated.

## Client Context
${context}

## Your Role
You are a dedicated engineer for this client. Focus on:
- Reading and understanding the codebase
- Implementing features and fixes as directed
- Running tests and QA
- Preparing code for review

Wait for instructions. When idle, you can explore the codebase to build context."

  echo "$prompt"
}

# --- Main ---

# Check dependencies
if ! command -v tmux &>/dev/null; then
  echo "Error: tmux is required. Install with: brew install tmux"
  exit 1
fi

if ! command -v claude &>/dev/null; then
  echo "Error: 'claude' CLI not found. Install Claude Code first."
  exit 1
fi

# Handle flags
case "${1:-}" in
  --list)
    list_clients
    exit 0
    ;;
  --kill)
    kill_sessions
    exit 0
    ;;
esac

# Determine which clients to launch
CLIENTS=("$@")

if [ ${#CLIENTS[@]} -eq 0 ]; then
  echo "No clients specified. Available:"
  echo ""
  list_clients
  echo "Usage: $0 <client1> <client2> ..."
  exit 1
fi

# Validate all clients before launching
for client in "${CLIENTS[@]}"; do
  if [ -z "${CLIENT_REPOS[$client]+x}" ]; then
    echo -e "${RED}Unknown client: $client${NC}"
    echo "Run '$0 --list' to see available clients."
    exit 1
  fi
done

# Kill existing session if any
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
  echo "Killing existing session..."
  tmux kill-session -t "$SESSION_NAME"
fi

# Create new tmux session with first client
first_client="${CLIENTS[0]}"
first_repo="${CLIENT_REPOS[$first_client]}"

echo -e "Launching ${GREEN}${#CLIENTS[@]}${NC} client sessions..."
echo ""

tmux new-session -d -s "$SESSION_NAME" -c "$first_repo" -n "$first_client"
tmux send-keys -t "$SESSION_NAME:$first_client" "cd '$first_repo' && claude" Enter

# Add panes for remaining clients
for ((i=1; i<${#CLIENTS[@]}; i++)); do
  client="${CLIENTS[$i]}"
  repo="${CLIENT_REPOS[$client]}"

  if [ ! -d "$repo" ]; then
    echo -e "${YELLOW}Skipping $client — repo not found${NC}"
    continue
  fi

  tmux new-window -t "$SESSION_NAME" -n "$client" -c "$repo"
  tmux send-keys -t "$SESSION_NAME:$client" "cd '$repo' && claude" Enter
done

echo "tmux session '$SESSION_NAME' ready with ${#CLIENTS[@]} windows."
echo ""
echo "Commands:"
echo "  tmux attach -t $SESSION_NAME          # Connect to the session"
echo "  Ctrl+B then N                          # Next client window"
echo "  Ctrl+B then P                          # Previous client window"
echo "  Ctrl+B then W                          # Window picker"
echo "  bash $0 --kill                         # Kill all sessions"
echo ""

# Auto-attach if running interactively
if [ -t 0 ]; then
  tmux attach -t "$SESSION_NAME"
fi
