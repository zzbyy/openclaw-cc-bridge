#!/bin/bash
# answer.sh - Write user's answer to a Claude Code question
# Called by OpenClaw when user replies with /answer command
#
# Usage: answer.sh <question-id> <answer-text>

set -e

if [ $# -lt 2 ]; then
    [ $# -lt 1 ] && echo '{"error": "No question ID specified"}' >&2 && exit 1
    echo '{"error": "No answer text specified"}' >&2 && exit 1
fi

QUESTION_ID="$1"
shift
ANSWER_TEXT="$*"

# Validate ID format (alphanumeric, hyphens, underscores only)
if [[ ! "$QUESTION_ID" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo '{"error": "Invalid question ID format"}' >&2
    exit 1
fi

# Bridge directory
BRIDGE_DIR="${CC_BRIDGE_DIR:-$HOME/.openclaw/cc-bridge}"
QUESTIONS_DIR="$BRIDGE_DIR/questions"
ANSWERS_DIR="$BRIDGE_DIR/answers"

mkdir -p "$ANSWERS_DIR"

# Check if question exists
QUESTION_FILE="$QUESTIONS_DIR/${QUESTION_ID}.json"
if [ ! -f "$QUESTION_FILE" ]; then
    # Try finding by partial match
    FOUND=$(find "$QUESTIONS_DIR" -name "*${QUESTION_ID}*.json" -print -quit 2>/dev/null)
    if [ -n "$FOUND" ]; then
        QUESTION_FILE="$FOUND"
        QUESTION_ID=$(basename "$FOUND" .json)
    else
        echo "{\"error\": \"Question not found: $QUESTION_ID\"}" >&2
        exit 1
    fi
fi

# Get question info
TASK_ID=$(jq -r '.task_id // ""' "$QUESTION_FILE")
SESSION_ID=$(jq -r '.session_id // ""' "$QUESTION_FILE")

# Write answer file
ANSWER_FILE="$ANSWERS_DIR/${QUESTION_ID}.json"
cat > "$ANSWER_FILE" << EOF
{
    "question_id": "$QUESTION_ID",
    "task_id": "$TASK_ID",
    "session_id": "$SESSION_ID",
    "answer": $(echo "$ANSWER_TEXT" | jq -Rs .),
    "status": "answered",
    "answered_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

# Log
echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Answer written: id=$QUESTION_ID task=$TASK_ID" \
    >> "$BRIDGE_DIR/logs/hooks.log"

# Output result
cat << EOF
{
    "success": true,
    "question_id": "$QUESTION_ID",
    "task_id": "$TASK_ID",
    "answer_written": true
}
EOF
