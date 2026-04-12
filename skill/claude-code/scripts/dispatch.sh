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

# Safe tilde expansion (no eval)
# Note: bash case expands ~ in patterns, so ~/* matches any path under $HOME.
# Use [[ ]] with single-quoted tilde to match the literal ~ character.
if [[ "$WORKDIR" == '~/'* ]]; then
    WORKDIR="$HOME/${WORKDIR:2}"
elif [[ "$WORKDIR" == '~' ]]; then
    WORKDIR="$HOME"
fi
if [ ! -d "$WORKDIR" ]; then
    jq -n --arg msg "Directory does not exist: $WORKDIR" '{"error": $msg}' >&2
    exit 1
fi
WORKDIR=$(cd "$WORKDIR" && pwd)

# Read from openclaw.json, env vars override
OC_FILE="$HOME/.openclaw/openclaw.json"
_oc_config() { [ -f "$OC_FILE" ] && jq -r "$1 // empty" "$OC_FILE" 2>/dev/null || echo ""; }

BRIDGE_DIR="${CC_BRIDGE_DIR:-$HOME/.openclaw/cc-bridge}"
_OC_PORT=$(_oc_config '.gateway.port')
_OC_TOKEN=$(_oc_config '.gateway.auth.token')
export OPENCLAW_GATEWAY_URL="${OPENCLAW_GATEWAY_URL:-http://127.0.0.1:${_OC_PORT:-18789}}"
export OPENCLAW_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-$_OC_TOKEN}"

mkdir -p "$BRIDGE_DIR/tasks" "$BRIDGE_DIR/logs"

# Generate task ID
TASK_ID="task-$(date +%s)-$(openssl rand -hex 4)"
TELEGRAM_GROUP="${CC_TELEGRAM_GROUP:-}"

# Create task file (use jq for safe JSON construction)
TASK_FILE="$BRIDGE_DIR/tasks/${TASK_ID}.json"
jq -n \
    --arg tid "$TASK_ID" \
    --arg prompt "$PROMPT" \
    --arg cwd "$WORKDIR" \
    --argjson agent_teams "$AGENT_TEAMS" \
    --arg model "$MODEL" \
    --argjson timeout "$TIMEOUT_MINUTES" \
    --arg channel "${CC_TELEGRAM_GROUP:-}" \
    --arg topic "${TOPIC:-}" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
        task_id: $tid,
        prompt: $prompt,
        cwd: $cwd,
        options: { agent_teams: $agent_teams, model: $model, timeout_minutes: $timeout },
        target_channel: $channel,
        target_topic: $topic,
        status: "pending",
        created_at: $ts
    }' > "$TASK_FILE"

# Log file
LOG_FILE="$BRIDGE_DIR/logs/${TASK_ID}.log"

# Spawn in background using exported env vars (avoids shell injection)
export CC_TASK_PROMPT="$PROMPT"
export CC_TASK_MODEL="$MODEL"
export CC_TASK_AGENT_TEAMS="$AGENT_TEAMS"
export CC_TASK_LOG_FILE="$LOG_FILE"
export CC_TASK_ID="$TASK_ID"
export CC_TASK_BRIDGE_DIR="$BRIDGE_DIR"
export CC_TASK_GATEWAY_URL="${OPENCLAW_GATEWAY_URL:-http://127.0.0.1:18789}"
export CC_TASK_GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-}"

cd "$WORKDIR"
nohup bash -c '
    export CC_BRIDGE_DIR="$CC_TASK_BRIDGE_DIR"
    export OPENCLAW_GATEWAY_URL="$CC_TASK_GATEWAY_URL"
    export OPENCLAW_GATEWAY_TOKEN="$CC_TASK_GATEWAY_TOKEN"

    # Build command as array (safe from injection)
    CC_CMD=(claude --dangerously-skip-permissions)
    if [ "$CC_TASK_AGENT_TEAMS" = "true" ]; then
        CC_CMD+=(--teammate-mode auto)
    fi
    CC_CMD+=(--model "$CC_TASK_MODEL" -p "$CC_TASK_PROMPT" --output-format stream-json)

    # Run Claude Code
    "${CC_CMD[@]}" 2>&1 | tee "$CC_TASK_LOG_FILE"
    EXIT_CODE=${PIPESTATUS[0]}

    # Update task with exit code
    TASK_JSON="$CC_TASK_BRIDGE_DIR/tasks/${CC_TASK_ID}.json"
    if [ -f "$TASK_JSON" ]; then
        jq --arg ec "$EXIT_CODE" ".exit_code = (\$ec | tonumber)" \
            "$TASK_JSON" > "${TASK_JSON}.tmp" \
            && mv "${TASK_JSON}.tmp" "$TASK_JSON"
    fi
' > /dev/null 2>&1 &

# Get PID
BG_PID=$!

# Update task with PID
jq --arg pid "$BG_PID" '.pid = ($pid | tonumber)' "$TASK_FILE" > "${TASK_FILE}.tmp" \
    && mv "${TASK_FILE}.tmp" "$TASK_FILE"

# Output result (safe JSON)
jq -n \
    --argjson success true \
    --arg tid "$TASK_ID" \
    --arg dir "$WORKDIR" \
    --arg prompt "$PROMPT" \
    --argjson agent_teams "$AGENT_TEAMS" \
    --arg model "$MODEL" \
    --argjson pid "$BG_PID" \
    --arg log "$LOG_FILE" \
    --arg topic "${TOPIC:-}" \
    --arg group "${TELEGRAM_GROUP:-}" \
    '{
        success: $success,
        task_id: $tid,
        directory: $dir,
        prompt: $prompt,
        agent_teams: $agent_teams,
        model: $model,
        pid: $pid,
        log_file: $log,
        topic: $topic,
        group: $group
    }'
