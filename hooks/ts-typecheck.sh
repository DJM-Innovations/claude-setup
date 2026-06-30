#!/usr/bin/env bash
# Smart TypeScript Type-Check Hook (PostToolUse on Edit|Write)
# Detects project package manager and runs tsc --noEmit on edited .ts/.tsx files
# Works across any TypeScript project (Next.js, Node, React, etc.)

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat)

# Extract file path from hook input
FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    r = d.get('tool_response', d.get('tool_input', {}))
    print(r.get('filePath', r.get('file_path', '')))
except:
    print('')
" 2>/dev/null)

# Skip if not a TypeScript file
case "$FILE_PATH" in
  *.ts|*.tsx) ;;
  *) echo '{}'; exit 0 ;;
esac

# Skip node_modules, dist, .next, build
case "$FILE_PATH" in
  */node_modules/*|*/dist/*|*/.next/*|*/build/*|*/.claude/*) echo '{}'; exit 0 ;;
esac

# Find project root (look for tsconfig.json)
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
TSCONFIG=""
CHECK_DIR=$(dirname "$FILE_PATH")
while [ "$CHECK_DIR" != "/" ] && [ "$CHECK_DIR" != "." ]; do
  if [ -f "$CHECK_DIR/tsconfig.json" ]; then
    TSCONFIG="$CHECK_DIR/tsconfig.json"
    PROJECT_DIR="$CHECK_DIR"
    break
  fi
  CHECK_DIR=$(dirname "$CHECK_DIR")
done

# No tsconfig found — skip
if [ -z "$TSCONFIG" ]; then
  echo '{}'
  exit 0
fi

# Run tsc --noEmit with timeout
ERRORS=$(cd "$PROJECT_DIR" && npx tsc --noEmit --pretty false 2>&1 | grep "$FILE_PATH" | head -10) || true

if [ -n "$ERRORS" ]; then
  # Format for Claude
  MSG=$(printf '⚠️ TypeScript errors in %s:\n\n%s\n\nFix these before proceeding.' "$(basename "$FILE_PATH")" "$ERRORS")
  # Escape for JSON
  MSG_ESCAPED=$(echo "$MSG" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null)
  echo "{\"decision\":\"block\",\"reason\":${MSG_ESCAPED}}"
else
  echo '{}'
fi
