#!/bin/bash
# notification.sh - Forward Claude Code notifications
# Handles idle prompts and permission requests

set -e
source "$(dirname "$0")/hook-utils.sh"

# Read input from stdin
INPUT=$(cat)

# Extract info
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
MESSAGE=$(echo "$INPUT" | jq -r '.message // ""')
NOTIFICATION_TYPE=$(echo "$INPUT" | jq -r '.notification_type // "unknown"')

# Find task
TASK_FILE=$(find_task_by_session "$SESSION_ID") || true
TASK_ID=""
[ -n "$TASK_FILE" ] && TASK_ID=$(get_task_id "$TASK_FILE")

TASK_LABEL=""
[ -n "$TASK_ID" ] && TASK_LABEL="[$TASK_ID] "

# Handle based on type
case "$NOTIFICATION_TYPE" in
    idle_prompt)
        # Claude is waiting for something
        send_wake "[CC-IDLE] ${TASK_LABEL}⏸️ Waiting for input" "now" "$TASK_ID"
        ;;
    permission_prompt)
        # Claude needs permission (shouldn't happen with --dangerously-skip-permissions)
        SHORT_MSG=$(echo "$MESSAGE" | head -c 100)
        send_wake "[CC-PERMISSION] ${TASK_LABEL}🔐 Permission needed: $SHORT_MSG" "now" "$TASK_ID"
        ;;
esac

# Write event
EVENT_FILE="$BRIDGE_DIR/events/$(portable_timestamp)-notification.json"
cat > "$EVENT_FILE" << EOF
{
    "event": "notification",
    "event_type": "notification",
    "task_id": "$TASK_ID",
    "session_id": "$SESSION_ID",
    "notification_type": "$NOTIFICATION_TYPE",
    "message": $(echo "$MESSAGE" | jq -Rs .),
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

log_hook "Notification: type=$NOTIFICATION_TYPE task=$TASK_ID"
exit 0
