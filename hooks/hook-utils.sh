#!/bin/bash
# hook-utils.sh - Shared utilities for Claude Code hooks
# Source this file in other hooks: source ~/.claude/hooks/hook-utils.sh

# Read a value from openclaw.json (falls back to empty string)
_oc_config() {
    local key="$1"
    local oc_file="$HOME/.openclaw/openclaw.json"
    [ -f "$oc_file" ] && jq -r "$key // empty" "$oc_file" 2>/dev/null || echo ""
}

# Bridge directory
export BRIDGE_DIR="${CC_BRIDGE_DIR:-$HOME/.openclaw/cc-bridge}"

# Gateway — read from openclaw.json, env vars override
_OC_PORT=$(_oc_config '.gateway.port')
_OC_TOKEN=$(_oc_config '.gateway.auth.token')
export GATEWAY_URL="${OPENCLAW_GATEWAY_URL:-http://127.0.0.1:${_OC_PORT:-18789}}"
export GATEWAY_TOKEN="${OPENCLAW_GATEWAY_TOKEN:-$_OC_TOKEN}"

# Telegram group/channel for notifications — env var or bridge config
export TELEGRAM_GROUP="${CC_TELEGRAM_GROUP:-}"

# Config file for notification settings
CONFIG_FILE="$BRIDGE_DIR/config.json"

# Initialize default config if not exists
init_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" << 'EOF'
{
    "notifications": {
        "start": true,
        "progress": true,
        "question": true,
        "complete": true,
        "error": true
    },
    "progress_filter": {
        "file_created": true,
        "package_install": true,
        "tests": true,
        "git": true,
        "subagent": true,
        "milestone_interval": 5
    }
}
EOF
    fi
}

# Get config value (returns "true" or "false")
get_config() {
    local key="$1"
    local default="${2:-true}"

    [ ! -f "$CONFIG_FILE" ] && echo "$default" && return

    # Use explicit null check — jq's // operator treats false as falsy
    local value=$(jq -r "if .$key == null then \"$default\" else .$key end" "$CONFIG_FILE" 2>/dev/null)
    [ "$value" = "null" ] && echo "$default" || echo "$value"
}

# Check if notification type is enabled
is_enabled() {
    local type="$1"
    local value=$(get_config "notifications.$type" "true")
    [ "$value" = "true" ]
}

# Check if progress subtype is enabled
is_progress_enabled() {
    local subtype="$1"
    # First check if progress is enabled at all
    is_enabled "progress" || return 1
    # Then check specific subtype
    local value=$(get_config "progress_filter.$subtype" "true")
    [ "$value" = "true" ]
}
# Get target from task file (group + optional topic)
get_task_target() {
    local task_id="$1"
    local task_file="$BRIDGE_DIR/tasks/${task_id}.json"
    
    # Check completed folder too
    [ ! -f "$task_file" ] && task_file="$BRIDGE_DIR/completed/${task_id}.json"
    [ ! -f "$task_file" ] && return
    
    local group=$(jq -r '.target_channel // ""' "$task_file")
    local topic=$(jq -r '.target_topic // ""' "$task_file")
    
    if [ -n "$topic" ] && [ "$topic" != "null" ]; then
        echo "${group}:topic:${topic}"
    else
        echo "$group"
    fi
}

# Ensure directories exist
mkdir -p "$BRIDGE_DIR"/{tasks,questions,answers,events,logs,completed,tracking}

