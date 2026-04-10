#!/bin/bash
# status.sh - Check status of Claude Code tasks
# Called by OpenClaw when user sends /cc-status command
#
# Usage: status.sh [task-id]

set -e

TASK_ID="$1"

# Bridge directory
BRIDGE_DIR="${CC_BRIDGE_DIR:-$HOME/.openclaw/cc-bridge}"
TASKS_DIR="$BRIDGE_DIR/tasks"
COMPLETED_DIR="$BRIDGE_DIR/completed"
QUESTIONS_DIR="$BRIDGE_DIR/questions"

# If specific task requested
if [ -n "$TASK_ID" ]; then
    # Find task file
    TASK_FILE=""
    if [ -f "$TASKS_DIR/${TASK_ID}.json" ]; then
        TASK_FILE="$TASKS_DIR/${TASK_ID}.json"
    elif [ -f "$COMPLETED_DIR/${TASK_ID}.json" ]; then
        TASK_FILE="$COMPLETED_DIR/${TASK_ID}.json"
    else
        # Try partial match
        FOUND=$(find "$TASKS_DIR" "$COMPLETED_DIR" -name "*${TASK_ID}*.json" -print -quit 2>/dev/null)
        if [ -n "$FOUND" ]; then
            TASK_FILE="$FOUND"
        fi
    fi
    
    if [ -z "$TASK_FILE" ] || [ ! -f "$TASK_FILE" ]; then
        echo "{\"error\": \"Task not found: $TASK_ID\"}" >&2
        exit 1
    fi
    
    # Get task details
    TASK_DATA=$(cat "$TASK_FILE")
    TASK_ID=$(echo "$TASK_DATA" | jq -r '.task_id')
    STATUS=$(echo "$TASK_DATA" | jq -r '.status // "unknown"')
    CWD=$(echo "$TASK_DATA" | jq -r '.cwd // ""')
    PROMPT=$(echo "$TASK_DATA" | jq -r '.prompt // ""' | head -c 100)
    CREATED=$(echo "$TASK_DATA" | jq -r '.created_at // ""')
    PID=$(echo "$TASK_DATA" | jq -r '.pid // null')
    
    # Check if process is still running
    RUNNING=false
    if [ "$PID" != "null" ] && [ -n "$PID" ]; then
        if ps -p "$PID" > /dev/null 2>&1; then
            RUNNING=true
        fi
    fi
    
    # Check for pending questions
    PENDING_QUESTIONS=$(find "$QUESTIONS_DIR" -name "*.json" 2>/dev/null | while read qf; do
        if [ "$(jq -r '.task_id' "$qf" 2>/dev/null)" = "$TASK_ID" ]; then
            jq -c '.' "$qf"
        fi
    done | jq -s '.')
    
    # Get recent log output
    LOG_FILE="$BRIDGE_DIR/logs/${TASK_ID}.log"
    RECENT_LOG=""
    if [ -f "$LOG_FILE" ]; then
        RECENT_LOG=$(tail -20 "$LOG_FILE" 2>/dev/null | head -c 1000 || echo "")
    fi
    
    cat << EOF
{
    "task_id": "$TASK_ID",
    "status": "$STATUS",
    "running": $RUNNING,
    "directory": "$CWD",
    "prompt": $(echo "$PROMPT" | jq -Rs .),
    "created_at": "$CREATED",
    "pid": $PID,
    "pending_questions": $PENDING_QUESTIONS,
    "recent_log": $(echo "$RECENT_LOG" | jq -Rs .)
}
EOF

else
    # List all tasks
    TASKS=()
    
    # Active tasks
    for f in "$TASKS_DIR"/*.json 2>/dev/null; do
        [ -f "$f" ] || continue
        TASK_DATA=$(cat "$f")
        TASK_ID=$(echo "$TASK_DATA" | jq -r '.task_id')
        STATUS=$(echo "$TASK_DATA" | jq -r '.status // "unknown"')
        CWD=$(echo "$TASK_DATA" | jq -r '.cwd // ""')
        PROMPT=$(echo "$TASK_DATA" | jq -r '.prompt // ""' | head -c 50)
        
        # Check if running
        PID=$(echo "$TASK_DATA" | jq -r '.pid // null')
        RUNNING=false
        if [ "$PID" != "null" ] && [ -n "$PID" ]; then
            if ps -p "$PID" > /dev/null 2>&1; then
                RUNNING=true
            fi
        fi
        
        TASKS+=("{\"task_id\":\"$TASK_ID\",\"status\":\"$STATUS\",\"running\":$RUNNING,\"directory\":\"$CWD\",\"prompt\":$(echo "$PROMPT" | jq -Rs .)}")
    done
    
    # Pending questions
    QUESTIONS=[]
    if [ -d "$QUESTIONS_DIR" ]; then
        QUESTIONS=$(find "$QUESTIONS_DIR" -name "*.json" -exec cat {} \; 2>/dev/null | jq -s '.')
    fi
    
    # Recent completed (last 5)
    COMPLETED=[]
    if [ -d "$COMPLETED_DIR" ]; then
        COMPLETED=$(ls -t "$COMPLETED_DIR"/*.json 2>/dev/null | head -5 | while read f; do
            jq -c '{task_id, status, cwd: .cwd, ended_at: .ended_at}' "$f"
        done | jq -s '.')
    fi
    
    # Output
    echo "{\"active_tasks\": [$(IFS=,; echo "${TASKS[*]}")], \"pending_questions\": $QUESTIONS, \"recent_completed\": $COMPLETED}"
fi
