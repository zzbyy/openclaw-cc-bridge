#!/bin/bash
# install.sh - Install/Update OpenClaw + Claude Code Bridge
#
# Safe to re-run — idempotent. Existing bridge hooks are replaced, not duplicated.
#
# This script:
# 1. Creates necessary directories
# 2. Copies hook scripts to ~/.claude/hooks/
# 3. Merges hooks config into ~/.claude/settings.json (idempotent)
# 4. Copies skill to OpenClaw skills directory
# 5. Verifies OpenClaw configuration

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
    
    # Idempotent merge: remove existing bridge hooks (identified by ~/.claude/hooks/ path),
    # then append new ones. This makes re-running safe (update, not duplicate).
    NEW_HOOKS=$(jq '.hooks' "$SCRIPT_DIR/claude-settings.json")
    jq --argjson new "$NEW_HOOKS" '
        # First strip any existing bridge hook entries from all events
        .hooks |= (if . then
            with_entries(
                .value |= [.[] | select(.hooks | all(.command | test("~/\\.claude/hooks/") | not))]
            )
        else {} end) |
        # Then append new bridge hooks
        reduce ($new | keys[]) as $event (
            .;
            .hooks[$event] = ((.hooks[$event] // []) + $new[$event])
        )
    ' "$CLAUDE_SETTINGS" > "${CLAUDE_SETTINGS}.tmp"
    mv "${CLAUDE_SETTINGS}.tmp" "$CLAUDE_SETTINGS"
    success "Merged hooks into settings (safe to re-run)"
else
    cp "$SCRIPT_DIR/claude-settings.json" "$CLAUDE_SETTINGS"
    success "Created new settings.json"
fi

# 4. Copy OpenClaw skill (personal skills dir: ~/.agents/skills/)
echo ""
echo "Installing OpenClaw skill..."
SKILLS_DIR="$HOME/.agents/skills"
mkdir -p "$SKILLS_DIR"

if [ -d "$SCRIPT_DIR/skill/claude-code" ]; then
    # Remove old locations if they exist
    rm -rf "$HOME/.openclaw/skills/claude-code" 2>/dev/null || true
    rm -rf "$SKILLS_DIR/claude-code" 2>/dev/null || true
    # Install as 'cc' skill (matches the name in SKILL.md frontmatter)
    rm -rf "$SKILLS_DIR/cc" 2>/dev/null || true
    cp -r "$SCRIPT_DIR/skill/claude-code" "$SKILLS_DIR/cc"
    chmod +x "$SKILLS_DIR/cc/scripts"/*.sh 2>/dev/null || true
    success "Installed cc skill to $SKILLS_DIR/cc/"
else
    warn "Skill directory not found, skipping"
fi

# 5. Verify OpenClaw config
echo ""
echo "Checking OpenClaw configuration..."
OC_FILE="$HOME/.openclaw/openclaw.json"

if [ -f "$OC_FILE" ]; then
    # Check gateway token
    OC_TOKEN=$(jq -r '.gateway.auth.token // empty' "$OC_FILE" 2>/dev/null)
    if [ -n "$OC_TOKEN" ]; then
        success "Gateway token found in openclaw.json"
    else
        warn "No gateway token in openclaw.json — run: openclaw configure"
    fi

    # Check telegram channel
    TG_ENABLED=$(jq -r '.channels.telegram.enabled // false' "$OC_FILE" 2>/dev/null)
    if [ "$TG_ENABLED" = "true" ]; then
        success "Telegram channel enabled"
    else
        warn "Telegram not enabled — run: openclaw configure"
    fi
else
    warn "openclaw.json not found — run: openclaw configure"
fi

# Check if CC_TELEGRAM_GROUP is set (needed for targeting notifications)
if [ -z "${CC_TELEGRAM_GROUP:-}" ]; then
    # Check .env file too
    OPENCLAW_ENV="$HOME/.openclaw/.env"
    if [ -f "$OPENCLAW_ENV" ] && grep -q "^CC_TELEGRAM_GROUP=" "$OPENCLAW_ENV" 2>/dev/null; then
        success "CC_TELEGRAM_GROUP found in .env"
    else
        warn "CC_TELEGRAM_GROUP not set — add to ~/.openclaw/.env for targeted notifications"
    fi
else
    success "CC_TELEGRAM_GROUP is set"
fi

# 6. Print summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Installation complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Gateway token and port are read from ~/.openclaw/openclaw.json automatically."
echo ""
echo "Next steps:"
echo ""
echo "1. (Optional) Set Telegram group for targeted notifications:"
echo "   echo 'CC_TELEGRAM_GROUP=-100xxxxxxxxxx' >> ~/.openclaw/.env"
echo ""
echo "2. Start/restart OpenClaw:"
echo "   openclaw start"
echo ""
echo "3. Test via Telegram:"
echo "   cc ~/test-folder create a hello.py that prints hello world"
echo ""
echo "For detailed setup instructions, see WALKTHROUGH.md"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
