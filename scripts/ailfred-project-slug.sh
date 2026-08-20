#!/usr/bin/env bash
# Resolve the <project-slug> of the repository being worked on.
#
# Usage: bash "$CLAUDE_PLUGIN_ROOT/scripts/ailfred-project-slug.sh" [--path]
#   (no flag) stdout: <project-slug>
#   --path    stdout: ~/.claude/ailfred/project/<project-slug>   (absolute, not created)
#
# THE single source of this logic. No other file re-implements it.
#
# slug = kebab-cased basename of the git toplevel + "-" + first 8 chars of the
# SHA-1 of its absolute path. The hash suffix keeps two repos with the same
# folder name from sharing one memory vault.
#
# Worktree-aware: a linked git worktree resolves to the MAIN worktree, so every
# worktree of a repo shares one memory.
set -euo pipefail

usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; }

want_path=0
case "${1:-}" in
  --path) want_path=1 ;;
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) echo "ERROR: unknown argument '$1'" >&2; usage >&2; exit 1 ;;
esac

resolve_repo_root() {
  if [ -n "${AILFRED_REPO_ROOT:-}" ]; then (cd "$AILFRED_REPO_ROOT" && pwd); return 0; fi
  local common
  # --git-common-dir points at the MAIN worktree's .git even from a linked worktree.
  if common="$(git rev-parse --git-common-dir 2>/dev/null)"; then
    case "$common" in
      /*) (cd "$(dirname "$common")" && pwd) ;;
      *)  git rev-parse --show-toplevel ;;
    esac
    return 0
  fi
  pwd
}

sha1_of() {
  if command -v shasum >/dev/null 2>&1; then printf '%s' "$1" | shasum | cut -c1-8
  elif command -v sha1sum >/dev/null 2>&1; then printf '%s' "$1" | sha1sum | cut -c1-8
  else echo "ERROR: neither shasum nor sha1sum available" >&2; exit 1
  fi
}

ROOT="$(resolve_repo_root)"
base="$(basename "$ROOT")"
slug="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]' | tr ' _.' '-' | tr -cd 'a-z0-9-')"
slug="$(printf '%s' "$slug" | sed -e 's/--*/-/g' -e 's/^-//' -e 's/-$//')"
[ -n "$slug" ] || slug="repo"
hash="$(sha1_of "$ROOT")"
project_slug="${slug}-${hash}"

if [ "$want_path" -eq 1 ]; then
  printf '%s\n' "${AILFRED_HOME:-$HOME/.claude/ailfred}/project/${project_slug}"
else
  printf '%s\n' "$project_slug"
fi
