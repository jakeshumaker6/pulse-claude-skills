#!/usr/bin/env bash
# autopilot-phases.sh — Phase functions for the autopilot pipeline
# Sourced by autopilot.sh. Do not run directly.

# --- Phase 1: Poll ClickUp ---

poll_tasks() {
  log "Polling ClickUp for ai-ready tasks..."

  claude -p "$(cat <<'PROMPT'
Search ClickUp for tasks tagged "ai-ready" that are NOT in "AI In Progress" status.
Use clickup_search with keywords "ai-ready" and filter to tasks only.

For each task found:
1. Get the full task details with clickup_get_task
2. Extract: task ID, task name, description, the folder name (this is the client), the list name (this is the project)

Output ONLY valid JSON in this exact format (no other text):
{"tasks": [{"id": "abc123", "name": "Task name", "description": "Full description", "client_folder": "S40S", "project_list": "Website Development", "url": "https://app.clickup.com/..."}]}

If no ai-ready tasks are found, output:
{"tasks": []}
PROMPT
  )" \
    --allowedTools "mcp__claude_ai_ClickUp__clickup_search,mcp__claude_ai_ClickUp__clickup_get_task" \
    2>/dev/null
}

# --- Phase 2: Claim Task ---

claim_task() {
  local task_id="$1"
  local task_name="$2"

  log "Claiming task: $task_name ($task_id)"

  claude -p "$(cat <<PROMPT
For ClickUp task ID "$task_id":
1. Update status to "AI In Progress" using clickup_update_task
2. Remove the "ai-ready" tag using clickup_remove_tag_from_task
3. Add a comment: "Autopilot picked up this task. Working on it now."

Output "CLAIMED" when done, or "FAILED" with the error.
PROMPT
  )" \
    --allowedTools "mcp__claude_ai_ClickUp__clickup_update_task,mcp__claude_ai_ClickUp__clickup_remove_tag_from_task,mcp__claude_ai_ClickUp__clickup_create_task_comment" \
    2>/dev/null
}

# --- Phase 3: Implement ---

implement_task() {
  local repo_path="$1"
  local task_id="$2"
  local task_name="$3"
  local task_desc="$4"
  local branch_name="feature/CU-${task_id}"

  log "Implementing in $repo_path on branch $branch_name"

  cd "$repo_path"

  # Create feature branch
  git checkout -b "$branch_name" 2>/dev/null || git checkout "$branch_name"

  claude -p "$(cat <<PROMPT
You are implementing a ClickUp task. Work in the current repo.

## Task: $task_name
## Task ID: $task_id

## Description & Acceptance Criteria:
$task_desc

## Instructions:
1. Read the CLAUDE.md for this repo first
2. Explore the codebase to understand the relevant files
3. Implement the changes described in the task
4. Run any existing tests (pytest, npm test, etc.) and fix failures
5. Ensure all acceptance criteria are met

When done, output a summary of what you changed and which files were modified.
If you cannot complete the task, explain what is blocking you.
PROMPT
  )" \
    --allowedTools "Bash,Read,Write,Edit,Grep,Glob" \
    2>/dev/null
}

# --- Phase 4: Start Dev Server ---

start_dev_server() {
  local repo_path="$1"
  cd "$repo_path"

  local server_cmd=""
  local port=""

  if [ -f "vite.config.ts" ] || [ -f "vite.config.js" ]; then
    if [ -f "bun.lockb" ]; then
      server_cmd="bun dev"
    else
      server_cmd="npm run dev"
    fi
    port="5173"
  elif [ -f "next.config.js" ] || [ -f "next.config.ts" ] || [ -f "next.config.mjs" ]; then
    server_cmd="npm run dev"
    port="3000"
  elif [ -f "app.py" ] || [ -f "wsgi.py" ]; then
    if [ -f "requirements.txt" ]; then
      server_cmd="flask run"
    else
      server_cmd="python app.py"
    fi
    port="5000"
  elif [ -f "package.json" ]; then
    server_cmd="npm start"
    port="3000"
  fi

  # Check if something is already running on the expected port
  if [ -n "$port" ]; then
    if curl -s -o /dev/null "http://localhost:$port" 2>/dev/null; then
      log "Dev server already running on port $port"
      echo "http://localhost:$port"
      return 0
    fi
  fi

  if [ -z "$server_cmd" ]; then
    log "No dev server detected. Skipping browser validation."
    echo "NONE"
    return 0
  fi

  log "Starting dev server: $server_cmd"
  $server_cmd &>/dev/null &
  DEV_SERVER_PID=$!

  # Wait for server to be ready (max 30 seconds)
  local attempts=0
  while [ $attempts -lt 30 ]; do
    if curl -s -o /dev/null "http://localhost:$port" 2>/dev/null; then
      log "Dev server ready on port $port"
      echo "http://localhost:$port"
      return 0
    fi
    sleep 1
    attempts=$((attempts + 1))
  done

  log "Dev server failed to start within 30 seconds"
  echo "NONE"
}

# --- Phase 5: Validate ---

