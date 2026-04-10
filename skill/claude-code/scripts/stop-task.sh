#!/bin/bash
# stop-task.sh - Stop a running Claude Code task
# Called by OpenClaw when user sends /cc-stop command
#
# Usage: stop-task.sh <task-id>

set -e

TASK_ID="$1"

if [ -z "$TASK_ID" ]; then
    echo '{"error": "No task ID specified"}' >&2
    exit 1
fi

# Bridge directory
BRIDGE_DIR="${CC_BRIDGE_DIR:-$HOME/.openclaw/cc-bridge}"
TASKS_DIR="$BRIDGE_DIR/tasks"

# Find task file
TASK_FILE=""
if [ -f "$TASKS_DIR/${TASK_ID}.json" ]; then
    TASK_FILE="$TASKS_DIR/${TASK_ID}.json"
else
    # Try partial match
    FOUND=$(find "$TASKS_DIR" -name "*${TASK_ID}*.json" -print -quit 2>/dev/null)
    if [ -n "$FOUND" ]; then
        TASK_FILE="$FOUND"
        TASK_ID=$(basename "$FOUND" .json)
    fi
fi

if [ -z "$TASK_FILE" ] || [ ! -f "$TASK_FILE" ]; then
    echo "{\"error\": \"Task not found: $TASK_ID\"}" >&2
    exit 1
fi

# Get PID
PID=$(jq -r '.pid // null' "$TASK_FILE")

if [ "$PID" = "null" ] || [ -z "$PID" ]; then
    echo "{\"error\": \"No PID found for task $TASK_ID\"}" >&2
    exit 1
fi

# Check if running
if ! ps -p "$PID" > /dev/null 2>&1; then
    echo "{\"error\": \"Process $PID is not running\"}" >&2
    exit 1
fi

# Kill the process group (to also stop any child processes)
pkill -TERM -P "$PID" 2>/dev/null || true
kill -TERM "$PID" 2>/dev/null || true

# Wait a moment and check
sleep 1

KILLED=true
if ps -p "$PID" > /dev/null 2>&1; then
    # Force kill
    pkill -KILL -P "$PID" 2>/dev/null || true
    kill -KILL "$PID" 2>/dev/null || true
    sleep 1
    
    if ps -p "$PID" > /dev/null 2>&1; then
        KILLED=false
    fi
fi

if [ "$KILLED" = true ]; then
    # Update task status
    jq '.status = "stopped" | .stopped_at = now' "$TASK_FILE" > "${TASK_FILE}.tmp" \
        && mv "${TASK_FILE}.tmp" "$TASK_FILE"
    
    # Move to completed
    mkdir -p "$BRIDGE_DIR/completed"
    mv "$TASK_FILE" "$BRIDGE_DIR/completed/"
    
    echo "{\"success\": true, \"task_id\": \"$TASK_ID\", \"pid\": $PID, \"status\": \"stopped\"}"
else
    echo "{\"error\": \"Failed to stop process $PID\"}" >&2
    exit 1
fi
