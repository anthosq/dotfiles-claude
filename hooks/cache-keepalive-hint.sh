#!/usr/bin/bash
# PostToolUse hook: prompt cache keep-alive hint on every background launch.
# Bash → use Monitor (~270s timeout); Agent → load /cache-hygiene.
# Fires on official Anthropic background tasks (explicit run_in_background or
# auto-backgrounded). Third-party providers may not share Anthropic prompt-cache
# economics, so stay silent there.
set -euo pipefail

input=$(cat)

# Detect background: explicit flag or auto-backgrounded via timeout
run_in_bg=$(echo "$input" | jq -r '.tool_input.run_in_background // false')
bg_id=$(echo "$input" | jq -r 'if (.tool_response | type) == "object" then .tool_response.backgroundTaskId // empty else empty end')

if [ "$run_in_bg" != "true" ] && [ -z "$bg_id" ]; then
    exit 0
fi

# Skip subagents — their session_id is prefixed `agent-`. Cache hygiene is a
# long-session concern; subagents are short-lived and the fork-boilerplate
# directs them to execute their directive without loading skills mid-task.
SID=$(jq -r '.session_id // empty' <<< "$input")
case "$SID" in agent-*) exit 0 ;; esac

source "$(dirname "$0")/lib/provider.sh"
if ! is_official_anthropic_runtime; then
    exit 0
fi

tool_name=$(echo "$input" | jq -r '.tool_name // ""')

if [ "$tool_name" = "Bash" ]; then
    msg='Background Bash task launched. Load /cache-hygiene now and follow its keep-alive protocol. This keeps prompt cache (5-minute TTL) warm.'
else
    msg='Background agent launched. Load /cache-hygiene now and follow its keep-alive protocol. This keeps prompt cache (5-minute TTL) warm.'
fi

source "$(dirname "$0")/lib/emit.sh"
emit_post_tool_context "$msg"
