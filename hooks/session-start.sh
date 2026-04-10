#!/bin/bash
# session-start.sh - Notify OpenClaw when Claude Code session starts
# Sends a rich "task started" message

set -e
source "$(dirname "$0")/hook-utils.sh"

# Ensure config exists
init_config

# Read input from stdin
INPUT=$(cat)

# Extract session info
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // "unknown"')
TRIGGER=$(echo "$INPUT" | jq -r '.trigger // "startup"')

# Find task file by CWD
TASK_FILE=$(find_task_by_cwd "$CWD")
TASK_ID=""

if [ -n "$TASK_FILE" ] && [ -f "$TASK_FILE" ]; then
    TASK_ID=$(get_task_id "$TASK_FILE")
    PROMPT=$(jq -r '.prompt // ""' "$TASK_FILE" | head -c 100)
    
    # Update task with session ID
    jq --arg sid "$SESSION_ID" --arg status "running" \
       '.session_id = $sid | .status = $status | .started_at = now' \
       "$TASK_FILE" > "${TASK_FILE}.tmp" && mv "${TASK_FILE}.tmp" "$TASK_FILE"
    
    # Initialize tracking
    init_tracking "$TASK_ID"
    
    # Shorten CWD for display (replace home with ~)
    DISPLAY_CWD=$(echo "$CWD" | sed "s|^$HOME|~|")
    
    # Build rich message
    MESSAGE="🚀 Task started [$TASK_ID]
━━━━━━━━━━━━━━━━━━━━━
📁 $DISPLAY_CWD
📝 \"$PROMPT\"
━━━━━━━━━━━━━━━━━━━━━"

    # Write event for OpenClaw
    EVENT_FILE="$BRIDGE_DIR/events/$(date +%s%N)-session-start.json"
    cat > "$EVENT_FILE" << EOF
{
    "event": "session_start",
    "event_type": "start",
    "task_id": "$TASK_ID",
    "session_id": "$SESSION_ID",
    "cwd": "$CWD",
    "display_cwd": "$DISPLAY_CWD",
    "prompt": $(echo "$PROMPT" | jq -Rs .),
    "trigger": "$TRIGGER",
    "message": $(echo "$MESSAGE" | jq -Rs .),
    "target_channel": "$TELEGRAM_GROUP",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

    # Send notification if enabled
    if is_enabled "start"; then
        send_wake "[CC-START] $TASK_ID" "now" "$TASK_ID"
    fi
fi

log_hook "SessionStart: session=$SESSION_ID task=$TASK_ID cwd=$CWD"
exit 0
