#!/usr/bin/env bash
# PreToolUse hook: Block writing files that likely contain secrets
# Runs before Write/Edit on .env, credentials, key files

input=$(cat)
file_path=$(echo "$input" | grep -o '"file_path":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$file_path" ]; then
  exit 0
fi

basename=$(basename "$file_path")
dirname=$(dirname "$file_path")

# Block .env files
case "$basename" in
  .env|.env.*|*.env)
    echo "BLOCKED: Cannot write to $basename — credentials belong in environment variables or secret managers, not in files tracked by Claude."
    exit 2
    ;;
esac

# Block known credential files
case "$basename" in
  credentials.json|service-account*.json|*-key.json|*.pem|*.key)
    echo "BLOCKED: Cannot write to $basename — this looks like a credentials file."
    exit 2
    ;;
esac

exit 0
