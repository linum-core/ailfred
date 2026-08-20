#!/usr/bin/env bash
# Create the per-repository memory vault, if it does not exist yet.
#
# Usage: bash "$CLAUDE_PLUGIN_ROOT/scripts/ailfred-memory-init.sh"
#   stdout: CREATED <path>   (first run)
#           EXISTS  <path>   (any later run)
#
# The vault lives OUTSIDE the user's repository, at
#   ~/.claude/ailfred/project/<project-slug>/memory/
# so it is never committed. Plain markdown; Obsidian is an optional reader and
# `.obsidian/` is never created here.
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
TPL="${PLUGIN_ROOT}/templates/ailfred/memory"
[ -d "$TPL" ] || { echo "ERROR: memory templates not found at ${TPL}" >&2; exit 1; }

project_slug="$(bash "${PLUGIN_ROOT}/scripts/ailfred-project-slug.sh")"
vault="$(bash "${PLUGIN_ROOT}/scripts/ailfred-project-slug.sh" --path)/memory"

if [ -f "${vault}/MOC.md" ]; then
  printf 'EXISTS %s\n' "$vault"
  exit 0
fi

mkdir -p "${vault}/architecture" "${vault}/decisions" "${vault}/goals" \
         "${vault}/surfaces" "${vault}/pitfalls"
sed "s/{{PROJECT_SLUG}}/${project_slug}/g" "${TPL}/MOC.md" > "${vault}/MOC.md"

printf 'CREATED %s\n' "$vault"
