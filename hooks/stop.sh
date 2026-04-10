#!/bin/bash
# stop.sh - Notify when Claude Code completes a response
# Sends a brief update (not full summary - that's session-end)

set -e
source "$(dirname "$0")/hook-utils.sh"

# Read input from stdin
INPUT=$(cat)

# Check for recursive call
STOP_HOOK_ACTIVE=$(echo "$INPUT" | jq -r '.stop_hook_active // false')
if [ "$STOP_HOOK_ACTIVE" = "true" ]; then
    exit 0
fi

# Extract info
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')

# Find task
TASK_FILE=$(find_task_by_session "$SESSION_ID")
[ -z "$TASK_FILE" ] && exit 0

TASK_ID=$(get_task_id "$TASK_FILE")

# Debounce (prevent duplicate notifications within 30s)
LOCK_FILE="$BRIDGE_DIR/.stop-lock-$SESSION_ID"
if [ -f "$LOCK_FILE" ]; then
    # macOS uses -f%m, Linux uses -c%Y
    LOCK_AGE=$(($(date +%s) - $(stat -f%m "$LOCK_FILE" 2>/dev/null || stat -c%Y "$LOCK_FILE" 2>/dev/null || echo 0)))
    if [ "$LOCK_AGE" -lt 30 ]; then
        exit 0
    fi
fi
touch "$LOCK_FILE"

# Get last activity from tracking
TRACKING=$(get_tracking_summary "$TASK_ID")
LAST_ACTIVITY=$(echo "$TRACKING" | jq -r '.last_activity // "Working..."')
TOOL_CALLS=$(echo "$TRACKING" | jq -r '.tool_calls // 0')

# Update task
jq '.last_stop_at = now' "$TASK_FILE" > "${TASK_FILE}.tmp" \
    && mv "${TASK_FILE}.tmp" "$TASK_FILE"

# Get milestone interval from config
MILESTONE_INTERVAL=$(get_config "progress_filter.milestone_interval" "5")

# Brief notification (not flooding - just key milestones)
# Only notify every N tool calls (configurable)
if is_enabled "progress" && [ "$((TOOL_CALLS % MILESTONE_INTERVAL))" -eq 0 ] && [ "$TOOL_CALLS" -gt 0 ]; then
    send_wake "[CC-PROGRESS] [$TASK_ID] ✓ $LAST_ACTIVITY ($TOOL_CALLS steps)" "now" "$TASK_ID"
fi

log_hook "Stop: task=$TASK_ID tool_calls=$TOOL_CALLS"
exit 0