# Find task by session ID
find_task_by_session() {
    local session_id="$1"
    for f in "$BRIDGE_DIR/tasks"/*.json; do
        [ -f "$f" ] || continue
        if [ "$(jq -r '.session_id' "$f" 2>/dev/null)" = "$session_id" ]; then
            echo "$f"
            return 0
        fi
    done
    return 1
}

# Find task by CWD (for session start before session_id is known)
find_task_by_cwd() {
    local cwd="$1"
    while IFS= read -r f; do
        if [ "$(jq -r '.cwd' "$f" 2>/dev/null)" = "$cwd" ] && \
           [ "$(jq -r '.status' "$f" 2>/dev/null)" = "pending" ]; then
            echo "$f"
            return 0
        fi
    done < <(find "$BRIDGE_DIR/tasks" -name "*.json" -mmin -10 2>/dev/null)
    return 1
}

# Get task ID from file path
get_task_id() {
    basename "$1" .json
}

# Send wake event to OpenClaw with optional channel/topic targeting
# Usage: send_wake "message" [mode] [task_id]
send_wake() {
    local message="$1"
    local mode="${2:-now}"
    local task_id="${3:-}"
    
    if [ -n "$GATEWAY_TOKEN" ]; then
        # Determine target: task-specific topic > default group
        local target=""
        if [ -n "$task_id" ]; then
            target=$(get_task_target "$task_id")
        fi
        [ -z "$target" ] && target="$TELEGRAM_GROUP"
        
        # Build JSON payload
        local payload="{\"text\":$(echo "$message" | jq -Rs .),\"mode\":\"$mode\""
        
        if [ -n "$target" ]; then
            payload="$payload,\"channel\":\"telegram\",\"to\":\"$target\""
        fi
        
        payload="$payload}"
        
        curl -s -X POST "$GATEWAY_URL/hooks/wake" \
            -H "Authorization: Bearer $GATEWAY_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            > /dev/null 2>&1 || true
    fi
}

# Log to hook log file
log_hook() {
    local message="$1"
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $message" >> "$BRIDGE_DIR/logs/hooks.log"
}

# Get tracking file for a task
get_tracking_file() {
    local task_id="$1"
    echo "$BRIDGE_DIR/tracking/${task_id}.json"
}

# Initialize tracking for a task
init_tracking() {
    local task_id="$1"
    local tracking_file=$(get_tracking_file "$task_id")
    
    cat > "$tracking_file" << EOF
{
    "task_id": "$task_id",
    "files_created": [],
    "files_modified": [],
    "commands_run": [],
    "errors": [],
    "last_activity": "",
    "tool_calls": 0,
    "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

# Add file change to tracking
track_file_change() {
    local task_id="$1"
    local file_path="$2"
    local change_type="$3"  # "created" or "modified"
    local tracking_file=$(get_tracking_file "$task_id")
    
    [ -f "$tracking_file" ] || return
    
    local field="files_modified"
    [ "$change_type" = "created" ] && field="files_created"
    
    # Add if not already tracked
    local exists=$(jq -r --arg f "$file_path" ".${field} | index(\$f)" "$tracking_file")
    if [ "$exists" = "null" ]; then
        jq --arg f "$file_path" ".${field} += [\$f]" "$tracking_file" > "${tracking_file}.tmp" \
            && mv "${tracking_file}.tmp" "$tracking_file"
    fi
}

# Add error to tracking
track_error() {
    local task_id="$1"
    local error_msg="$2"
    local tracking_file=$(get_tracking_file "$task_id")
    
    [ -f "$tracking_file" ] || return
    
    jq --arg e "$error_msg" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '.errors += [{"message": $e, "time": $t}]' "$tracking_file" > "${tracking_file}.tmp" \
        && mv "${tracking_file}.tmp" "$tracking_file"
}

# Add command to tracking
track_command() {
    local task_id="$1"
    local command="$2"
    local tracking_file=$(get_tracking_file "$task_id")
    
    [ -f "$tracking_file" ] || return
    
    # Keep only last 10 commands
    jq --arg c "$command" \
       '.commands_run = (.commands_run + [$c] | .[-10:])' "$tracking_file" > "${tracking_file}.tmp" \
        && mv "${tracking_file}.tmp" "$tracking_file"
}

# Update last activity
update_activity() {
    local task_id="$1"
    local activity="$2"
    local tracking_file=$(get_tracking_file "$task_id")
    
    [ -f "$tracking_file" ] || return
    
    jq --arg a "$activity" --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '.last_activity = $a | .last_activity_at = $t | .tool_calls += 1' \
       "$tracking_file" > "${tracking_file}.tmp" \
        && mv "${tracking_file}.tmp" "$tracking_file"
}

# Get summary from tracking
get_tracking_summary() {
    local task_id="$1"
    local tracking_file=$(get_tracking_file "$task_id")
    
    [ -f "$tracking_file" ] && cat "$tracking_file"
}

# Portable high-resolution timestamp for unique filenames (macOS lacks %N)
portable_timestamp() {
    if python3 -c '' 2>/dev/null; then
        python3 -c 'import time; print(int(time.time()*1e9))'
    else
        echo "$(date +%s)$$${RANDOM:-0}"
    fi
}

# Format duration from seconds
format_duration() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local secs=$((seconds % 60))
    
    if [ $minutes -gt 60 ]; then
        local hours=$((minutes / 60))
        minutes=$((minutes % 60))
        echo "${hours}h ${minutes}m"
    elif [ $minutes -gt 0 ]; then
        echo "${minutes}m ${secs}s"
    else
        echo "${secs}s"
    fi
}

# Extract final summary from transcript
extract_transcript_summary() {
    local transcript_path="$1"
    local max_chars="${2:-500}"

    [ -f "$transcript_path" ] || return

    # Portable reverse: tail -r (macOS) or tac (Linux)
    local reversed
    if command -v tac &>/dev/null; then
        reversed=$(tac "$transcript_path" 2>/dev/null)
    elif tail -r /dev/null 2>/dev/null; then
        reversed=$(tail -r "$transcript_path" 2>/dev/null)
    else
        reversed=$(awk '{a[NR]=$0} END{for(i=NR;i>=1;i--)print a[i]}' "$transcript_path" 2>/dev/null)
    fi

    # Get last assistant message content
    echo "$reversed" | while IFS= read -r line; do
        local msg_type=$(echo "$line" | jq -r '.type // empty' 2>/dev/null)
        if [ "$msg_type" = "assistant" ]; then
            echo "$line" | jq -r '.message.content[]? | select(.type=="text") | .text' 2>/dev/null | head -c "$max_chars"
            break
        fi
    done
}
