#!/bin/bash
# elicitation.sh - Handle Claude Code questions via OpenClaw/Telegram
# BLOCKING: waits for user answer or timeout

set -e
source "$(dirname "$0")/hook-utils.sh"

# Configuration — internal timeout must be shorter than hook timeout (300s) for clean handling
MAX_WAIT_SECONDS=${CC_ELICITATION_TIMEOUT:-270}  # 4.5 minutes default (hook timeout is 300s)
POLL_INTERVAL=2

# Read input from stdin
INPUT=$(cat)

# Extract info
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
MCP_SERVER=$(echo "$INPUT" | jq -r '.mcp_server_name // ""')
MESSAGE=$(echo "$INPUT" | jq -r '.message // ""')
ELICITATION_ID=$(echo "$INPUT" | jq -r '.elicitation_id // ""')

# Find task
TASK_FILE=$(find_task_by_session "$SESSION_ID") || true
TASK_ID=""
[ -n "$TASK_FILE" ] && TASK_ID=$(get_task_id "$TASK_FILE")

# Generate question ID if not provided
if [ -z "$ELICITATION_ID" ] || [ "$ELICITATION_ID" = "null" ]; then
    ELICITATION_ID="q-$(date +%s)-$$"
fi

# Track that we're waiting for input
[ -n "$TASK_ID" ] && update_activity "$TASK_ID" "Waiting for user input"

# Create question file
QUESTION_FILE="$BRIDGE_DIR/questions/${ELICITATION_ID}.json"
ANSWER_FILE="$BRIDGE_DIR/answers/${ELICITATION_ID}.json"

cat > "$QUESTION_FILE" << EOF
{
    "question_id": "$ELICITATION_ID",
    "task_id": "$TASK_ID",
    "session_id": "$SESSION_ID",
    "mcp_server": "$MCP_SERVER",
    "message": $(echo "$MESSAGE" | jq -Rs .),
    "status": "pending",
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Build rich question message
TASK_LABEL=""
[ -n "$TASK_ID" ] && TASK_LABEL="Task: $TASK_ID"

RICH_MESSAGE="🤔 Claude Code Question
━━━━━━━━━━━━━━━━━━━━━
$TASK_LABEL
━━━━━━━━━━━━━━━━━━━━━

$MESSAGE

━━━━━━━━━━━━━━━━━━━━━
Reply: /answer $ELICITATION_ID <your answer>
Or reply directly to this message"

# Write event for OpenClaw
EVENT_FILE="$BRIDGE_DIR/events/$(portable_timestamp)-question.json"
cat > "$EVENT_FILE" << EOF
{
    "event": "question",
    "event_type": "question",
    "question_id": "$ELICITATION_ID",
    "task_id": "$TASK_ID",
    "session_id": "$SESSION_ID",
    "message": $(echo "$MESSAGE" | jq -Rs .),
    "rich_message": $(echo "$RICH_MESSAGE" | jq -Rs .),
    "target_channel": "$TELEGRAM_GROUP",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Wake OpenClaw (questions are always sent - disabling would break interaction)
# Config check is still here in case user wants to suppress the notification
# but the hook still waits for the answer
if is_enabled "question"; then
    send_wake "[CC-QUESTION] $ELICITATION_ID task:$TASK_ID" "now" "$TASK_ID"
else
    # Even if notification is disabled, still write event so OpenClaw can process
    log_hook "Elicitation: question notification disabled, but still waiting for answer"
fi

log_hook "Elicitation: id=$ELICITATION_ID task=$TASK_ID"

# Poll for answer
WAITED=0
while [ $WAITED -lt $MAX_WAIT_SECONDS ]; do
    if [ -f "$ANSWER_FILE" ]; then
        ANSWER_STATUS=$(jq -r '.status // "pending"' "$ANSWER_FILE" 2>/dev/null)
        
        if [ "$ANSWER_STATUS" = "answered" ]; then
            ANSWER_TEXT=$(jq -r '.answer // ""' "$ANSWER_FILE")
            
            log_hook "Elicitation answered: id=$ELICITATION_ID"
            [ -n "$TASK_ID" ] && update_activity "$TASK_ID" "Received user answer"
            
            # Clean up
            rm -f "$QUESTION_FILE" "$ANSWER_FILE"
            
            # Return answer to Claude Code (hookSpecificOutput envelope)
            echo "{\"hookSpecificOutput\": {\"hookEventName\": \"Elicitation\", \"action\": \"accept\", \"content\": {\"answer\": $(echo "$ANSWER_TEXT" | jq -Rs .)}}}"
            exit 0

        elif [ "$ANSWER_STATUS" = "skipped" ] || [ "$ANSWER_STATUS" = "cancelled" ]; then
            log_hook "Elicitation skipped: id=$ELICITATION_ID"
            rm -f "$QUESTION_FILE" "$ANSWER_FILE"
            echo '{"hookSpecificOutput": {"hookEventName": "Elicitation", "action": "decline"}}'
            exit 0
        fi
    fi
    
    sleep $POLL_INTERVAL
    WAITED=$((WAITED + POLL_INTERVAL))
done

# Timeout
log_hook "Elicitation timeout: id=$ELICITATION_ID"

jq '.status = "timeout"' "$QUESTION_FILE" > "${QUESTION_FILE}.tmp" \
    && mv "${QUESTION_FILE}.tmp" "$QUESTION_FILE"

# Track timeout
[ -n "$TASK_ID" ] && track_error "$TASK_ID" "Question timed out after ${MAX_WAIT_SECONDS}s"

send_wake "[CC-TIMEOUT] [$TASK_ID] ⏰ Question timed out" "now" "$TASK_ID"

echo '{"hookSpecificOutput": {"hookEventName": "Elicitation", "action": "decline"}}'
exit 0