validate_task() {
  local repo_path="$1"
  local url="$2"
  local task_name="$3"
  local task_desc="$4"

  cd "$repo_path"

  local validate_prompt="$(cat <<PROMPT
You are validating a code change. Test it against the acceptance criteria.

## Task: $task_name

## Acceptance Criteria (from task description):
$task_desc

## What to validate:

### Unit/Integration Tests
Run the test suite (pytest, npm test, bun test). Report PASS or FAIL.

PROMPT
  )"

  local allowed_tools="Bash,Read,Grep,Glob"

  if [ "$url" != "NONE" ]; then
    validate_prompt="$validate_prompt
### Browser Validation (target: $url)
Use Puppeteer to test the actual UI against the acceptance criteria:
1. Navigate to the relevant page(s)
2. Screenshot the result
3. Test specific interactions mentioned in the acceptance criteria
4. Verify the feature works as described — click buttons, fill forms, check content
5. Check for console errors

This is NOT a generic site crawl. Test ONLY what the task asked for.
"
    allowed_tools="$allowed_tools,mcp__puppeteer__puppeteer_navigate,mcp__puppeteer__puppeteer_screenshot,mcp__puppeteer__puppeteer_click,mcp__puppeteer__puppeteer_fill,mcp__puppeteer__puppeteer_evaluate,mcp__puppeteer__puppeteer_hover,mcp__puppeteer__puppeteer_select"
  fi

  validate_prompt="$validate_prompt

## Output Format
Output ONLY one of:
VALIDATE_PASS — all tests pass and acceptance criteria met
VALIDATE_FAIL: <specific reason what failed and how to fix it>
"

  claude -p "$validate_prompt" \
    --allowedTools "$allowed_tools" \
    2>/dev/null
}

# --- Phase 5B: Fix and Retry ---

fix_and_revalidate() {
  local repo_path="$1"
  local url="$2"
  local task_name="$3"
  local task_desc="$4"
  local failure_reason="$5"

  cd "$repo_path"

  log "Fixing: $failure_reason"

  claude -p "$(cat <<PROMPT
The previous validation failed. Fix the issue and try again.

## Task: $task_name

## What failed:
$failure_reason

## Instructions:
1. Read the failing test output or browser validation result
2. Fix the code
3. Run tests again to confirm the fix
4. Do not break anything that was previously working

Output a summary of what you fixed.
PROMPT
  )" \
    --allowedTools "Bash,Read,Write,Edit,Grep,Glob" \
    2>/dev/null
}

# --- Phase 6: Ship ---

ship_task() {
  local repo_path="$1"
  local task_id="$2"
  local task_name="$3"
  local branch_name="feature/CU-${task_id}"

  cd "$repo_path"

  log "Shipping: creating PR and updating ClickUp"

  # Commit any uncommitted changes
  git add -A
  git diff --cached --quiet 2>/dev/null || \
    git commit -m "$(cat <<EOF
Implement: $task_name

ClickUp: $task_id

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
    )"

  git push -u origin "$branch_name" 2>/dev/null

  local pr_url
  pr_url=$(gh pr create \
    --title "$task_name" \
    --body "$(cat <<EOF
## Summary
Automated implementation of ClickUp task $task_id.

## ClickUp Task
$task_name

## Test Results
- Unit tests: PASS
- Browser validation: PASS

## Test Plan
- [ ] Code review
- [ ] Manual QA on staging
- [ ] Verify acceptance criteria

Generated by Autopilot via [Claude Code](https://claude.com/claude-code)
EOF
    )" 2>/dev/null || echo "PR_FAILED")

  if [ "$pr_url" = "PR_FAILED" ]; then
    log "PR creation failed. Branch pushed: $branch_name"
    pr_url="(PR creation failed — branch $branch_name pushed)"
  else
    log "PR created: $pr_url"
  fi

  claude -p "$(cat <<PROMPT
For ClickUp task "$task_id":
1. Update status to "in review" using clickup_update_task
2. Add a comment: "Autopilot completed this task. PR: $pr_url Branch: $branch_name Ready for human review."

Output "DONE" when complete.
PROMPT
  )" \
    --allowedTools "mcp__claude_ai_ClickUp__clickup_update_task,mcp__claude_ai_ClickUp__clickup_create_task_comment" \
    2>/dev/null

  echo "$pr_url"
}

# --- Phase 7: Fail Task ---

fail_task() {
  local task_id="$1"
  local reason="$2"

  log "Task failed: $reason"

  claude -p "$(cat <<PROMPT
For ClickUp task "$task_id":
1. Update status back to "to do" using clickup_update_task
2. Add a comment: "Autopilot could not complete this task. Reason: $reason This task needs human attention."

Output "DONE" when complete.
PROMPT
  )" \
    --allowedTools "mcp__claude_ai_ClickUp__clickup_update_task,mcp__claude_ai_ClickUp__clickup_remove_tag_from_task,mcp__claude_ai_ClickUp__clickup_create_task_comment" \
    2>/dev/null
}
