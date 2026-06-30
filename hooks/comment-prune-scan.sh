#!/usr/bin/env bash
# Global PostToolUse hook: scans files for self-explanatory comments per
# ~/.claude/rules/prune-self-explanatory-comments.md.
# Reads hook payload on stdin as JSON; extracts file_path; greps it.
# Emits advisory to stderr if hits are found. Never blocks.

set -euo pipefail

payload=$(cat)

file_path=$(printf '%s' "$payload" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    path = data.get('tool_input', {}).get('file_path') or data.get('tool_response', {}).get('filePath')
    print(path or '')
except Exception:
    pass
" 2>/dev/null || true)

[ -z "$file_path" ] && exit 0
[ ! -f "$file_path" ] && exit 0

case "$file_path" in
    *.py|*.ts|*.tsx|*.js|*.jsx|*.go|*.rs|*.rb) ;;
    *) exit 0 ;;
esac

case "$file_path" in
    *.test.*|*.spec.*|*/__tests__/*|*/fixtures/*|*.d.ts) exit 0 ;;
esac

# Verbs that are obvious restatements when followed by the same identifier
# the next line uses. Conservative list — high precision over recall.
restate_verbs='Loop through|Iterate (over|through)|Fetch the|Get the|Set the|Check (if|whether)|Initialize|Create the|Insert (the |into)|Update the|Delete the|Return the|Render (the )?[A-Z]|Add (the )?[a-z]+ to|Remove (the )?[a-z]+ from|Calculate the|Build the|Parse the|Convert .* to|Format the|Validate the|Log the|Print the|Loop over|Increment|Decrement|Assign|Declare|Define the'

# Match `// <verb> ...` or `# <verb> ...` lines, excluding JSDoc, dividers,
# and lines that contain why-words (why, because, TODO, FIXME, HACK, NOTE,
# fallback, tradeoff, constraint, gotcha, defense, security, race, lint,
# eslint, see, docs, http, https, eip, rfc).
hits=$(grep -nE "^[[:space:]]*(//|#)[[:space:]]+(${restate_verbs})\b" "$file_path" 2>/dev/null \
    | grep -viE 'why|because|TODO|FIXME|HACK|NOTE:|NOTE -|fallback|tradeoff|constraint|gotcha|defense|security|race condition|eslint|lint:|see |https?://|eip-|rfc[ -]|\* @|====|----' \
    || true)

# JSX comment-above-same-element pattern: `{/* X */}` line followed by `<X` line
jsx_hits=$(awk '
    /^[[:space:]]*\{\/\*[[:space:]]*[A-Z][A-Za-z]+[[:space:]]*\*\/\}[[:space:]]*$/ {
        match($0, /[A-Z][A-Za-z]+/);
        word=substr($0, RSTART, RLENGTH);
        prev_line=NR; prev_word=word; next
    }
    prev_line && NR == prev_line + 1 {
        if (index($0, "<" prev_word) > 0) {
            printf "%d:%s\n", prev_line, prev_word
        }
        prev_line=0
    }
' "$file_path" 2>/dev/null || true)

findings=""
nl=$'\n'
[ -n "$hits" ] && findings+="${nl}[restating-verbs]${nl}${hits}"
[ -n "$jsx_hits" ] && findings+="${nl}[jsx-comment-restates-element]${nl}${jsx_hits}"

if [ -n "$findings" ]; then
    cat >&2 <<EOF
⚠️  comment-prune-scan: candidate self-explanatory comments detected
file: $file_path$findings

apply ~/.claude/rules/prune-self-explanatory-comments.md heuristic: if deleting the
comment leaves the code understandable, delete it. keep only why / constraint /
tradeoff / non-obvious context.
(advisory — not blocking)
EOF
fi

exit 0
