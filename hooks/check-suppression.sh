#!/usr/bin/env bash
# PostToolUse hook: Check for suppression comments after Edit/Write
# Warns if @ts-ignore, eslint-disable, noinspection, or istanbul ignore were introduced

input=$(cat)
file_path=$(echo "$input" | grep -o '"file_path":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$file_path" ]; then
  exit 0
fi

# Only check code files
case "$file_path" in
  *.ts|*.tsx|*.js|*.jsx|*.py|*.xml)
    ;;
  *)
    exit 0
    ;;
esac

# Check if file exists
if [ ! -f "$file_path" ]; then
  exit 0
fi

# Search for suppression patterns
matches=$(grep -n -E '(@ts-ignore|@ts-expect-error|eslint-disable|noinspection|istanbul ignore|# type: ignore|# noqa|# pragma: no cover)' "$file_path" 2>/dev/null)

if [ -n "$matches" ]; then
  echo "WARNING: Suppression comments detected in $file_path:"
  echo "$matches"
  echo ""
  echo "Per CLAUDE.md rules, fix the underlying issue instead of suppressing it."
  # Exit 0 (warning only, don't block) — the prompt hook will surface this to Claude
  exit 0
fi

exit 0
