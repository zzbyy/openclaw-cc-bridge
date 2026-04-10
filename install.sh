#!/bin/bash
# install.sh - Install OpenClaw + Claude Code Bridge
#
# This script:
# 1. Creates necessary directories
# 2. Copies hook scripts to ~/.claude/hooks/
# 3. Merges hooks config into ~/.claude/settings.json
# 4. Copies skill to OpenClaw skills directory
# 5. Adds environment variables to ~/.openclaw/.env

set -e

echo "🔧 Installing OpenClaw + Claude Code Bridge..."

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
error() { echo -e "${RED}✗${NC} $1"; exit 1; }

# 1. Create bridge directories
echo ""
echo "Creating bridge directories..."
BRIDGE_DIR="$HOME/.openclaw/cc-bridge"
mkdir -p "$BRIDGE_DIR"/{tasks,questions,answers,events,logs,completed,tracking}
success "Created $BRIDGE_DIR/"

# 2. Copy hook scripts
echo ""
echo "Installing Claude Code hooks..."
HOOKS_DIR="$HOME/.claude/hooks"
mkdir -p "$HOOKS_DIR"

for hook in "$SCRIPT_DIR/hooks"/*.sh; do
    [ -f "$hook" ] || continue
    cp "$hook" "$HOOKS_DIR/"
    chmod +x "$HOOKS_DIR/$(basename "$hook")"
    success "Installed $(basename "$hook")"
done

# 3. Configure Claude Code settings
echo ""
echo "Configuring Claude Code hooks..."
CLAUDE_SETTINGS="$HOME/.claude/settings.json"

if [ -f "$CLAUDE_SETTINGS" ]; then
    # Backup existing
    cp "$CLAUDE_SETTINGS" "${CLAUDE_SETTINGS}.backup.$(date +%s)"
    success "Backed up existing settings"
    
    # Merge hooks — append to existing arrays instead of replacing them
    NEW_HOOKS=$(jq '.hooks' "$SCRIPT_DIR/claude-settings.json")
    jq --argjson new "$NEW_HOOKS" '
        .hooks as $existing |
        reduce ($new | keys[]) as $event (
            .;
            .hooks[$event] = (($existing[$event] // []) + $new[$event])
        )
    ' "$CLAUDE_SETTINGS" > "${CLAUDE_SETTINGS}.tmp"
    mv "${CLAUDE_SETTINGS}.tmp" "$CLAUDE_SETTINGS"
    success "Merged hooks into existing settings (appended, not replaced)"
else
    cp "$SCRIPT_DIR/claude-settings.json" "$CLAUDE_SETTINGS"
    success "Created new settings.json"
fi

# 4. Copy OpenClaw skill
echo ""
echo "Installing OpenClaw skill..."
SKILLS_DIR="$HOME/.openclaw/skills"
mkdir -p "$SKILLS_DIR"

if [ -d "$SCRIPT_DIR/skill/claude-code" ]; then
    cp -r "$SCRIPT_DIR/skill/claude-code" "$SKILLS_DIR/"
    chmod +x "$SKILLS_DIR/claude-code/scripts"/*.sh 2>/dev/null || true
    success "Installed claude-code skill"
else
    warn "Skill directory not found, skipping"
fi

# 5. Configure environment
echo ""
echo "Configuring environment..."
OPENCLAW_ENV="$HOME/.openclaw/.env"

# Get gateway token
GATEWAY_TOKEN=""
if command -v openclaw &> /dev/null; then
    # Try to get token from openclaw config
    GATEWAY_TOKEN=$(openclaw config get hooks.token 2>/dev/null || echo "")
fi

if [ ! -f "$OPENCLAW_ENV" ]; then
    touch "$OPENCLAW_ENV"
fi

# Add variables if not present
add_env_var() {
    local var="$1"
    local value="$2"
    if ! grep -q "^${var}=" "$OPENCLAW_ENV" 2>/dev/null; then
        echo "${var}=${value}" >> "$OPENCLAW_ENV"
        success "Added $var to .env"
    else
        warn "$var already set in .env"
    fi
}

add_env_var "OPENCLAW_GATEWAY_URL" "http://127.0.0.1:18789"
add_env_var "CC_BRIDGE_DIR" "$BRIDGE_DIR"

if [ -n "$GATEWAY_TOKEN" ]; then
    add_env_var "OPENCLAW_GATEWAY_TOKEN" "$GATEWAY_TOKEN"
else
    warn "Gateway token not found. Please add OPENCLAW_GATEWAY_TOKEN to $OPENCLAW_ENV"
fi

# 6. Print summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Installation complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo ""
echo "1. Add to ~/.openclaw/.env:"
echo "   OPENCLAW_GATEWAY_TOKEN=your-gateway-token"
echo "   CC_TELEGRAM_GROUP=-100xxxxxxxxxx  # Your Telegram group ID"
echo ""
echo "2. Load environment (add to ~/.zshrc or ~/.bashrc):"
echo '   if [ -f ~/.openclaw/.env ]; then'
echo '       set -a; source ~/.openclaw/.env; set +a'
echo '   fi'
echo ""
echo "3. Enable hooks in OpenClaw:"
echo '   openclaw config set hooks.enabled true'
echo '   openclaw config set hooks.token "your-gateway-token"'
echo ""
echo "4. Start/restart OpenClaw:"
echo "   openclaw start"
echo ""
echo "5. Test via Telegram:"
echo "   cc ~/test-folder create a hello.py that prints hello world"
echo ""
echo "For detailed setup instructions, see WALKTHROUGH.md"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
