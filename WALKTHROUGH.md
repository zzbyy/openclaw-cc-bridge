# OpenClaw + Claude Code + Telegram Bridge

## Setup Walkthrough

**Prerequisites:** [Claude Code](https://docs.anthropic.com/claude-code) and [OpenClaw](https://docs.openclaw.ai) already installed and configured with Telegram.

---

## 1. Set Up Telegram

### Option A: DM Chat (simplest)

Message your OpenClaw bot directly. No extra setup needed.

### Option B: Group with Topics (organized)

Great for tracking parallel tasks -- each task gets its own topic.

1. Create a Telegram group and enable **Topics** in settings
2. Add your bot and make it **admin**
3. Find your group ID:

```bash
# Send a message in the group, then:
BOT_TOKEN=$(jq -r '.channels.telegram.botToken' ~/.openclaw/openclaw.json)
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates" \
  | jq '.result[].message.chat | select(.type != "private") | {id, title, type}'
```

4. Save the group ID:
```bash
echo 'CC_TELEGRAM_GROUP=-1001234567890' >> ~/.openclaw/.env
```

5. Add to your shell profile (`~/.zshrc` or `~/.bashrc`):
```bash
if [ -f ~/.openclaw/.env ]; then
    set -a; source ~/.openclaw/.env; set +a
fi
```

---

## 2. Install the Bridge

```bash
curl -fsSL https://raw.githubusercontent.com/zzbyy/openclaw-cc-bridge/main/remote-install.sh | bash
```

This installs:
- Hook scripts to `~/.claude/hooks/`
- Hook config to `~/.claude/settings.json`
- Skill to `~/.agents/skills/cc/`

---

## 3. Verify

```bash
# Skill should show Ready
openclaw skills info cc

# Hooks should be registered
jq '.hooks | keys' ~/.claude/settings.json
```

---

## 4. Test

```bash
openclaw gateway restart
```

### Test /cc (fire-and-forget)

Send in Telegram (DM or group topic):
```
/cc ~/test-folder create a hello.py that prints hello world
```

Expected: start notification, progress, completion summary -- all in the same conversation.

### Test /cc-live (interactive)

```
/cc-live ~/test-folder build a snake game with pygame, ask me about board size and colors
```

Expected: Claude Code asks questions, you answer naturally, it builds the game.

End with:
```
/cc-live stop
```

---

## 5. Daily Usage

### When to use which

| Mode | Best for | How it works |
|------|----------|--------------|
| `/cc` | Simple, well-defined tasks | Fire-and-forget. Notifications come back when done. |
| `/cc-live` | Complex tasks, planning, review | Interactive session. You talk directly to Claude Code. |

### Commands

| Command | Description |
|---------|-------------|
| `/cc <dir> <task>` | Fire-and-forget task |
| `/cc-live <dir> <task>` | Start interactive live session |
| `/cc-live stop` | End live session |
| `/answer <id> <text>` | Answer a question (/cc mode) |
| `/cc-status` | List active tasks |
| `/cc-stop <id>` | Stop a /cc task |
| `/cc-config quiet\|minimal\|verbose` | Notification preset |

### /cc Notification Presets

```
/cc-config quiet      -- Only completion + errors
/cc-config minimal    -- Start + completion + errors
/cc-config verbose    -- Everything (default)
```

---

## 6. Troubleshooting

**No response from bot?**
```bash
openclaw status
openclaw gateway restart
```

**Hooks not firing?**
```bash
ls -la ~/.claude/hooks/
tail -f ~/.openclaw/cc-bridge/logs/hooks.log
```

**Permission denied on hooks?**
```bash
chmod +x ~/.claude/hooks/*.sh
chmod +x ~/.agents/skills/cc/scripts/*.sh
```

---

## 7. Architecture

```
/cc (fire-and-forget):
  Telegram → OpenClaw → dispatch.sh → Claude Code (-p mode)
       ↑                                    │
       └──── hooks send notifications ──────┘

/cc-live (interactive):
  Telegram → OpenClaw → acpx CLI → Claude Code (ACP session)
       ↑                                    │
       └──── responses flow directly ───────┘
```

**`/cc` mode** uses Claude Code hooks (shell scripts in `~/.claude/hooks/`) to track progress and send notifications via `openclaw message send`.

**`/cc-live` mode** uses OpenClaw's ACP system (`acpx` CLI) to create a persistent Claude Code session. Responses flow directly through the conversation -- no hooks needed.

---

## 8. Updating

```bash
curl -fsSL https://raw.githubusercontent.com/zzbyy/openclaw-cc-bridge/main/remote-install.sh | bash
```

Idempotent -- safe to re-run.

---

## 9. Security

- `/cc` uses `--dangerously-skip-permissions` -- dispatch only trusted tasks
- `/cc-live` uses `--approve-all` -- auto-approves all permission requests
- Gateway token read from `openclaw.json` -- keep it secret
- Gateway runs on localhost only
