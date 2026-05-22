#!/usr/bin/bash
# Reset the recall-reminder counter when the agent demonstrably touched
# the memory pages or pitfalls projection — mirrors how Claude Code's
# built-in TodoWrite reminder resets on a TodoWrite tool call.
#
# Triggers reset on:
#   - Read of any file under memory/pages/*.md or memory/pitfalls.md
#   - Skill invocation of memory-add
#
# Silent: no stdout, no permissionDecision, just touches the state file.
set -euo pipefail

STATE_DIR="/tmp/claude-${UID}-state/recall-reminder"

PAYLOAD=""
if ! [ -t 0 ]; then
  PAYLOAD=$(cat || true)
fi
SID=$(printf '%s' "$PAYLOAD" | jq -r '.session_id // "unknown"' 2>/dev/null) || SID="unknown"
[ -z "$SID" ] && SID="unknown"

TOOL=$(printf '%s' "$PAYLOAD" | jq -r '.tool_name // ""' 2>/dev/null) || TOOL=""

RESET=0
case "$TOOL" in
  Read)
    FP=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.file_path // ""' 2>/dev/null) || FP=""
    case "$FP" in
      */memory/pages/*.md|*/memory/pitfalls.md) RESET=1 ;;
    esac
    ;;
  Skill)
    SK=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.skill // ""' 2>/dev/null) || SK=""
    case "$SK" in
      memory-add) RESET=1 ;;
    esac
    ;;
esac

if [ "$RESET" = "1" ]; then
  mkdir -p "$STATE_DIR"
  chmod 700 "$STATE_DIR" 2>/dev/null || true
  echo 0 > "$STATE_DIR/$SID"
fi
