#!/bin/bash
# session-end.sh - Send comprehensive completion summary
# This is the main summary the user sees when a task finishes

set -e
source "$(dirname "$0")/hook-utils.sh"

# Read input from stdin
INPUT=$(cat)

# Extract info
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
CWD=$(echo "$INPUT" | jq -r '.cwd // "unknown"')
REASON=$(echo "$INPUT" | jq -r '.reason // "unknown"')
TRANSCRIPT_PATH=$(echo "$INPUT" | jq -r '.transcript_path // ""')

# Find task
TASK_FILE=$(find_task_by_session "$SESSION_ID")
if [ -z "$TASK_FILE" ]; then
    log_hook "SessionEnd: no task found for session=$SESSION_ID"
    exit 0
fi

TASK_ID=$(get_task_id "$TASK_FILE")

# Get task metadata
TASK_DATA=$(cat "$TASK_FILE")
STARTED_AT=$(echo "$TASK_DATA" | jq -r '.started_at // ""')
PROMPT=$(echo "$TASK_DATA" | jq -r '.prompt // ""' | head -c 60)

# Get tracking data
TRACKING=$(get_tracking_summary "$TASK_ID")
FILES_CREATED=$(echo "$TRACKING" | jq -r '.files_created // []')
FILES_MODIFIED=$(echo "$TRACKING" | jq -r '.files_modified // []')
ERRORS=$(echo "$TRACKING" | jq -r '.errors // []')
TOOL_CALLS=$(echo "$TRACKING" | jq -r '.tool_calls // 0')

# Calculate duration
DURATION_STR="unknown"
if [ -n "$STARTED_AT" ]; then
    START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${STARTED_AT%%.*}" +%s 2>/dev/null || \
                  date -d "${STARTED_AT}" +%s 2>/dev/null || echo "")
    if [ -n "$START_EPOCH" ]; then
        NOW_EPOCH=$(date +%s)
        DURATION=$((NOW_EPOCH - START_EPOCH))
        DURATION_STR=$(format_duration $DURATION)
    fi
fi

# Extract summary from transcript
TRANSCRIPT_SUMMARY=""
if [ -n "$TRANSCRIPT_PATH" ] && [ -f "$TRANSCRIPT_PATH" ]; then
    TRANSCRIPT_SUMMARY=$(extract_transcript_summary "$TRANSCRIPT_PATH" 400)
fi

# Display CWD
DISPLAY_CWD=$(echo "$CWD" | sed "s|^$HOME|~|")

# Build file changes section
FILE_CHANGES=""
CREATED_COUNT=$(echo "$FILES_CREATED" | jq 'length')
MODIFIED_COUNT=$(echo "$FILES_MODIFIED" | jq 'length')
TOTAL_FILES=$((CREATED_COUNT + MODIFIED_COUNT))

if [ "$TOTAL_FILES" -gt 0 ]; then
    FILE_CHANGES="📄 Files changed ($TOTAL_FILES):"
    
    # Show created files (max 5)
    if [ "$CREATED_COUNT" -gt 0 ]; then
        echo "$FILES_CREATED" | jq -r '.[:5][]' | while read f; do
            SHORT=$(basename "$f")
            FILE_CHANGES="$FILE_CHANGES
   + $SHORT (new)"
        done
        if [ "$CREATED_COUNT" -gt 5 ]; then
            FILE_CHANGES="$FILE_CHANGES
   + ...and $((CREATED_COUNT - 5)) more"
        fi
    fi
    
    # Show modified files (max 5)
    if [ "$MODIFIED_COUNT" -gt 0 ]; then
        echo "$FILES_MODIFIED" | jq -r '.[:5][]' | while read f; do
            SHORT=$(basename "$f")
            FILE_CHANGES="$FILE_CHANGES
   ~ $SHORT (modified)"
        done
        if [ "$MODIFIED_COUNT" -gt 5 ]; then
            FILE_CHANGES="$FILE_CHANGES
   ~ ...and $((MODIFIED_COUNT - 5)) more"
        fi
    fi
fi

# Build errors section
ERROR_SECTION=""
ERROR_COUNT=$(echo "$ERRORS" | jq 'length')
if [ "$ERROR_COUNT" -gt 0 ]; then
    if [ "$REASON" = "exit" ] || [ "$REASON" = "sigint" ]; then
        # Task completed despite errors
        ERROR_SECTION="
⚠️ $ERROR_COUNT error(s) during session (resolved):"
    else
        # Task failed
        ERROR_SECTION="
❌ Errors ($ERROR_COUNT):"
    fi
    
    echo "$ERRORS" | jq -r '.[0:3][] | "   - " + .message[:80]' | while read e; do
        ERROR_SECTION="$ERROR_SECTION
$e"
    done
    
    if [ "$ERROR_COUNT" -gt 3 ]; then
        ERROR_SECTION="$ERROR_SECTION
   ...and $((ERROR_COUNT - 3)) more"
    fi
fi

# Determine status emoji and label
STATUS_EMOJI="✅"
STATUS_LABEL="completed"
case "$REASON" in
    exit)
        STATUS_EMOJI="✅"
        STATUS_LABEL="completed"
        ;;
    sigint)
        STATUS_EMOJI="⏹️"
        STATUS_LABEL="stopped by user"
        ;;
    error)
        STATUS_EMOJI="❌"
        STATUS_LABEL="failed"
        ;;
    *)
        STATUS_EMOJI="⚠️"
        STATUS_LABEL="ended ($REASON)"
        ;;
