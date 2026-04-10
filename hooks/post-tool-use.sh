#!/bin/bash
# post-tool-use.sh - Track tool usage for progress updates
# Captures file changes, commands run, and significant activities

set -e
source "$(dirname "$0")/hook-utils.sh"

# Read input from stdin
INPUT=$(cat)

# Extract info
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // "unknown"')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {}')
TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_response // ""' | head -c 500)

# Find task
TASK_FILE=$(find_task_by_session "$SESSION_ID")
[ -z "$TASK_FILE" ] && exit 0

TASK_ID=$(get_task_id "$TASK_FILE")

# Track based on tool type
case "$TOOL_NAME" in
    Write)
        FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // ""')
        if [ -n "$FILE_PATH" ]; then
            track_file_change "$TASK_ID" "$FILE_PATH" "created"
            SHORT_PATH=$(basename "$FILE_PATH")
            update_activity "$TASK_ID" "Created $SHORT_PATH"
            
            # Send progress update for new files (if enabled)
            if is_progress_enabled "file_created"; then
                send_wake "[CC-PROGRESS] [$TASK_ID] 📄 Created $SHORT_PATH" "now" "$TASK_ID"
            fi
        fi
        ;;
    Edit|MultiEdit)
        FILE_PATH=$(echo "$TOOL_INPUT" | jq -r '.file_path // ""')
        if [ -n "$FILE_PATH" ]; then
            track_file_change "$TASK_ID" "$FILE_PATH" "modified"
            SHORT_PATH=$(basename "$FILE_PATH")
            update_activity "$TASK_ID" "Modified $SHORT_PATH"
        fi
        ;;
    Bash)
        COMMAND=$(echo "$TOOL_INPUT" | jq -r '.command // ""' | head -c 100)
        if [ -n "$COMMAND" ]; then
            track_command "$TASK_ID" "$COMMAND"
            update_activity "$TASK_ID" "Ran: $COMMAND"
            
            # Send progress for significant commands (if enabled)
            case "$COMMAND" in
                npm\ install*|pip\ install*|yarn\ add*|brew\ install*)
                    if is_progress_enabled "package_install"; then
                        send_wake "[CC-PROGRESS] [$TASK_ID] 📦 $COMMAND" "now" "$TASK_ID"
                    fi
                    ;;
                pytest*|npm\ test*|go\ test*|cargo\ test*)
                    if is_progress_enabled "tests"; then
                        send_wake "[CC-PROGRESS] [$TASK_ID] 🧪 Running tests..." "now" "$TASK_ID"
                    fi
                    ;;
                git\ commit*|git\ push*)
                    if is_progress_enabled "git"; then
                        send_wake "[CC-PROGRESS] [$TASK_ID] 📤 $COMMAND" "now" "$TASK_ID"
                    fi
                    ;;
            esac
        fi
        ;;
    Task)
        # Subagent spawned
        PROMPT=$(echo "$TOOL_INPUT" | jq -r '.prompt // ""' | head -c 80)
        update_activity "$TASK_ID" "Spawned subagent: $PROMPT"
        if is_progress_enabled "subagent"; then
            send_wake "[CC-PROGRESS] [$TASK_ID] 🤖 Spawned subagent" "now" "$TASK_ID"
        fi
        ;;
esac

log_hook "PostToolUse: task=$TASK_ID tool=$TOOL_NAME"
exit 0
