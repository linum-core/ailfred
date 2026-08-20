#!/usr/bin/env bash
# Compressed memory context for the host — NOT a vault dump.
#
# Usage:
#   bash "$CLAUDE_PLUGIN_ROOT/scripts/ailfred-memory-read.sh" \
#        [--tags a,b] [--type architecture|decision|goal|surface|pitfall] [--max-notes N]
#
#   stdout: compact YAML — front-matter fields + the first body line of each note.
#           Default --max-notes 12, ordered by `updated` desc, then by type weight.
#
# Budget: ~1.5k tokens. A bigger vault is cut, never dumped: tag matches first,
# then most recently updated. Whoever needs a whole note opens its `path`.
#
# Also reports `architecture_fresh_days`, used to decide whether
# `ailfred-capability-scan.sh` needs to run at all.
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
usage() { sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; }

tags=""; want_type=""; max_notes=12
while [ $# -gt 0 ]; do
  case "$1" in
    --tags)      tags="${2:-}"; shift 2 ;;
    --type)      want_type="${2:-}"; shift 2 ;;
    --max-notes) max_notes="${2:-12}"; shift 2 ;;
    -h|--help)   usage; exit 0 ;;
    *) echo "ERROR: unknown argument '$1'" >&2; usage >&2; exit 1 ;;
  esac
done
case "$max_notes" in ''|*[!0-9]*) echo "ERROR: --max-notes must be an integer" >&2; exit 1 ;; esac

project_slug="$(bash "${PLUGIN_ROOT}/scripts/ailfred-project-slug.sh")"
vault="$(bash "${PLUGIN_ROOT}/scripts/ailfred-project-slug.sh" --path)/memory"

if [ ! -f "${vault}/MOC.md" ]; then
  printf 'project: %s\nvault: %s\nstatus: empty\nnotes_total: 0\narchitecture_fresh_days: null\nnotes: []\n' \
    "$project_slug" "$vault"
  exit 0
fi

today_epoch="$(date -u +%s)"

# One TSV line per note: updated \t type \t tagscore \t title \t tags \t confidence \t path \t hook
scan() {
  local f
  for f in "$vault"/*/*.md; do
    [ -f "$f" ] || continue
    awk -v path="$f" -v want_tags="$tags" -v q="'" '
      function trim(s){ gsub(/^[[:space:]]+|[[:space:]]+$/,"",s); return s }
      NR==1 && $0=="---" { fm=1; next }
      fm && $0=="---"    { fm=0; next }
      fm && /^type:/        { v=$0; sub(/^type:[[:space:]]*/,"",v);        type=trim(v); next }
      fm && /^title:/       { v=$0; sub(/^title:[[:space:]]*/,"",v);       gsub(/^"|"$/,"",v); title=trim(v); next }
      fm && /^updated:/     { v=$0; sub(/^updated:[[:space:]]*/,"",v);     upd=trim(v); next }
      fm && /^confidence:/  { v=$0; sub(/^confidence:[[:space:]]*/,"",v);  sub(/#.*$/,"",v); conf=trim(v); next }
      fm && /^tags:/        { v=$0; sub(/^tags:[[:space:]]*/,"",v); gsub(/[\[\]]/,"",v); ntags=trim(v); next }
      !fm && NF && hook=="" { hook=trim($0); next }
      END {
        if (title=="") exit 0
        score=0
        if (want_tags != "") {
          n=split(want_tags, w, ",")
          m=split(ntags, g, ",")
          for (i=1;i<=n;i++) for (j=1;j<=m;j++)
            if (trim(w[i]) != "" && trim(w[i]) == trim(g[j])) score++
        }
        if (length(hook) > 120) hook = substr(hook,1,117) "..."
        gsub(/\t/," ",title); gsub(/\t/," ",hook)
        gsub(/"/,q,title); gsub(/"/,q,hook)
        printf "%s\t%s\t%d\t%s\t%s\t%s\t%s\t%s\n", upd, type, score, title, ntags, conf, path, hook
      }
    ' "$f"
  done
}

rows="$(scan || true)"
[ -n "${want_type}" ] && rows="$(printf '%s\n' "$rows" | awk -F'\t' -v t="$want_type" '$2==t')"
rows="$(printf '%s' "$rows" | grep -v '^$' || true)"

total=0
[ -n "$rows" ] && total="$(printf '%s\n' "$rows" | wc -l | tr -d ' ')"

# Freshness of the newest `architecture` note, in days (null when there is none).
arch_days="null"
if [ -n "$rows" ]; then
  newest_arch="$(printf '%s\n' "$rows" | awk -F'\t' '$2=="architecture"{print $1}' | LC_ALL=C sort -r | head -1)"
  if [ -n "$newest_arch" ]; then
    arch_epoch="$(date -j -f %Y-%m-%d "$newest_arch" +%s 2>/dev/null || date -d "$newest_arch" +%s 2>/dev/null || echo "")"
    if [ -n "$arch_epoch" ]; then
      arch_days=$(( (today_epoch - arch_epoch) / 86400 ))
      [ "$arch_days" -lt 0 ] && arch_days=0   # timezone skew, never negative
    fi
  fi
fi

# Ranking: tag matches first, then most recently updated.
selected="$(printf '%s\n' "$rows" | LC_ALL=C sort -t"$(printf '\t')" -k3,3nr -k1,1r | head -n "$max_notes")"

printf 'project: %s\n' "$project_slug"
printf 'vault: %s\n' "$vault"
printf 'status: ok\n'
printf 'notes_total: %s\n' "$total"
printf 'notes_returned: %s\n' "$( [ -n "$selected" ] && printf '%s\n' "$selected" | wc -l | tr -d ' ' || echo 0 )"
printf 'architecture_fresh_days: %s\n' "$arch_days"
printf 'notes:\n'
if [ -z "$selected" ]; then
  printf '  []\n'
else
  printf '%s\n' "$selected" | awk -F'\t' '{
    printf "  - type: %s\n", $2
    printf "    title: \"%s\"\n", $4
    printf "    updated: %s\n", $1
    printf "    confidence: %s\n", $6
    printf "    tags: [%s]\n", $5
    printf "    path: %s\n", $7
    printf "    hook: \"%s\"\n", $8
  }'
fi
