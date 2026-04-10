#!/bin/bash
# cc-entry.sh — Single entry point for /cc commands
# Parses raw args into directory + prompt, then calls dispatch.sh
#
# Usage: cc-entry.sh <directory> <task description...>
#   e.g. cc-entry.sh ~/projects/myapp implement user auth
#   e.g. cc-entry.sh --topic 42 ~/projects/api build endpoints

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ $# -lt 2 ]; then
    echo '{"error": "Usage: /cc <directory> <task description>"}'
    exit 1
fi

# Parse --topic flag if present
TOPIC_ARGS=()
if [ "$1" = "--topic" ]; then
    TOPIC_ARGS=(--topic "$2")
    shift 2
fi

# First arg is directory, rest is prompt
DIR="$1"
shift
PROMPT="$*"

if [ -z "$DIR" ] || [ -z "$PROMPT" ]; then
    echo '{"error": "Usage: /cc <directory> <task description>"}'
    exit 1
fi

# Call dispatch.sh with safe argument passing (no eval)
exec "$SCRIPT_DIR/dispatch.sh" --dir "$DIR" "${TOPIC_ARGS[@]}" -- "$PROMPT"