esac

# Build the full message
MESSAGE="$STATUS_EMOJI Task $STATUS_LABEL [$TASK_ID]
━━━━━━━━━━━━━━━━━━━━━
📁 $DISPLAY_CWD
⏱️ $DURATION_STR"

# Add file changes if any
if [ -n "$FILE_CHANGES" ]; then
    # Build file list properly
    CREATED_LIST=""
    MODIFIED_LIST=""
    
    if [ "$CREATED_COUNT" -gt 0 ]; then
        CREATED_LIST=$(echo "$FILES_CREATED" | jq -r '.[:5][]' | while read f; do
            echo "   + $(basename "$f") (new)"
        done)
        if [ "$CREATED_COUNT" -gt 5 ]; then
            CREATED_LIST="$CREATED_LIST
   + ...and $((CREATED_COUNT - 5)) more"
        fi
    fi
    
    if [ "$MODIFIED_COUNT" -gt 0 ]; then
        MODIFIED_LIST=$(echo "$FILES_MODIFIED" | jq -r '.[:5][]' | while read f; do
            echo "   ~ $(basename "$f") (modified)"
        done)
        if [ "$MODIFIED_COUNT" -gt 5 ]; then
            MODIFIED_LIST="$MODIFIED_LIST
   ~ ...and $((MODIFIED_COUNT - 5)) more"
        fi
    fi
    
    MESSAGE="$MESSAGE

📄 Files changed ($TOTAL_FILES):
$CREATED_LIST$MODIFIED_LIST"
fi

# Add transcript summary
if [ -n "$TRANSCRIPT_SUMMARY" ]; then
    MESSAGE="$MESSAGE

📋 Summary:
$TRANSCRIPT_SUMMARY"
fi

# Add errors if any
if [ "$ERROR_COUNT" -gt 0 ]; then
    ERROR_LIST=$(echo "$ERRORS" | jq -r '.[0:3][] | "   - " + (.message[:80])')
    if [ "$REASON" = "exit" ] || [ "$REASON" = "sigint" ]; then
        MESSAGE="$MESSAGE

⚠️ $ERROR_COUNT error(s) during session (resolved):
$ERROR_LIST"
    else
        MESSAGE="$MESSAGE

❌ Errors ($ERROR_COUNT):
$ERROR_LIST"
    fi
    
    if [ "$ERROR_COUNT" -gt 3 ]; then
        MESSAGE="$MESSAGE
   ...and $((ERROR_COUNT - 3)) more"
    fi
fi

# Add tool call count as rough token estimate
if [ "$TOOL_CALLS" -gt 0 ]; then
    # Very rough estimate: ~1k tokens per tool call average
    ROUGH_TOKENS=$((TOOL_CALLS * 1000))
    if [ "$ROUGH_TOKENS" -gt 1000 ]; then
        TOKEN_DISPLAY="~$((ROUGH_TOKENS / 1000))k tokens"
    else
        TOKEN_DISPLAY="~${ROUGH_TOKENS} tokens"
    fi
    MESSAGE="$MESSAGE

💰 $TOKEN_DISPLAY (est.)"
fi

MESSAGE="$MESSAGE
━━━━━━━━━━━━━━━━━━━━━"

# Update task status
jq --arg reason "$REASON" --arg status "completed" \
   '.status = $status | .ended_at = now | .end_reason = $reason' \
   "$TASK_FILE" > "${TASK_FILE}.tmp" && mv "${TASK_FILE}.tmp" "$TASK_FILE"

# Move to completed
mkdir -p "$BRIDGE_DIR/completed"
mv "$TASK_FILE" "$BRIDGE_DIR/completed/"

# Clean up
rm -f "$BRIDGE_DIR/.stop-lock-$SESSION_ID"
rm -f "$BRIDGE_DIR/tracking/${TASK_ID}.json"

# Clean up any pending questions for this session
find "$BRIDGE_DIR/questions" -name "*.json" 2>/dev/null | while read qf; do
    if [ "$(jq -r '.session_id' "$qf" 2>/dev/null)" = "$SESSION_ID" ]; then
        rm -f "$qf"
    fi
done

# Write completion event
EVENT_FILE="$BRIDGE_DIR/events/$(date +%s%N)-complete.json"
cat > "$EVENT_FILE" << EOF
{
    "event": "session_end",
    "event_type": "complete",
    "task_id": "$TASK_ID",
    "session_id": "$SESSION_ID",
    "status": "$STATUS_LABEL",
    "reason": "$REASON",
    "duration": "$DURATION_STR",
    "files_created": $CREATED_COUNT,
    "files_modified": $MODIFIED_COUNT,
    "error_count": $ERROR_COUNT,
    "tool_calls": $TOOL_CALLS,
    "message": $(echo "$MESSAGE" | jq -Rs .),
    "transcript_summary": $(echo "$TRANSCRIPT_SUMMARY" | jq -Rs .),
    "target_channel": "$TELEGRAM_GROUP",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Send wake with completion (if enabled)
if is_enabled "complete"; then
    send_wake "[CC-COMPLETE] $TASK_ID $STATUS_LABEL" "now" "$TASK_ID"
fi

log_hook "SessionEnd: task=$TASK_ID status=$STATUS_LABEL reason=$REASON duration=$DURATION_STR files=$TOTAL_FILES errors=$ERROR_COUNT"
exit 0
