#!/usr/bin/env bash
# Claude Code Status Line
# Shows: git branch | token cost estimate | active project | skill count

set -euo pipefail

# Git branch
branch=""
if git rev-parse --git-dir &>/dev/null 2>&1; then
  branch=$(git branch --show-current 2>/dev/null || echo "detached")
fi

# Project name from directory
project=$(basename "${CLAUDE_PROJECT_DIR:-$(pwd)}")

# Skill count
skill_count=$(ls ~/.claude/skills/ 2>/dev/null | wc -l | tr -d ' ')

# Plugin count
plugin_count=$(cat ~/.claude/settings.json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('enabledPlugins',{})))" 2>/dev/null || echo "?")

# Format output
parts=()
[ -n "$branch" ] && parts+=("⎇ $branch")
parts+=("📂 $project")
parts+=("🧩 ${skill_count} skills")
parts+=("🔌 ${plugin_count} plugins")

echo "${parts[*]}"
