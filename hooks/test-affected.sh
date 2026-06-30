#!/usr/bin/env bash
# Smart Test Runner Hook (PostToolUse on Edit|Write)
# After editing source files, suggests running affected tests
# Does NOT run tests automatically — injects a reminder so Claude does it

set -euo pipefail

INPUT=$(cat)

FILE_PATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    r = d.get('tool_response', d.get('tool_input', {}))
    print(r.get('filePath', r.get('file_path', '')))
except:
    print('')
" 2>/dev/null)

# Only trigger for source files, not test files or configs
case "$FILE_PATH" in
  *.test.*|*.spec.*|*.config.*|*/__tests__/*) echo '{}'; exit 0 ;;
  *.ts|*.tsx|*.js|*.jsx|*.py) ;;
  *) echo '{}'; exit 0 ;;
esac

# Skip non-source directories
case "$FILE_PATH" in
  */node_modules/*|*/dist/*|*/.next/*|*/build/*|*/.claude/*) echo '{}'; exit 0 ;;
esac

# Find corresponding test file
BASENAME=$(basename "$FILE_PATH" | sed 's/\.[^.]*$//')
DIR=$(dirname "$FILE_PATH")
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"

TEST_FILE=""
for ext in ".test.ts" ".test.tsx" ".spec.ts" ".spec.tsx" ".test.js" ".test.jsx" "_test.py" "_test.go"; do
  candidate="$DIR/${BASENAME}${ext}"
  if [ -f "$candidate" ]; then
    TEST_FILE="$candidate"
    break
  fi
  # Check __tests__ directory
  candidate="$DIR/__tests__/${BASENAME}${ext}"
  if [ -f "$candidate" ]; then
    TEST_FILE="$candidate"
    break
  fi
  # Check test/ directory (relative to project root)
  candidate="$PROJECT_DIR/test/${BASENAME}${ext}"
  if [ -f "$candidate" ]; then
    TEST_FILE="$candidate"
    break
  fi
done

if [ -n "$TEST_FILE" ]; then
  REL_TEST=$(python3 -c "import os.path; print(os.path.relpath('$TEST_FILE', '$PROJECT_DIR'))" 2>/dev/null || echo "$TEST_FILE")
  REL_SRC=$(python3 -c "import os.path; print(os.path.relpath('$FILE_PATH', '$PROJECT_DIR'))" 2>/dev/null || echo "$FILE_PATH")

  MSG="📋 Source file \`${REL_SRC}\` was modified. Related test exists: \`${REL_TEST}\`. Consider running it to verify changes."
  MSG_ESCAPED=$(echo "$MSG" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read()))" 2>/dev/null)

  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PostToolUse\",\"additionalContext\":${MSG_ESCAPED}}}"
else
  echo '{}'
fi
