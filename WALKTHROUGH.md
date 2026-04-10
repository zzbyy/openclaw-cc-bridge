# OpenClaw + Claude Code + Telegram Bridge

## Complete Setup Walkthrough

This guide walks you through setting up a system where you can:
- Dispatch Claude Code tasks from Telegram
- Receive progress updates, questions, and completion summaries
- Answer Claude Code questions remotely
- Run multiple tasks in parallel (each in its own forum topic)
- Configure which notifications you receive

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Install OpenClaw](#2-install-openclaw)
3. [Create Telegram Bot](#3-create-telegram-bot)
4. [Configure OpenClaw for Telegram](#4-configure-openclaw-for-telegram)
5. [Install the Bridge](#5-install-the-bridge)
6. [Configure Environment Variables](#6-configure-environment-variables)
7. [Enable OpenClaw Hooks](#7-enable-openclaw-hooks)
8. [Set Up Forum Topics (Optional)](#8-set-up-forum-topics-optional)
9. [Test the Setup](#9-test-the-setup)
10. [Daily Usage](#10-daily-usage)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Prerequisites

Before starting, ensure you have:

- [ ] **Claude Code** installed and working
  ```bash
  claude --version
  ```
  If not installed: https://docs.anthropic.com/claude-code

- [ ] **Node.js 18+** (for OpenClaw)
  ```bash
  node --version
  ```

- [ ] **jq** installed (for JSON processing in hooks)
  ```bash
  # macOS
  brew install jq
  
  # Ubuntu/Debian
  sudo apt install jq
  
  # Verify
  jq --version
  ```

- [ ] **A Telegram account**

---

## 2. Install OpenClaw

OpenClaw is your AI gateway that connects Telegram to your local machine.

```bash
# Install globally
npm install -g openclaw

# Verify installation
openclaw --version
```

Create the OpenClaw directory structure:

```bash
mkdir -p ~/.openclaw/{skills,cc-bridge}
```

---

## 3. Create Telegram Bot

### Step 3.1: Create the Bot

1. Open Telegram and search for `@BotFather`
2. Send `/newbot`
3. Follow prompts to name your bot (e.g., "My Dev Assistant")
4. Save the **API token** (looks like `123456789:ABCdefGHI...`)

### Step 3.2: Get Your User ID

1. Search for `@userinfobot` in Telegram
2. Send `/start`
3. Save your **User ID** (a number like `123456789`)

### Step 3.3: Create a Group/Channel (Recommended)

For a dedicated "control room":

1. Create a new Telegram group (or forum/channel)
2. Add your bot to the group
3. Make the bot an admin (so it can post)
4. Get the group ID:
   - Send a message in the group
   - Visit: `https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates`
   - Look for `"chat":{"id":-100xxxxxxxxxx}` — that's your group ID

**For forum topics**: Enable "Topics" in group settings to use parallel task threads.

---

## 4. Configure OpenClaw for Telegram

### Step 4.1: Initialize Configuration

```bash
openclaw init
```

### Step 4.2: Edit Configuration

Open `~/.openclaw/config.yaml` and configure:

```yaml
# ~/.openclaw/config.yaml

gateway:
  port: 18789
  token: "your-secure-gateway-token"  # Generate: openssl rand -hex 32

channels:
  telegram:
    enabled: true
    token: "YOUR_BOT_TOKEN_FROM_BOTFATHER"
    allowedUsers:
      - YOUR_USER_ID
    # Optional: restrict to specific groups
    groups:
      - "-100xxxxxxxxxx"  # Your group ID
    groupPolicy: "allowlist"  # or "open" to allow any group

hooks:
  enabled: true
  token: "your-secure-gateway-token"  # Same as gateway.token

# Skills directory
skills:
  directory: ~/.openclaw/skills
```

### Step 4.3: Test Telegram Connection

```bash
# Start OpenClaw
openclaw start

# In another terminal, check logs
openclaw logs --follow
```

Send a message to your bot in Telegram. You should see it in the logs.

---

## 5. Install the Bridge

### Step 5.1: Install the Bridge

**One-line install (recommended):**

```bash
curl -fsSL https://raw.githubusercontent.com/zzbyy/openclaw-cc-bridge/main/remote-install.sh | bash
```

**Or clone and install manually:**

```bash
git clone https://github.com/zzbyy/openclaw-cc-bridge.git
cd openclaw-cc-bridge
./install.sh
```

The installer will:
- Copy hooks to `~/.claude/hooks/`
- Copy skill to `~/.openclaw/skills/claude-code/`
- Merge settings into `~/.claude/settings.json`

### Step 5.2: Manual Installation (Alternative)

If you prefer manual setup:

```bash
# Create directories
mkdir -p ~/.claude/hooks
mkdir -p ~/.openclaw/skills/claude-code/scripts
mkdir -p ~/.openclaw/cc-bridge/{tasks,questions,answers,events,logs,completed,tracking}

# Copy hooks
cp hooks/*.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh

# Copy skill
cp -r skill/claude-code/* ~/.openclaw/skills/claude-code/
chmod +x ~/.openclaw/skills/claude-code/scripts/*.sh

# Merge Claude settings (careful - backup first!)
cp ~/.claude/settings.json ~/.claude/settings.json.backup
# Then manually merge claude-settings.json into your settings
```

---

## 6. Configure Environment Variables

The bridge reads your gateway token and port directly from `~/.openclaw/openclaw.json`,
so you don't need to duplicate them. The only thing you may want to set is the Telegram
group ID for targeted notifications.

### Step 6.1: (Optional) Set Telegram Group Target

If you want notifications sent to a specific Telegram group:

```bash
echo 'CC_TELEGRAM_GROUP=-100xxxxxxxxxx' >> ~/.openclaw/.env
```

To find your group ID: send a message in the group, then visit
`https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates` and look for `"chat":{"id":-100...}`.

### Step 6.2: Load Environment

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
# Load OpenClaw environment
if [ -f ~/.openclaw/.env ]; then
    set -a
    source ~/.openclaw/.env
    set +a
fi
```

Reload your shell:
```bash
source ~/.zshrc  # or ~/.bashrc
```

### Step 6.3: Verify Configuration

```bash
# Gateway token should exist in openclaw.json
jq '.gateway.auth.token' ~/.openclaw/openclaw.json

# Telegram should be enabled
jq '.channels.telegram.enabled' ~/.openclaw/openclaw.json
```

---

## 7. Enable OpenClaw Hooks

### Step 7.1: Configure OpenClaw to Accept Hook Calls

OpenClaw should already have hooks enabled from initial setup. Verify:

```bash
jq '.hooks' ~/.openclaw/openclaw.json
```

### Step 7.2: Verify Claude Code Hooks

Check that hooks are registered:

```bash
cat ~/.claude/settings.json | jq '.hooks'
```

You should see entries for:
- `SessionStart`
- `PostToolUse`
- `PostToolUseFailure`
- `Notification`
- `Elicitation`
- `Stop`
- `SessionEnd`

---

## 8. Set Up Forum Topics (Optional)

If you want to run parallel tasks in separate topics:

### Step 8.1: Enable Topics in Your Group

1. Open your Telegram group settings
2. Enable "Topics" feature
3. Create topics for different task categories (or let OpenClaw create them)

### Step 8.2: Get Topic IDs

Send a message in each topic, then check:
```
https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates
```

Look for `message_thread_id` — that's your topic ID.

### Step 8.3: Use Topics When Dispatching

```
cc --topic 42 ~/projects/api build user endpoints
cc --topic 43 ~/projects/web create login page
```

---

## 9. Test the Setup

### Step 9.1: Start OpenClaw

```bash
openclaw start
```

### Step 9.2: Send a Test Task

In your Telegram group, send:

```
cc ~/test-folder create a hello.py that prints hello world
```

### Step 9.3: Expected Flow

1. **OpenClaw receives message** → Parses `cc` command
2. **Dispatch script runs** → Creates task file, spawns Claude Code
3. **You receive**: 
   ```
   🚀 Task started [task-xxx]
   ━━━━━━━━━━━━━━━━━━━━━
   📁 ~/test-folder
   📝 "create a hello.py that prints hello world"
   ━━━━━━━━━━━━━━━━━━━━━
   ```
4. **Progress updates** (if enabled):
   ```
   📄 Created hello.py
   ```
5. **Completion**:
   ```
   ✅ Task completed [task-xxx]
   ━━━━━━━━━━━━━━━━━━━━━
   📁 ~/test-folder
   ⏱️ 45s
   
   📄 Files changed (1):
      + hello.py (new)
   
   📋 Summary:
   Created hello.py with a simple print statement.
   ━━━━━━━━━━━━━━━━━━━━━
   ```

### Step 9.4: Test Questions

Try a task that requires input:

```
cc ~/test-folder create a config file, ask me what settings to include
```

You should receive a question and be able to answer with `/answer`.

---

## 10. Daily Usage

### Starting Your Session

```bash
# Terminal 1: Start OpenClaw
openclaw start

# That's it! Now use Telegram.
```

### Commands Reference

| Command | Description |
|---------|-------------|
| `cc <dir> <task>` | Start a new task |
| `cc --topic <id> <dir> <task>` | Start task in specific topic |
| `/answer <id> <text>` | Answer a question |
| `/cc-status` | List active tasks |
| `/cc-stop <id>` | Stop a task |
| `/cc-config` | Show notification settings |
| `/cc-config quiet` | Minimal notifications |
| `/cc-config verbose` | All notifications |

### Notification Presets

**Quiet Mode** (only completion + errors):
```
/cc-config quiet
```

**Minimal Mode** (start + completion + errors):
```
/cc-config minimal
```

**Verbose Mode** (everything):
```
/cc-config verbose
```

**Custom**:
```
/cc-config set notifications.progress off
/cc-config set notifications.start on
```

---

## 11. Troubleshooting

### Problem: No response from bot

**Check OpenClaw is running:**
```bash
openclaw status
```

**Check logs:**
```bash
openclaw logs --follow
```

**Verify bot token:**
```bash
curl https://api.telegram.org/bot<YOUR_TOKEN>/getMe
```

### Problem: Task starts but no notifications

**Check environment variables are set:**
```bash
echo $OPENCLAW_GATEWAY_URL
echo $OPENCLAW_GATEWAY_TOKEN
echo $CC_TELEGRAM_GROUP
```

**Check hooks are executable:**
```bash
ls -la ~/.claude/hooks/
```

**Test a hook manually:**
```bash
echo '{"session_id":"test","cwd":"/tmp"}' | ~/.claude/hooks/session-start.sh
```

**Check hook logs:**
```bash
tail -f ~/.openclaw/cc-bridge/logs/hooks.log
```

### Problem: Questions time out

**Increase timeout:**
```bash
export CC_ELICITATION_TIMEOUT=600  # 10 minutes
```

**Check answer file is being created:**
```bash
ls ~/.openclaw/cc-bridge/answers/
```

### Problem: Claude Code not spawning

**Check Claude Code works directly:**
```bash
claude --version
claude -p "say hello" --dangerously-skip-permissions
```

**Check dispatch script:**
```bash
~/.openclaw/skills/claude-code/scripts/dispatch.sh --dir ~/test -- "say hello"
```

### Problem: "Permission denied" on hooks

```bash
chmod +x ~/.claude/hooks/*.sh
chmod +x ~/.openclaw/skills/claude-code/scripts/*.sh
```

### Problem: jq errors

**Install jq:**
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Your Phone                              │
│                        (Telegram)                               │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Telegram Servers                           │
└─────────────────────────────┬───────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                        OpenClaw                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │  Telegram   │  │   Gateway   │  │   Claude Code Skill     │ │
│  │  Channel    │◄─┤   :18789    │◄─┤   (dispatch, answer,    │ │
│  │             │  │             │  │    status, config)      │ │
│  └─────────────┘  └──────┬──────┘  └─────────────────────────┘ │
└──────────────────────────┼──────────────────────────────────────┘
                           │ /hooks/wake
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Claude Code                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                       Hooks                              │   │
│  │  session-start.sh ──► "Task started" notification        │   │
│  │  post-tool-use.sh ──► Progress updates                   │   │
│  │  elicitation.sh ────► Questions (waits for answer)       │   │
│  │  session-end.sh ────► Completion summary                 │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              │                                  │
│                              ▼                                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    Your Project                          │   │
│  │                   ~/projects/myapp                       │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

---

## File Locations

| Path | Purpose |
|------|---------|
| `~/.openclaw/config.yaml` | OpenClaw configuration |
| `~/.openclaw/.env` | Environment variables |
| `~/.openclaw/skills/claude-code/` | Bridge skill for OpenClaw |
| `~/.openclaw/cc-bridge/` | Bridge data directory |
| `~/.openclaw/cc-bridge/config.json` | Notification settings |
| `~/.openclaw/cc-bridge/tasks/` | Active task files |
| `~/.openclaw/cc-bridge/questions/` | Pending questions |
| `~/.openclaw/cc-bridge/logs/` | Hook logs |
| `~/.claude/hooks/` | Claude Code hook scripts |
| `~/.claude/settings.json` | Claude Code settings (includes hooks) |

---

## Security Notes

1. **Gateway Token**: Keep `OPENCLAW_GATEWAY_TOKEN` secret — it authenticates hook calls
2. **Telegram User ID**: Only allow your user ID in `allowedUsers`
3. **Skip Permissions**: The bridge uses `--dangerously-skip-permissions` — only dispatch tasks you trust
4. **Local Only**: The gateway runs on `127.0.0.1` by default — not exposed to the internet

---

## Next Steps

- [ ] Set up multiple topics for parallel tasks
- [ ] Customize notification preferences
- [ ] Create shortcuts for common tasks
- [ ] Set up a dedicated dev channel

---

Happy coding! 🚀
