#!/usr/bin/env bash
# Write (or update) one memory note and refresh the MOC index.
#
# Usage:
#   bash "$CLAUDE_PLUGIN_ROOT/scripts/ailfred-memory-write.sh" \
#        --type architecture|decision|goal|surface|pitfall \
#        --title "frase curta e específica" \
#        --body-file <path> \
#        [--tags a,b] [--goal-slug S] [--supersedes "titulo"] [--confidence high|medium|low]
#
#   stdout: WROTE <path> | UPDATED <path>
#
# Dedup: same type + same title -> the existing file is rewritten and `updated`
# bumped (`created` preserved). One fact, one file, forever.
#
# The MOC section of the type is regenerated from disk on every write, so it can
# never hold an orphan or a duplicate.
set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
usage() { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; }

type=""; title=""; body_file=""; tags=""; goal_slug="null"; supersedes="null"; confidence="medium"
while [ $# -gt 0 ]; do
  case "$1" in
    --type)       type="${2:-}"; shift 2 ;;
    --title)      title="${2:-}"; shift 2 ;;
    --body-file)  body_file="${2:-}"; shift 2 ;;
    --tags)       tags="${2:-}"; shift 2 ;;
    --goal-slug)  goal_slug="${2:-}"; shift 2 ;;
    --supersedes) supersedes="${2:-}"; shift 2 ;;
    --confidence) confidence="${2:-}"; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "ERROR: unknown argument '$1'" >&2; usage >&2; exit 1 ;;
  esac
done

case "$type" in
  architecture) dir="architecture" ;;
  decision)     dir="decisions" ;;
  goal)         dir="goals" ;;
  surface)      dir="surfaces" ;;
  pitfall)      dir="pitfalls" ;;
  "") echo "ERROR: --type required" >&2; usage >&2; exit 1 ;;
  *)  echo "ERROR: invalid --type '$type'" >&2; exit 1 ;;
esac
[ -n "$title" ] || { echo "ERROR: --title required" >&2; exit 1; }
[ -n "$body_file" ] && [ -f "$body_file" ] || { echo "ERROR: --body-file must point at an existing file" >&2; exit 1; }
case "$confidence" in high|medium|low) ;; *) echo "ERROR: --confidence must be high|medium|low" >&2; exit 1 ;; esac

vault="$(bash "${PLUGIN_ROOT}/scripts/ailfred-project-slug.sh" --path)/memory"
[ -f "${vault}/MOC.md" ] || bash "${PLUGIN_ROOT}/scripts/ailfred-memory-init.sh" >/dev/null

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr ' _.:/' '-' \
    | tr -cd 'a-z0-9-' | sed -e 's/--*/-/g' -e 's/^-//' -e 's/-$//'
}
fname="$(slugify "$title")"; [ -n "$fname" ] || fname="nota"
path="${vault}/${dir}/${fname}.md"
today="$(date -u +%Y-%m-%d)"

created="$today"; verb="WROTE"
if [ -f "$path" ]; then
  verb="UPDATED"
  existing_created="$(sed -n 's/^created:[[:space:]]*//p' "$path" | head -1)"
  [ -n "$existing_created" ] && created="$existing_created"
fi

# tags: "a,b" -> [a, b]
if [ -n "$tags" ]; then
  tags_yaml="[$(printf '%s' "$tags" | sed -e 's/[[:space:]]*,[[:space:]]*/, /g')]"
else
  tags_yaml="[]"
fi
quote_or_null() { case "$1" in ""|null) printf 'null' ;; *) printf '"%s"' "$1" ;; esac; }

mkdir -p "$(dirname "$path")"
tmp="${path}.tmp.$$"
{
  printf -- '---\n'
  printf 'type: %s\n' "$type"
  printf 'title: "%s"\n' "$title"
  printf 'created: %s\n' "$created"
  printf 'updated: %s\n' "$today"
  printf 'goal_slug: %s\n' "$(quote_or_null "$goal_slug")"
  printf 'confidence: %s\n' "$confidence"
  printf 'tags: %s\n' "$tags_yaml"
  printf 'supersedes: %s\n' "$(quote_or_null "$supersedes")"
  printf -- '---\n\n'
  cat "$body_file"
} > "$tmp"
mv "$tmp" "$path"

# --- MOC: regenerate the section of this type from what is on disk -------------
# One line per note: `- [[titulo]] — gancho`. The hook is the first non-empty body
# line, truncated. Pointers only: the MOC never carries content.
entries="$(
  for f in "${vault}/${dir}"/*.md; do
    [ -f "$f" ] || continue
    awk '
      NR==1 && $0=="---" { fm=1; next }
      fm && $0=="---"    { fm=0; next }
      fm && /^title:/    { t=$0; sub(/^title:[[:space:]]*/,"",t); gsub(/^"|"$/,"",t); next }
      !fm && NF && h=="" { h=$0; next }
      END {
        if (t=="") exit 0
        gsub(/^[[:space:]]+|[[:space:]]+$/,"",h)
        if (length(h) > 90) h = substr(h,1,87) "..."
        if (h=="") h = "(sem gancho)"
        printf "- [[%s]] — %s\n", t, h
      }
    ' "$f"
  done | LC_ALL=C sort
)"

moc="${vault}/MOC.md"
start="<!-- ailfred:${type}:start -->"
end="<!-- ailfred:${type}:end -->"
entfile="${moc}.entries.$$"
printf '%s\n' "$entries" | grep -v '^$' > "$entfile" || true
trap 'rm -f "$entfile"' EXIT

if grep -qF "$start" "$moc"; then
  # awk -v cannot carry a multi-line value on every awk; read the block from a file.
  awk -v start="$start" -v end="$end" -v entfile="$entfile" '
    $0 == start { print; while ((getline line < entfile) > 0) print line; close(entfile); skip=1; next }
    $0 == end   { skip=0 }
    !skip       { print }
  ' "$moc" > "${moc}.tmp.$$" && mv "${moc}.tmp.$$" "$moc"
else
  { printf '\n## %s\n\n%s\n' "$dir" "$start"; cat "$entfile"; printf '%s\n' "$end"; } >> "$moc"
fi
rm -f "$entfile"; trap - EXIT

printf '%s %s\n' "$verb" "$path"
