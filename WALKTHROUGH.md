# OpenClaw + Claude Code + Telegram Bridge

## Complete Setup Walkthrough

This guide walks you through setting up the bridge so you can:
- Send coding tasks to Claude Code from Telegram
- Receive progress updates, questions, and completion summaries
- Answer Claude Code questions remotely
- Work in DM chats or group topics

**Prerequisites:** [Claude Code](https://docs.anthropic.com/claude-code) and [OpenClaw](https://docs.openclaw.ai) should already be installed and configured with Telegram.

---

## Table of Contents

1. [Set Up Telegram](#1-set-up-telegram)
2. [Install the Bridge](#2-install-the-bridge)
3. [Configure Notifications](#3-configure-notifications)
4. [Verify Setup](#4-verify-setup)
5. [Test](#5-test)
6. [Daily Usage](#6-daily-usage)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. Set Up Telegram

The bridge works in two modes. Choose one or both:

### Option A: DM Chat (simplest)

Message your OpenClaw bot directly. All notifications come back in the same DM.

**Setup:** Nothing extra needed -- just DM your bot. Make sure your Telegram user ID is in OpenClaw's allowed users (`openclaw configure`).

### Option B: Group with Topics (organized)

Each task gets its own forum topic. Great for tracking parallel tasks.

**Setup:**

1. Create a new Telegram group
2. Open group settings and enable **Topics**
3. Add your bot to the group
4. Make the bot an **admin** (needs permissions to post and manage topics)
5. Find your group ID:

```bash
# Temporarily stop the gateway so we can read bot updates directly
# Send any message in your group, then run:
BOT_TOKEN=$(jq -r '.channels.telegram.botToken' ~/.openclaw/openclaw.json)
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates" \
  | jq '.result[].message.chat | select(.type != "private") | {id, title, type}'
```

You should see:
```json
{
  "id": -1001234567890,
  "title": "My Dev Group",
  "type": "supergroup"
}
```

6. Save the group ID:
```bash
echo 'CC_TELEGRAM_GROUP=-1001234567890' >> ~/.openclaw/.env
```

7. Load environment -- add to your shell profile (`~/.zshrc` or `~/.bashrc`):
```bash
if [ -f ~/.openclaw/.env ]; then
    set -a
    source ~/.openclaw/.env
    set +a
fi
```

Then reload: `source ~/.zshrc`

---

## 2. Install the Bridge

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
- Copy the skill to `~/.agents/skills/cc/` (OpenClaw personal skills dir)
- Verify your OpenClaw configuration

---

## 3. Configure Notifications

Notification preferences are optional. Defaults send everything.

```
/cc-config quiet      -- Only completion + errors
/cc-config minimal    -- Start + completion + errors
/cc-config verbose    -- Everything (default)
```

Fine-grained control:
```
/cc-config set notifications.progress off
/cc-config set notifications.start on
/cc-config set progress_filter.file_created off
```

---

## 4. Verify Setup

### Check Claude Code Hooks

```bash
jq '.hooks | keys' ~/.claude/settings.json
```

Should include: `SessionStart`, `PostToolUse`, `Elicitation`, `SessionEnd`, etc.

### Check Skill

```bash
openclaw skills info cc
```

Should show `✓ Ready`.

### Check Group ID (if using group mode)

```bash
echo $CC_TELEGRAM_GROUP
```

---

## 5. Test

Restart the gateway to pick up changes:

```bash
openclaw gateway restart
```

Start a new session in Telegram (`/new`), then send a task:

**In DM:**
```
/cc ~/test-folder create a hello.py that prints hello world
```

**In a group topic:**
Create a topic, then send the same command in that topic.

### Expected Flow

1. **Bot confirms** -- task dispatched with ID
2. **Start notification:**
   ```
   🚀 Task started [task-xxx]
   ━━━━━━━━━━━━━━━━━━━━━
   📁 ~/test-folder
   📝 "create a hello.py that prints hello world"
   ━━━━━━━━━━━━━━━━━━━━━
   ```
3. **Progress updates:**
   ```
   [CC-PROGRESS] [task-xxx] 📄 Created hello.py
   ```
4. **Completion:**
   ```
   ✅ Task completed [task-xxx]
   ━━━━━━━━━━━━━━━━━━━━━
   📁 ~/test-folder
   ⏱️ 45s

   📄 Files changed (1):
      + hello.py (new)

   📋 Summary:
   Created hello.py with a simple print statement.

   💰 ~5k tokens (est.)
   ━━━━━━━━━━━━━━━━━━━━━
   ```

---

## 6. Daily Usage

### Commands Reference

| Command | Description |
|---------|-------------|
| `/cc <dir> <task>` | Fire-and-forget task |
| `/cc-live <dir> <task>` | Start interactive live session |
| `/cc-live stop` | End live session |
| `/answer <id> <text>` | Answer a question (fire-and-forget mode) |
| `/cc-status` | List active tasks |
| `/cc-status <id>` | Get task details |
| `/cc-stop <id>` | Stop a fire-and-forget task |
| `/cc-config` | Show notification settings |
| `/cc-config quiet\|minimal\|verbose` | Apply preset |
| `/cc-config set <key> <on\|off>` | Toggle a setting |

### When to use which

- **`/cc`** -- simple, well-defined tasks Claude Code can handle without questions
- **`/cc-live`** -- complex tasks where you want to discuss, plan, review, or iterate with Claude Code

---

## 7. Troubleshooting

### No response from bot

```bash
openclaw status
openclaw gateway restart
```

### Task starts but no notifications

Check hooks are executable:
```bash
ls -la ~/.claude/hooks/
```

Check hook logs:
```bash
tail -f ~/.openclaw/cc-bridge/logs/hooks.log
```

### Questions time out

```bash
echo 'CC_ELICITATION_TIMEOUT=600' >> ~/.openclaw/.env
source ~/.zshrc
```

### "Permission denied" on hooks

```bash
chmod +x ~/.claude/hooks/*.sh
chmod +x ~/.agents/skills/cc/scripts/*.sh
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Telegram                                   │
│  DM or Group Topic ──► send /cc task                        │
│                    ◄── receive notifications                 │
└──────────────┬──────────────────────────┬───────────────────┘
               │                          ▲
               ▼                          │
┌──────────────────────────────────────────────────────────────┐
│  OpenClaw Gateway (:18789)                                   │
│  CC Skill → dispatch.sh → spawns Claude Code in background   │
└──────────────────────────────┬───────────────────────────────┘
                               │
                               ▼
┌──────────────────────────────────────────────────────────────┐
│  Claude Code + Hooks                                         │
│  session-start.sh → 🚀 Task started notification             │
│  post-tool-use.sh → 📄 Progress updates                     │
│  elicitation.sh   → 🤔 Questions (waits for /answer)        │
│  session-end.sh   → ✅ Completion summary                    │
│                          │                                   │
│                          ▼                                   │
│                   Your Project ~/myapp                       │
└──────────────────────────────────────────────────────────────┘
```

---

## Updating

Re-run the same install command:

```bash
curl -fsSL https://raw.githubusercontent.com/zzbyy/openclaw-cc-bridge/main/remote-install.sh | bash
```

The installer is idempotent -- replaces old bridge hooks without duplicating, preserves your other hooks.

---

## Security

- Tasks use `--dangerously-skip-permissions` -- only dispatch tasks you trust
- Gateway token is read from `openclaw.json` -- keep it secret
- Gateway runs on `127.0.0.1` by default -- not exposed to the internet
