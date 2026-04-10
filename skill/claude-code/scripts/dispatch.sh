#!/bin/bash
# dispatch.sh - Spawn Claude Code task in background
# Called by OpenClaw when user sends a cc/claude-code command
#
# Usage: dispatch.sh --dir <directory> [--agent-teams] [--model <model>] -- <prompt>

set -e

# Defaults
WORKDIR=""
AGENT_TEAMS=false
MODEL="claude-sonnet-4"
TIMEOUT_MINUTES=60
TOPIC=""
PROMPT=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dir|-d)
            WORKDIR="$2"
            shift 2
            ;;
        --agent-teams|-t)
            AGENT_TEAMS=true
            shift
            ;;
        --model|-m)
            MODEL="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT_MINUTES="$2"
            shift 2
            ;;
        --topic)
            TOPIC="$2"
            shift 2
            ;;
        --)
            shift
            PROMPT="$*"
            break
            ;;
        *)
            # If no -- separator, treat remaining as prompt
            PROMPT="$*"
            break
            ;;
    esac
done

# Validate
if [ -z "$WORKDIR" ]; then
    echo '{"error": "No directory specified. Use --dir <path>"}' >&2
    exit 1
fi

if [ -z "$PROMPT" ]; then
    echo '{"error": "No prompt specified"}' >&2
    exit 1
fi

# Expand ~ and resolve path
WORKDIR=$(eval echo "$WORKDIR")
if [ ! -d "$WORKDIR" ]; then
    echo "{\"error\": \"Directory does not exist: $WORKDIR\"}" >&2
    exit 1
fi
WORKDIR=$(cd "$WORKDIR" && pwd)

# Bridge directory
BRIDGE_DIR="${CC_BRIDGE_DIR:-$HOME/.openclaw/cc-bridge}"
mkdir -p "$BRIDGE_DIR/tasks" "$BRIDGE_DIR/logs"

# Generate task ID
TASK_ID="task-$(date +%s)-$(openssl rand -hex 4)"

# Create task file
TASK_FILE="$BRIDGE_DIR/tasks/${TASK_ID}.json"
cat > "$TASK_FILE" << EOF
{
    "task_id": "$TASK_ID",
    "prompt": $(echo "$PROMPT" | jq -Rs .),
    "cwd": "$WORKDIR",
    "options": {
        "agent_teams": $AGENT_TEAMS,
        "model": "$MODEL",
        "timeout_minutes": $TIMEOUT_MINUTES
    },
    "target_channel": "${CC_TELEGRAM_GROUP:-}",
    "target_topic": "${TOPIC:-}",
    "status": "pending",
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Build Claude Code command
CC_CMD="claude --dangerously-skip-permissions"

if [ "$AGENT_TEAMS" = true ]; then
    CC_CMD="$CC_CMD --teammate-mode auto"
fi

CC_CMD="$CC_CMD --model $MODEL"
CC_CMD="$CC_CMD -p \"$PROMPT\""
CC_CMD="$CC_CMD --output-format stream-json"

# Log file
LOG_FILE="$BRIDGE_DIR/logs/${TASK_ID}.log"

# Spawn in background
cd "$WORKDIR"
nohup bash -c "
    export CC_BRIDGE_DIR=\"$BRIDGE_DIR\"
    export OPENCLAW_GATEWAY_URL=\"${OPENCLAW_GATEWAY_URL:-http://127.0.0.1:18789}\"
    export OPENCLAW_GATEWAY_TOKEN=\"${OPENCLAW_GATEWAY_TOKEN:-}\"
    
    # Run Claude Code
    $CC_CMD 2>&1 | tee \"$LOG_FILE\"
    
    # Capture exit code
    EXIT_CODE=\${PIPESTATUS[0]}
    
    # Update task with exit code
    if [ -f \"$BRIDGE_DIR/tasks/${TASK_ID}.json\" ]; then
        jq --arg ec \"\$EXIT_CODE\" '.exit_code = (\$ec | tonumber)' \
            \"$BRIDGE_DIR/tasks/${TASK_ID}.json\" > \"$BRIDGE_DIR/tasks/${TASK_ID}.json.tmp\" \
            && mv \"$BRIDGE_DIR/tasks/${TASK_ID}.json.tmp\" \"$BRIDGE_DIR/tasks/${TASK_ID}.json\"
    fi
" > /dev/null 2>&1 &

# Get PID
BG_PID=$!

# Update task with PID
jq --arg pid "$BG_PID" '.pid = ($pid | tonumber)' "$TASK_FILE" > "${TASK_FILE}.tmp" \
    && mv "${TASK_FILE}.tmp" "$TASK_FILE"

# Output result
cat << EOF
{
    "success": true,
    "task_id": "$TASK_ID",
    "directory": "$WORKDIR",
    "prompt": $(echo "$PROMPT" | jq -Rs .),
    "agent_teams": $AGENT_TEAMS,
    "model": "$MODEL",
    "pid": $BG_PID,
    "log_file": "$LOG_FILE"
}
EOF
