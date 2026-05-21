#!/usr/bin/bash
# PreToolUse hook: when Claude is about to call WebSearch, nudge it to load
# the `jina-ai` skill instead — `jina search` is strictly more capable
# (site:, time-window, region/language filters, arXiv / SSRN, BibTeX, Unix
# pipes). Fires at most once per session_id to avoid re-prompting on
# iterative searches.
#
# Non-blocking by design: the built-in WebSearch still works for one-shot
# lookups or when the jina API key is unavailable.
#
# Sibling hook `hint-skill-read-url.sh` covers WebFetch → /read-url.
set -euo pipefail

source "$(dirname "$0")/lib/emit.sh"
source "$(dirname "$0")/lib/session_lock.sh"

input=$(cat)

SID=$(jq -r '.session_id // "unknown"' <<< "$input")

# Skip subagents — agent-* prefix on session_id. Main agent benefits from
# being nudged toward the skill; short-lived subagents typically just use
# WebSearch directly and don't have budget for loading a skill.
case "$SID" in agent-*) exit 0 ;; esac

CACHE_DIR=/tmp/claude-${UID}-state/skill-hint-jina-ai
CACHE="$CACHE_DIR/$SID"
mkdir -p "$CACHE_DIR"
reset_on_compact "$SID" "$CACHE_DIR" "$CACHE"
[ -f "$CACHE" ] && exit 0
touch "$CACHE"

emit_pre_tool_warn 'About to call WebSearch. Consider the /jina-ai skill — `jina search` adds site:/time/region filters, arXiv & SSRN search, and Unix-pipe composition. Built-in WebSearch is fine for one-shot low-stakes lookups or when the jina API key is unavailable.'
