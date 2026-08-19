#!/usr/bin/env bash
# Capability scan for the internal /ailfred command.
#
# Lists the skills, agents and commands that actually exist on THIS machine so
# the planner reuses them instead of improvising a method from scratch.
#
# Usage: bash "$CLAUDE_PLUGIN_ROOT/scripts/ailfred-capability-scan.sh" [--section skills|agents|commands|all]
#
# Scopes reported:
#   project   .claude/{skills,agents,commands} of this repository
#   user      ${CLAUDE_CONFIG_DIR}/... and ~/.claude/... (both, deduped)
#   plugin    skills shipped by installed plugin marketplaces
#   ref       loose *.md under a skills/ dir — readable reference material,
#             NOT auto-loaded by the agent (no SKILL.md = no automatic load)
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
SECTION="all"
[ "${1:-}" = "--section" ] && SECTION="${2:-all}"

# ---------- helpers ----------

# Value of a frontmatter field, truncated to one line.
# Handles both `description: text` and YAML block scalars (`description: >-`),
# where the real text lives on the following indented lines.
fm_field() {
  awk -v key="$2" '
    $0 ~ "^"key":" && !seen {
      seen=1
      sub("^"key":[[:space:]]*","")
      if ($0 ~ /^[>|][-+]?[[:space:]]*$/) { block=1; next }
      print substr($0,1,120); exit
    }
    block {
      if ($0 ~ /^[[:space:]]+[^[:space:]]/) { sub(/^[[:space:]]+/,""); buf=buf" "$0 }
      else { exit }
      if (length(buf) > 120) exit
    }
    END { if (block) { sub(/^ /,"",buf); print substr(buf,1,120) } }
  ' "$1"
}

row() { printf '  %-9s %-34s %s\n' "$1" "$2" "$3"; }

skill_dirs() { # scope base
  [ -d "$2" ] || return 0
  local f
  for f in "$2"/*/SKILL.md; do
    [ -e "$f" ] || continue
    row "$1" "$(basename "$(dirname "$f")")" "$(fm_field "$f" description)"
  done
}

skill_refs() { # scope base — loose .md files (reference only)
  [ -d "$2" ] || return 0
  local f d
  for f in "$2"/*.md; do
    [ -e "$f" ] || continue
    d="$(fm_field "$f" description)"
    [ -n "$d" ] || d="$(head -3 "$f" | tr '\n' ' ' | cut -c1-110)"
    row "$1" "$(basename "$f" .md)" "$d"
  done
}

md_dir() { # scope base — agents/commands (flat .md, frontmatter optional)
  [ -d "$2" ] || return 0
  local f d
  for f in "$2"/*.md; do
    [ -e "$f" ] || continue
    d="$(fm_field "$f" description)"
    [ -n "$d" ] || d="$(grep -m1 '^# ' "$f" 2>/dev/null | sed 's/^# //' | cut -c1-100)"
    row "$1" "$(basename "$f" .md)" "$d"
  done
}

# Config dirs: honour CLAUDE_CONFIG_DIR, but always also look at ~/.claude.
CFG_DIRS=()
for d in "${CLAUDE_CONFIG_DIR:-}" "$HOME/.claude"; do
  [ -n "$d" ] && [ -d "$d" ] || continue
  case " ${CFG_DIRS[*]-} " in *" $d "*) continue ;; esac
  CFG_DIRS+=("$d")
done

# ---------- report ----------

echo "CAPABILITY SCAN — $(date +%F)  root=${ROOT}"
echo "config dirs: ${CFG_DIRS[*]-none}"

if [ "$SECTION" = "all" ] || [ "$SECTION" = "skills" ]; then
  echo
  echo "SKILLS (loaded — invocable by name)"
  skill_dirs project "${ROOT}/.claude/skills"
  skill_dirs ailfred "${PLUGIN_ROOT}/skills"
  for d in "${CFG_DIRS[@]-}"; do skill_dirs user "${d}/skills"; done
  for m in "${CFG_DIRS[@]-}"; do
    [ -d "${m}/plugins/marketplaces" ] || continue
    for p in "${m}"/plugins/marketplaces/*; do
      [ -d "$p" ] || continue
      skill_dirs "plugin" "${p}/skills"
      skill_dirs "plugin" "$p"
    done
  done

  echo
  echo "SKILLS (reference-only files — read on demand, never auto-loaded)"
  for d in "${CFG_DIRS[@]-}"; do skill_refs ref "${d}/skills"; done
fi

if [ "$SECTION" = "all" ] || [ "$SECTION" = "agents" ]; then
  echo
  echo "AGENTS (subagent_type available to spawn)"
  md_dir project "${ROOT}/.claude/agents"
  md_dir ailfred "${PLUGIN_ROOT}/agents"
  for d in "${CFG_DIRS[@]-}"; do md_dir user "${d}/agents"; done
fi

if [ "$SECTION" = "all" ] || [ "$SECTION" = "commands" ]; then
  echo
  echo "COMMANDS (slash commands)"
  md_dir project "${ROOT}/.claude/commands"
  md_dir ailfred "${PLUGIN_ROOT}/commands"
  for d in "${CFG_DIRS[@]-}"; do md_dir user "${d}/commands"; done
fi

echo
echo "END SCAN — pick only what the goal actually needs; record the choice in PRD.md section 9."
