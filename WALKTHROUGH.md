# OpenClaw + Claude Code + Telegram Bridge

## Complete Setup Walkthrough

This guide walks you through setting up a system where you can:
- DM tasks to your OpenClaw bot from Telegram
- Each task auto-creates a forum topic in your group
- Receive progress updates, questions, and completion summaries in the topic
- Answer Claude Code questions remotely
- Run multiple tasks in parallel (each in its own topic)

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Install OpenClaw](#2-install-openclaw)
3. [Create Telegram Bot](#3-create-telegram-bot)
4. [Configure OpenClaw](#4-configure-openclaw)
5. [Install the Bridge](#5-install-the-bridge)
6. [Set Telegram Group](#6-set-telegram-group)
7. [Verify Setup](#7-verify-setup)
8. [Test the Setup](#8-test-the-setup)
9. [Daily Usage](#9-daily-usage)
10. [Troubleshooting](#10-troubleshooting)

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

OpenClaw is the AI gateway that connects Telegram to your local machine.

```bash
# Install globally
npm install -g openclaw

# Verify
openclaw --version
```

---

## 3. Create Telegram Bot

### Step 3.1: Create the Bot

1. Open Telegram and search for `@BotFather`
2. Send `/newbot`
3. Follow prompts to name your bot (e.g., "My Dev Assistant")
4. Save the **API token** (looks like `123456789:ABCdefGHI...`)

### Step 3.2: Create a Group with Topics

This group is where task updates will appear, one topic per task.

1. Create a new Telegram group
2. Open group settings and enable **Topics**
3. Add your bot to the group
4. Make the bot an **admin** (needs permissions to create topics and post)

---

## 4. Configure OpenClaw

### Step 4.1: Run the Configuration Wizard

```bash
openclaw configure
```

This interactive wizard sets up:
- Gateway token (auto-generated)
- Telegram bot token (paste the one from BotFather)
- Allowed users
- Other settings

Everything is saved to `~/.openclaw/openclaw.json`. The bridge reads from this file automatically.

### Step 4.2: Start the Gateway

```bash
openclaw gateway
```

Or to run in the background:

```bash
openclaw gateway --force
```

### Step 4.3: Verify Telegram Connection

Send a message to your bot in Telegram. Check logs to confirm it's received:

```bash
openclaw status
```

---

## 5. Install the Bridge

### One-line install (recommended):

```bash
curl -fsSL https://raw.githubusercontent.com/zzbyy/openclaw-cc-bridge/main/remote-install.sh | bash
```

### Or clone and install manually:

```bash
git clone https://github.com/zzbyy/openclaw-cc-bridge.git
cd openclaw-cc-bridge
./install.sh
```

The installer will:
- Copy hook scripts to `~/.claude/hooks/`
- Register hooks in `~/.claude/settings.json` (idempotent -- safe to re-run)
- Copy the skill to `~/.openclaw/skills/claude-code/`
- Verify your OpenClaw configuration

---

## 6. Set Telegram Group

The bridge needs to know which group to create task topics in.

### Step 6.1: Find Your Group ID

Temporarily stop the gateway so we can read bot updates directly:

```bash
# Stop the gateway (Ctrl+C if running in foreground, or kill the process)
```

Send any message in your Telegram group, then run:

```bash
BOT_TOKEN=$(jq -r '.channels.telegram.botToken' ~/.openclaw/openclaw.json)
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates" | jq '.result[].message.chat | select(.type != "private") | {id, title, type}'
```

You should see something like:

```json
{
  "id": -1001234567890,
  "title": "My Dev Group",
  "type": "supergroup"
}
```

### Step 6.2: Save the Group ID

```bash
echo 'CC_TELEGRAM_GROUP=-1001234567890' >> ~/.openclaw/.env
```

Replace `-1001234567890` with your actual group ID.

### Step 6.3: Load Environment

Add to your shell profile (`~/.zshrc` or `~/.bashrc`):

```bash
# Load OpenClaw environment
if [ -f ~/.openclaw/.env ]; then
    set -a
    source ~/.openclaw/.env
    set +a
fi
```

Then reload:

```bash
source ~/.zshrc  # or ~/.bashrc
```

---

## 7. Verify Setup

### Step 7.1: Check OpenClaw Config

```bash
# Gateway token should exist
jq '.gateway.auth.token' ~/.openclaw/openclaw.json
```

You should see a token string (not `null`).

```bash
# Telegram should be enabled
jq '.channels.telegram.enabled' ~/.openclaw/openclaw.json
```

Should return `true`.

```bash
# Hooks should be enabled
jq '.hooks' ~/.openclaw/openclaw.json
```

You should see:

```json
{
  "internal": {
    "enabled": true,
    "entries": {
      "command-logger": {
        "enabled": true
      },
      "session-memory": {
        "enabled": true
      }
    }
  }
}
```

If missing, run `openclaw configure`.

### Step 7.2: Check Claude Code Hooks

```bash
jq '.hooks | keys' ~/.claude/settings.json
```

Should include:
```json
["Elicitation", "Notification", "PostToolUse", "PostToolUseFailure", "SessionEnd", "SessionStart", "Stop"]
```

### Step 7.3: Check Group ID

```bash
echo $CC_TELEGRAM_GROUP
```

Should print your group ID (e.g., `-1001234567890`).

---

## 8. Test the Setup

### Step 8.1: Start the Gateway

```bash
openclaw gateway --force
```

### Step 8.2: Send a Test Task

DM your bot in Telegram:

```
cc ~/test-folder create a hello.py that prints hello world
```

### Step 8.3: Expected Flow

1. **Bot confirms in DM** -- task started with ID
2. **Forum topic created** in your group (e.g., `[a1b2] create a hello.py...`)
3. **Progress updates** appear in the topic:
   ```
   🚀 Task started [task-xxx]
   ━━━━━━━━━━━━━━━━━━━━━
   📁 ~/test-folder
   📝 "create a hello.py that prints hello world"
   ━━━━━━━━━━━━━━━━━━━━━
   ```
4. **Completion** posted to the same topic:
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

### Step 8.4: Test Questions

Try a task that requires input:

```
cc ~/test-folder create a config file, ask me what settings to include
```

You should receive a question in the topic and be able to answer with `/answer`.

---

## 9. Daily Usage

### Starting Your Session

```bash
# Start the gateway (if not already running)
openclaw gateway --force

# That's it! Now DM tasks to your bot.
```

### Commands Reference

| Command | Description |
|---------|-------------|
| `cc <dir> <task>` | Start a task (auto-creates topic) |
| `cc --topic <id> <dir> <task>` | Start task in a specific topic |
| `/answer <id> <text>` | Answer a question |
| `/cc-status` | List active tasks |
| `/cc-stop <id>` | Stop a task |
| `/cc-config` | Show notification settings |
| `/cc-config quiet` | Only completion & errors |
| `/cc-config minimal` | Start + completion + errors |
| `/cc-config verbose` | All notifications |

### Notification Presets

```
/cc-config quiet      -- Only completion + errors
/cc-config minimal    -- Start + completion + errors
/cc-config verbose    -- Everything
```

Custom:
```
/cc-config set notifications.progress off
/cc-config set notifications.start on
```

---

## 10. Troubleshooting

### Problem: No response from bot

**Check gateway is running:**
```bash
openclaw status
```

**Restart gateway:**
```bash
openclaw gateway --force
```

### Problem: Task starts but no topic created

**Check CC_TELEGRAM_GROUP is set:**
```bash
echo $CC_TELEGRAM_GROUP
```

**Check bot is admin in the group** (needs permission to create topics).

**Check hook logs:**
```bash
tail -f ~/.openclaw/cc-bridge/logs/hooks.log
```

### Problem: Task starts but no notifications

**Check hooks are executable:**
```bash
ls -la ~/.claude/hooks/
```

**Test a hook manually:**
```bash
echo '{"session_id":"test","cwd":"/tmp"}' | ~/.claude/hooks/session-start.sh
```

### Problem: Questions time out

**Increase timeout:**
```bash
echo 'CC_ELICITATION_TIMEOUT=600' >> ~/.openclaw/.env
source ~/.zshrc
```

### Problem: Claude Code not spawning

**Check Claude Code works directly:**
```bash
claude --version
claude -p "say hello" --dangerously-skip-permissions
```

### Problem: "Permission denied" on hooks

```bash
chmod +x ~/.claude/hooks/*.sh
chmod +x ~/.openclaw/skills/claude-code/scripts/*.sh
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                   Your Phone (Telegram)                         │
│                                                                 │
│  DM to bot:                    Group (with Topics):             │
│  "cc ~/proj implement auth"    [a1b2] implement auth...         │
│                                  ├─ 🚀 Task started            │
│                                  ├─ 📄 Created auth.py         │
│                                  ├─ 🤔 Question: JWT or...?    │
│                                  └─ ✅ Task completed           │
└────────────────┬──────────────────────────┬─────────────────────┘
                 │                          ▲
                 ▼                          │
┌─────────────────────────────────────────────────────────────────┐
│                        OpenClaw Gateway                         │
│  ┌──────────────┐  ┌────────────┐  ┌──────────────────────────┐│
│  │  Telegram     │  │  Gateway   │  │  Claude Code Skill       ││
│  │  Channel      │  │  :18789    │  │  (dispatch, answer,      ││
│  │              ◄├──┤            │◄─┤   status, config)        ││
│  └──────────────┘  └─────┬──────┘  └──────────────────────────┘│
└───────────────────────────┼─────────────────────────────────────┘
                            │ /hooks/wake
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      Claude Code + Hooks                        │
│                                                                 │
│  session-start.sh ──► "Task started" → group topic              │
│  post-tool-use.sh ──► Progress updates → group topic            │
│  elicitation.sh   ──► Questions → group topic (waits for answer)│
│  session-end.sh   ──► Completion summary → group topic          │
│                              │                                  │
│                              ▼                                  │
│                      Your Project                               │
│                     ~/projects/myapp                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## File Locations

| Path | Purpose |
|------|---------|
| `~/.openclaw/openclaw.json` | OpenClaw config (gateway token, telegram, etc.) |
| `~/.openclaw/.env` | Optional overrides (`CC_TELEGRAM_GROUP`, etc.) |
| `~/.openclaw/skills/claude-code/` | Bridge skill for OpenClaw |
| `~/.openclaw/cc-bridge/` | Bridge data directory |
| `~/.openclaw/cc-bridge/config.json` | Notification settings |
| `~/.openclaw/cc-bridge/tasks/` | Active task files |
| `~/.openclaw/cc-bridge/questions/` | Pending questions |
| `~/.openclaw/cc-bridge/logs/` | Hook logs |
| `~/.claude/hooks/` | Claude Code hook scripts |
| `~/.claude/settings.json` | Claude Code settings (hooks registered here) |

---

## Security Notes

1. **Gateway Token**: Stored in `openclaw.json`, authenticates hook calls -- keep it secret
2. **Telegram User ID**: Only allow your user ID in the OpenClaw config
3. **Skip Permissions**: The bridge uses `--dangerously-skip-permissions` -- only dispatch tasks you trust
4. **Local Only**: The gateway runs on `127.0.0.1` by default -- not exposed to the internet

---

## Updating

Re-run the same install command:

```bash
curl -fsSL https://raw.githubusercontent.com/zzbyy/openclaw-cc-bridge/main/remote-install.sh | bash
```

The installer is idempotent -- replaces old bridge hooks without duplicating, preserves your other hooks.
