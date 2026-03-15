#!/usr/bin/env bash
# SessionStart hook: Pull latest pulse-claude-skills on session start
# Ensures client meetings and shared context are always up to date

SKILLS_REPO="$HOME/.claude/skills/pulse-claude-skills"

if [ -d "$SKILLS_REPO/.git" ]; then
  cd "$SKILLS_REPO" && git pull --ff-only --quiet 2>/dev/null
fi
