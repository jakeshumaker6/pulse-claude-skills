#!/usr/bin/env bash
# PostToolUse hook: Warn when a file exceeds 500 lines after Edit/Write
# Enforces CLAUDE.md max file size rule

input=$(cat)
file_path=$(echo "$input" | grep -o '"file_path":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$file_path" ]; then
  exit 0
fi

if [ ! -f "$file_path" ]; then
  exit 0
fi

line_count=$(wc -l < "$file_path" | tr -d ' ')

if [ "$line_count" -gt 500 ]; then
  echo "WARNING: $file_path is $line_count lines (max 500). Consider extracting into sibling modules."
fi

exit 0
