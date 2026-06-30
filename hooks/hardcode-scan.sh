#!/usr/bin/env bash
# Global PostToolUse hook: scan files just written/edited for hardcode smells.
# Receives hook payload on stdin as JSON; extracts file_path; greps it.
# Emits an advisory message to stderr if hits are found. Never blocks.

set -euo pipefail

payload=$(cat)

# Extract file_path from payload; exit if we can't parse or it's not a code file
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
    *.py|*.ts|*.tsx|*.js|*.jsx|*.go|*.rs|*.sol|*.rb|*.sh|*.yml|*.yaml) ;;
    *) exit 0 ;;
esac

case "$file_path" in
    *test*|*fixture*|*spec*|*.md|*.json|*.log|*.lock) exit 0 ;;
esac

findings=""

# Pattern 1: production URLs inlined
url_hits=$(grep -nE '"https?://(api|rpc|mainnet|prod|production)[^"]+"' "$file_path" 2>/dev/null \
    | grep -v -E '# |// |/\*|default=|fallback|comment' || true)
[ -n "$url_hits" ] && findings+="\n[urls] $url_hits"

# Pattern 2: on-chain addresses
addr_hits=$(grep -nE '"0x[a-fA-F0-9]{40}"' "$file_path" 2>/dev/null \
    | grep -v -E '0x0{40}|# |// |test|fixture|default=|fallback' || true)
[ -n "$addr_hits" ] && findings+="\n[addresses] $addr_hits"

# Pattern 3: schedule literals
sched_hits=$(grep -nE 'schedule\.every.*\.at\("[0-9]{2}:[0-9]{2}"\)' "$file_path" 2>/dev/null || true)
[ -n "$sched_hits" ] && findings+="\n[schedule] $sched_hits"

# Pattern 4: pinned Docker tags in code (not in config files)
docker_hits=$(grep -nE '"[a-zA-Z0-9./_-]+:[0-9]+\.[0-9]+\.[0-9]+"' "$file_path" 2>/dev/null \
    | grep -v -E 'requirements|package|config/|# |// ' || true)
[ -n "$docker_hits" ] && findings+="\n[docker-tags] $docker_hits"

# Pattern 5: model IDs
model_hits=$(grep -nE '"(claude|gpt|gemini|deepseek|kimi|llama|mini[Mm]ax)-[a-zA-Z0-9.-]+"' "$file_path" 2>/dev/null \
    | grep -v -E 'config/|models\.json|# |// ' || true)
[ -n "$model_hits" ] && findings+="\n[model-ids] $model_hits"

if [ -n "$findings" ]; then
    cat >&2 <<EOF
⚠️  hardcode-scan detected patterns that may violate the no-hardcoded-values rule
file: $file_path$findings

run the hardcode-audit skill to review; move offenders to config or dynamic lookup where appropriate.
(this is an advisory — not blocking)
EOF
fi

exit 0
