#!/usr/bin/env bash
# git worktree helper for parallel task execution driven by /ailfred-execute.
#
# Usage:
#   bash "$CLAUDE_PLUGIN_ROOT/scripts/ailfred-worktree.sh" add       <slug> <task-id> [base-branch]
#   bash "$CLAUDE_PLUGIN_ROOT/scripts/ailfred-worktree.sh" list      [slug]
#   bash "$CLAUDE_PLUGIN_ROOT/scripts/ailfred-worktree.sh" status    <slug> <task-id>
#   bash "$CLAUDE_PLUGIN_ROOT/scripts/ailfred-worktree.sh" integrate <slug> <task-id> [into-branch]
#   bash "$CLAUDE_PLUGIN_ROOT/scripts/ailfred-worktree.sh" remove    <slug> <task-id> [--force]
#
# Layout (outside the repo, so it never pollutes the working tree):
#   ../.ailfred-worktrees/<repo-name>/<slug>/<task-id>   on branch ailfred/<slug>/<task-id>
#
# Exit codes: 0 ok | 1 usage/precondition error | 2 merge conflict (agent must resolve)
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
REPO="$(basename "$ROOT")"
WT_BASE="$(cd "${ROOT}/.." && pwd)/.ailfred-worktrees/${REPO}"

action="${1:-}"; shift || true

wt_path() { printf '%s/%s/%s' "$WT_BASE" "$1" "$2"; }
wt_branch() { printf 'ailfred/%s/%s' "$1" "$2"; }

require_args() {
  [ -n "${1:-}" ] && [ -n "${2:-}" ] || {
    echo "ERROR: <slug> and <task-id> required" >&2; exit 1; }
}

case "$action" in
  add)
    slug="${1:-}"; task="${2:-}"; base="${3:-}"
    require_args "$slug" "$task"
    # A worktree needs a commit to branch from; a fresh repo has none and git would fail
    # with an unrelated "use -- to separate paths" message.
    git -C "$ROOT" rev-parse --verify --quiet HEAD >/dev/null || {
      echo "ERROR: ${ROOT} has no commits yet — commit once before creating worktrees" >&2
      exit 1; }
    [ -n "$base" ] || base="$(git -C "$ROOT" symbolic-ref --quiet --short HEAD 2>/dev/null || git -C "$ROOT" rev-parse --short HEAD)"
    path="$(wt_path "$slug" "$task")"; branch="$(wt_branch "$slug" "$task")"
    if [ -d "$path" ]; then
      echo "EXISTS: ${path} (branch ${branch}) — reuse it"
      exit 0
    fi
    mkdir -p "$(dirname "$path")"
    if git -C "$ROOT" show-ref --verify --quiet "refs/heads/${branch}"; then
      git -C "$ROOT" worktree add "$path" "$branch"
    else
      git -C "$ROOT" worktree add -b "$branch" "$path" "$base"
    fi
    echo "WORKTREE_PATH=${path}"
    echo "WORKTREE_BRANCH=${branch}"
    echo "WORKTREE_BASE=${base}"
    ;;

  list)
    slug="${1:-}"
    # substr, not $2: worktree paths may contain spaces.
    git -C "$ROOT" worktree list --porcelain \
      | awk '/^worktree /{p=substr($0,10)} /^branch /{b=substr($0,8); sub(/^refs\/heads\//,"",b); print b"\t"p}' \
      | { if [ -n "$slug" ]; then grep "^ailfred/${slug}/" || true; else cat; fi; }
    ;;

  status)
    slug="${1:-}"; task="${2:-}"; require_args "$slug" "$task"
    path="$(wt_path "$slug" "$task")"
    [ -d "$path" ] || { echo "MISSING: ${path}"; exit 1; }
    echo "PATH=${path}"
    echo "BRANCH=$(git -C "$path" rev-parse --abbrev-ref HEAD)"
    echo "DIRTY_FILES=$(git -C "$path" status --porcelain | wc -l | tr -d ' ')"
    echo "COMMITS_AHEAD=$(git -C "$path" rev-list --count "$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)..HEAD" 2>/dev/null || echo '?')"
    git -C "$path" status --short | head -20
    ;;

  integrate)
    slug="${1:-}"; task="${2:-}"; into="${3:-}"; require_args "$slug" "$task"
    branch="$(wt_branch "$slug" "$task")"
    path="$(wt_path "$slug" "$task")"
    [ -d "$path" ] || { echo "ERROR: worktree ${path} not found" >&2; exit 1; }
    if [ -n "$(git -C "$path" status --porcelain)" ]; then
      echo "ERROR: worktree ${path} has uncommitted changes — the task worker must commit before integration" >&2
      exit 1
    fi
    [ -n "$into" ] || into="$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)"
    if [ "$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)" != "$into" ]; then
      echo "ERROR: repo root is on '$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)', expected '${into}' — checkout first" >&2
      exit 1
    fi
    if [ -n "$(git -C "$ROOT" status --porcelain)" ]; then
      echo "ERROR: repo root has uncommitted changes — integration needs a clean tree" >&2
      exit 1
    fi
    set +e
    git -C "$ROOT" merge --no-ff --no-edit "$branch"
    code=$?
    set -e
    if [ $code -ne 0 ]; then
      echo "CONFLICT: merge of ${branch} into ${into} stopped — resolve, then 'git commit'"
      git -C "$ROOT" diff --name-only --diff-filter=U
      exit 2
    fi
    echo "MERGED=${branch} -> ${into}"
    ;;

  remove)
    slug="${1:-}"; task="${2:-}"; force="${3:-}"; require_args "$slug" "$task"
    path="$(wt_path "$slug" "$task")"
    branch="$(wt_branch "$slug" "$task")"
    [ -d "$path" ] || { echo "MISSING: ${path} (nothing to remove)"; exit 0; }
    dirty="$(git -C "$path" status --porcelain | wc -l | tr -d ' ')"
    if [ "$dirty" != "0" ] && [ "$force" != "--force" ]; then
      echo "REFUSED: ${path} has ${dirty} uncommitted change(s). Ask the developer before discarding, then re-run with --force." >&2
      exit 1
    fi
    # merge-base, not `git branch --merged`: a branch checked out in another
    # worktree is listed as "+ <name>", so an exact-match on the "  " prefix
    # would report an already-merged branch as unmerged.
    merged="no"
    git -C "$ROOT" merge-base --is-ancestor "$branch" HEAD 2>/dev/null && merged="yes"
    [ "$force" = "--force" ] || [ "$merged" = "yes" ] || {
      echo "REFUSED: branch ${branch} is not merged into HEAD. Integrate it first, or re-run with --force." >&2
      exit 1; }
    git -C "$ROOT" worktree remove ${force:+--force} "$path"
    echo "REMOVED=${path} (branch ${branch} kept — delete manually if no longer needed)"
    ;;

  *)
    sed -n '2,20p' "$0"
    exit 1
    ;;
esac
