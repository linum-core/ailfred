#!/usr/bin/env bash
# Scaffold the runtime folder of one goal from the plugin templates.
#
# Usage: bash "$CLAUDE_PLUGIN_ROOT/scripts/ailfred-scaffold.sh" <slug> ["Título do goal"]
#   Writes into <repo>/.claude/ailfred/<slug>/ (override the repo with AILFRED_REPO_ROOT).
#
# Idempotent: an existing goal folder is never overwritten — it prints EXISTS and
# returns 0 so /ailfred can resume planning instead of losing approved content.
set -euo pipefail

# Root resolution (plugin-aware):
#   PLUGIN_ROOT — where this kit's own assets live (templates, sibling scripts).
#     ${CLAUDE_PLUGIN_ROOT} when running as an installed plugin; otherwise derived
#     from this script's own path, so it also works straight from the repo.
#   REPO_ROOT   — the project being worked on: where .claude/ailfred/<slug>/ is written.
#     Never derived from the script path: the plugin may live in the plugin cache.
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

resolve_repo_root() {
  if [ -n "${AILFRED_REPO_ROOT:-}" ]; then printf '%s\n' "$AILFRED_REPO_ROOT"; return 0; fi
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

ROOT="$(resolve_repo_root)"
TPL="${PLUGIN_ROOT}/templates/ailfred"
slug="${1:-}"
title="${2:-$slug}"

if [ -z "$slug" ]; then
  echo "ERROR: slug required — bash \"$PLUGIN_ROOT/scripts/ailfred-scaffold.sh\" <slug> [\"title\"]" >&2
  exit 1
fi
case "$slug" in
  *[^a-z0-9-]*) echo "ERROR: slug must be kebab-case ([a-z0-9-]): '$slug'" >&2; exit 1 ;;
esac
[ -d "$TPL" ] || { echo "ERROR: templates not found at ${TPL}" >&2; exit 1; }

DST="${ROOT}/.claude/ailfred/${slug}"
if [ -d "$DST" ]; then
  echo "EXISTS: .claude/ailfred/${slug} — nothing copied (resume instead of re-scaffolding)"
  exit 0
fi

# sed replacement safety: & and | are special in the replacement string.
title="$(printf '%s' "$title" | tr '|&' '  ')"
today="$(date +%F)"

# Branch name, resolved in a way that survives the awkward cases:
#   * repo with zero commits — `rev-parse --abbrev-ref HEAD` prints "HEAD" AND exits
#     non-zero, so `cmd || echo fallback` would yield TWO lines and break the sed below;
#   * detached HEAD — falls back to the short sha;
#   * no git at all — "no-git".
branch="$(git -C "$ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || true)"
[ -n "$branch" ] || branch="$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || true)"
[ -n "$branch" ] || branch="no-git"
branch="${branch%%$'\n'*}"   # defensive: never let a multi-line value reach sed

mkdir -p "${DST}/tasks" "${DST}/steps" "${DST}/evidence"
# A half-written goal folder would block the next run with EXISTS; drop it on failure.
trap 'rm -rf "$DST"' EXIT
for f in PRD.md plan.md REVIEW.md state.yaml; do
  sed -e "s|{{SLUG}}|${slug}|g" \
      -e "s|{{TITLE}}|${title}|g" \
      -e "s|{{DATE}}|${today}|g" \
      -e "s|{{BRANCH}}|${branch}|g" \
      "${TPL}/${f}" > "${DST}/${f}"
  echo "created .claude/ailfred/${slug}/${f}"
done

cat > "${DST}/tasks/.gitkeep" <<'EOF'
EOF
cat > "${DST}/steps/.gitkeep" <<'EOF'
EOF
cat > "${DST}/evidence/.gitkeep" <<'EOF'
EOF

trap - EXIT
echo "OK: goal scaffolded at .claude/ailfred/${slug} (base branch: ${branch})"
echo "next: ailfred-architect writes PRD.md (discovery), host owns state.yaml"
