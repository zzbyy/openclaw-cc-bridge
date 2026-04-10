#!/bin/bash
# remote-install.sh — One-click installer for OpenClaw + Claude Code Bridge
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/zzbyy/openclaw-cc-bridge/main/remote-install.sh | bash
#
# Or with a specific branch/tag:
#   curl -fsSL https://raw.githubusercontent.com/zzbyy/openclaw-cc-bridge/main/remote-install.sh | bash -s -- --ref v1.0.0

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${GREEN}==>${NC} $1"; }
warn()    { echo -e "${YELLOW}==>${NC} $1"; }
error()   { echo -e "${RED}==>${NC} $1"; exit 1; }

# Parse arguments
REPO="zzbyy/openclaw-cc-bridge"
REF="main"

while [[ $# -gt 0 ]]; do
    case $1 in
        --ref|-r) REF="$2"; shift 2 ;;
        --repo)   REPO="$2"; shift 2 ;;
        *)        shift ;;
    esac
done

# Check dependencies
command -v git  &>/dev/null || error "git is required but not installed"
command -v jq   &>/dev/null || error "jq is required. Install: brew install jq (macOS) or apt install jq (Linux)"
command -v curl &>/dev/null || error "curl is required but not installed"

# Check for Claude Code
if ! command -v claude &>/dev/null; then
    warn "Claude Code not found. Install from https://docs.anthropic.com/claude-code"
    warn "Continuing anyway — hooks will work once Claude Code is installed."
fi

# Create temp directory and ensure cleanup
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

info "Downloading openclaw-cc-bridge ($REF)..."
git clone --depth 1 --branch "$REF" "https://github.com/${REPO}.git" "$TMPDIR/openclaw-cc-bridge" 2>&1 | tail -1

info "Running installer..."
cd "$TMPDIR/openclaw-cc-bridge"
bash install.sh

echo ""
info "Done! Run 'openclaw start' and send a task from Telegram."
