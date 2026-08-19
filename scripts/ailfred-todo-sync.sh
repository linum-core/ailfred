#!/usr/bin/env bash
# Write completion back into the source checklist: flip one line's [ ] <-> [x].
#
# Usage:
#   bash "$CLAUDE_PLUGIN_ROOT/scripts/ailfred-todo-sync.sh" <file> --line N --expect "<substring>" \
#        (--check | --uncheck) [--dry-run]
#
# Why line + expect (and not a text search): the developer keeps editing the file while
# the goal runs. The line number locates the item; the expected substring proves it is
# still the SAME item. If the two disagree the script refuses (exit 3) instead of
# marking the wrong line — the caller must re-parse with ailfred-todo-parse.sh.
#
# Exit codes: 0 changed or already in the target state | 1 usage/precondition | 3 drift
#
# Guarantees: only that single line changes; the rest of the file is byte-for-byte
# identical (including a missing trailing newline); idempotent; --dry-run prints the
# before/after line and writes nothing.
set -euo pipefail

FILE=""; LINE=""; EXPECT=""; ACTION=""; DRY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --line)    LINE="${2:-}"; shift 2 ;;
    --expect)  EXPECT="${2:-}"; shift 2 ;;
    --check)   ACTION="check"; shift ;;
    --uncheck) ACTION="uncheck"; shift ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,18p' "$0"; exit 0 ;;
    *)         FILE="$1"; shift ;;
  esac
done

[ -n "$FILE" ] && [ -f "$FILE" ] || { echo "ERROR: existing file required" >&2; exit 1; }
case "$LINE" in ''|*[^0-9]*) echo "ERROR: --line N required" >&2; exit 1 ;; esac
[ -n "$ACTION" ] || { echo "ERROR: --check or --uncheck required" >&2; exit 1; }
[ -n "$EXPECT" ] || { echo "ERROR: --expect \"<substring>\" required (drift guard)" >&2; exit 1; }

current="$(awk -v n="$LINE" 'NR==n{print; exit}' "$FILE")"
[ -n "$current" ] || { echo "ERROR: line $LINE is empty or out of range in $FILE" >&2; exit 1; }

# Must still be a checklist item…
case "$current" in
  *"- ["*|*"* ["*|*"+ ["*) ;;
  *) echo "DRIFT: line $LINE is not a checklist item any more" >&2
     echo "  actual: $current" >&2
     exit 3 ;;
esac
# …and still the same item.
case "$current" in
  *"$EXPECT"*) ;;
  *) echo "DRIFT: line $LINE no longer contains the expected text" >&2
     echo "  expected substring: $EXPECT" >&2
     echo "  actual line:        $current" >&2
     echo "  fix: re-run ailfred-todo-parse.sh and use the new line number" >&2
     exit 3 ;;
esac

if [ "$ACTION" = "check" ]; then
  case "$current" in *"[x]"*|*"[X]"*) echo "ALREADY checked: $current"; exit 0 ;; esac
  new="$(printf '%s' "$current" | sed 's/\[ \]/[x]/')"
else
  case "$current" in *"[ ]"*) echo "ALREADY unchecked: $current"; exit 0 ;; esac
  new="$(printf '%s' "$current" | sed 's/\[[xX]\]/[ ]/')"
fi

echo "line $LINE"
echo "  antes:  $current"
echo "  depois: $new"
[ "$DRY" -eq 1 ] && { echo "DRY-RUN: nada escrito"; exit 0; }

# Preserve a missing final newline: awk would otherwise add one.
had_final_newline=1
[ -n "$(tail -c1 "$FILE")" ] && had_final_newline=0

tmp="$(mktemp)"
awk -v n="$LINE" -v repl="$new" 'NR==n{print repl; next} {print}' "$FILE" > "$tmp"
if [ "$had_final_newline" -eq 0 ]; then
  printf '%s' "$(cat "$tmp")" > "${tmp}.2" && mv "${tmp}.2" "$tmp"
fi
cat "$tmp" > "$FILE"   # cat, not mv: keeps the original inode, mode and any symlink
rm -f "$tmp"
echo "OK: $FILE atualizado"
