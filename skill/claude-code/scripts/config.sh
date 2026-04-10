#!/bin/bash
# config.sh - Manage Claude Code bridge notification settings
#
# Usage:
#   config.sh show                    # Show current config
#   config.sh set <key> <value>       # Set a config value
#   config.sh toggle <key>            # Toggle a boolean value
#   config.sh reset                   # Reset to defaults
#
# Examples:
#   config.sh set notifications.progress false
#   config.sh toggle notifications.start
#   config.sh set progress_filter.milestone_interval 10

set -e

BRIDGE_DIR="${CC_BRIDGE_DIR:-$HOME/.openclaw/cc-bridge}"
CONFIG_FILE="$BRIDGE_DIR/config.json"

# Default config
DEFAULT_CONFIG='{
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
}'

# Ensure config exists
init_config() {
    mkdir -p "$BRIDGE_DIR"
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "$DEFAULT_CONFIG" > "$CONFIG_FILE"
    fi
}

# Show current config
show_config() {
    init_config
    echo "📋 Current notification settings:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Notifications:"
    
    local start=$(jq -r '.notifications.start' "$CONFIG_FILE")
    local progress=$(jq -r '.notifications.progress' "$CONFIG_FILE")
    local question=$(jq -r '.notifications.question' "$CONFIG_FILE")
    local complete=$(jq -r '.notifications.complete' "$CONFIG_FILE")
    local error=$(jq -r '.notifications.error' "$CONFIG_FILE")
    
    [ "$start" = "true" ] && echo "  ✅ start    - Task started" || echo "  ❌ start    - Task started"
    [ "$progress" = "true" ] && echo "  ✅ progress - Progress updates" || echo "  ❌ progress - Progress updates"
    [ "$question" = "true" ] && echo "  ✅ question - Questions (⚠️ keep on)" || echo "  ❌ question - Questions (⚠️ disabled!)"
    [ "$complete" = "true" ] && echo "  ✅ complete - Completion summary" || echo "  ❌ complete - Completion summary"
    [ "$error" = "true" ] && echo "  ✅ error    - Error alerts" || echo "  ❌ error    - Error alerts"
    
    echo ""
    echo "Progress filters (when progress=true):"
    
    local file_created=$(jq -r '.progress_filter.file_created' "$CONFIG_FILE")
    local package_install=$(jq -r '.progress_filter.package_install' "$CONFIG_FILE")
    local tests=$(jq -r '.progress_filter.tests' "$CONFIG_FILE")
    local git=$(jq -r '.progress_filter.git' "$CONFIG_FILE")
    local subagent=$(jq -r '.progress_filter.subagent' "$CONFIG_FILE")
    local milestone=$(jq -r '.progress_filter.milestone_interval' "$CONFIG_FILE")
    
    [ "$file_created" = "true" ] && echo "  ✅ file_created    - New files" || echo "  ❌ file_created    - New files"
    [ "$package_install" = "true" ] && echo "  ✅ package_install - npm/pip install" || echo "  ❌ package_install - npm/pip install"
    [ "$tests" = "true" ] && echo "  ✅ tests           - Test runs" || echo "  ❌ tests           - Test runs"
    [ "$git" = "true" ] && echo "  ✅ git             - Git commits/push" || echo "  ❌ git             - Git commits/push"
    [ "$subagent" = "true" ] && echo "  ✅ subagent        - Subagent spawns" || echo "  ❌ subagent        - Subagent spawns"
    echo "  📊 milestone_interval = $milestone (notify every N steps)"
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Set a config value
set_config() {
    local key="$1"
    local value="$2"
    
    init_config
    
    # Convert on/off to true/false
    case "$value" in
        on|yes|1) value="true" ;;
        off|no|0) value="false" ;;
    esac
    
    # Check if value is a number
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        jq ".$key = $value" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    elif [ "$value" = "true" ] || [ "$value" = "false" ]; then
        jq ".$key = $value" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    else
        jq ".$key = \"$value\"" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    fi
    
    echo "✅ Set $key = $value"
}

# Toggle a boolean value
toggle_config() {
    local key="$1"
    
    init_config
    
    local current=$(jq -r ".$key" "$CONFIG_FILE")
    local new_value="true"
    [ "$current" = "true" ] && new_value="false"
    
    jq ".$key = $new_value" "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    
    [ "$new_value" = "true" ] && echo "✅ $key is now ON" || echo "❌ $key is now OFF"
}

# Reset to defaults
reset_config() {
    echo "$DEFAULT_CONFIG" > "$CONFIG_FILE"
    echo "✅ Config reset to defaults"
}

# Quick presets
preset_quiet() {
    init_config
    jq '.notifications.start = false | .notifications.progress = false | .notifications.complete = true | .notifications.error = true' \
        "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo "🔇 Quiet mode: Only completion and errors"
}

preset_minimal() {
    init_config
    jq '.notifications.start = true | .notifications.progress = false | .notifications.complete = true | .notifications.error = true' \
        "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo "📝 Minimal mode: Start, completion, and errors only"
}

preset_verbose() {
    init_config
    jq '.notifications.start = true | .notifications.progress = true | .notifications.complete = true | .notifications.error = true | .progress_filter.file_created = true | .progress_filter.package_install = true | .progress_filter.tests = true | .progress_filter.git = true | .progress_filter.subagent = true' \
        "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo "📢 Verbose mode: All notifications enabled"
}

# Main
case "${1:-show}" in
    show|status)
        show_config
        ;;
    set)
        [ -z "$2" ] || [ -z "$3" ] && echo "Usage: config.sh set <key> <value>" && exit 1
        set_config "$2" "$3"
        ;;
    toggle)
        [ -z "$2" ] && echo "Usage: config.sh toggle <key>" && exit 1
        toggle_config "$2"
        ;;
    reset)
        reset_config
        ;;
    quiet)
        preset_quiet
        ;;
    minimal)
        preset_minimal
        ;;
    verbose)
        preset_verbose
        ;;
    *)
        echo "Usage: config.sh <command>"
        echo ""
        echo "Commands:"
        echo "  show                  Show current settings"
        echo "  set <key> <value>     Set a value (e.g., notifications.progress false)"
        echo "  toggle <key>          Toggle a boolean"
        echo "  reset                 Reset to defaults"
        echo ""
        echo "Presets:"
        echo "  quiet                 Only completion and errors"
        echo "  minimal               Start, completion, and errors"
        echo "  verbose               All notifications"
        echo ""
        echo "Keys:"
        echo "  notifications.start, .progress, .question, .complete, .error"
        echo "  progress_filter.file_created, .package_install, .tests, .git, .subagent"
        echo "  progress_filter.milestone_interval (number)"
        ;;
esac
