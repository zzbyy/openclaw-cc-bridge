#!/bin/bash
# post-tool-use-failure.sh - Track tool failures and errors
# Sends immediate notification for significant errors

set -e
source "$(dirname "$0")/hook-utils.sh"

# Read input from stdin
INPUT=$(cat)

# Extract info
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
ERROR=$(echo "$INPUT" | jq -r '.error // ""' | head -c 300)

# Find task
TASK_FILE=$(find_task_by_session "$SESSION_ID")
[ -z "$TASK_FILE" ] && exit 0

TASK_ID=$(get_task_id "$TASK_FILE")

# Track the error
track_error "$TASK_ID" "$TOOL_NAME failed: $ERROR"
update_activity "$TASK_ID" "Error in $TOOL_NAME"

# Format error for notification
SHORT_ERROR=$(echo "$ERROR" | head -c 150 | tr '\n' ' ')

# Send error notification (if enabled)
if is_enabled "error"; then
    send_wake "[CC-ERROR] [$TASK_ID] ⚠️ $TOOL_NAME failed: $SHORT_ERROR" "now" "$TASK_ID"
fi

# Write event
EVENT_FILE="$BRIDGE_DIR/events/$(portable_timestamp)-error.json"
cat > "$EVENT_FILE" << EOF
{
    "event": "error",
    "event_type": "error",
    "task_id": "$TASK_ID",
    "session_id": "$SESSION_ID",
    "tool_name": "$TOOL_NAME",
    "error": $(echo "$ERROR" | jq -Rs .),
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

log_hook "PostToolUseFailure: task=$TASK_ID tool=$TOOL_NAME error=$SHORT_ERROR"
exit 0
