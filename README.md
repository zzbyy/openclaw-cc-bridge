# OpenClaw + Claude Code + Telegram Bridge

Control Claude Code remotely via Telegram. Dispatch tasks, receive updates, answer questions — all from your phone.

## Features

- 🚀 **Dispatch tasks** from Telegram → Claude Code runs in background
- 📊 **Progress updates** as files are created, tests run, etc.
- 🤔 **Interactive Q&A** — Claude Code questions forwarded to you
- ✅ **Completion summaries** with files changed and results
- 🔀 **Parallel tasks** in separate forum topics
- ⚙️ **Configurable notifications** — quiet, minimal, or verbose

## Quick Start

```bash
# One-line install
curl -fsSL https://raw.githubusercontent.com/zzbyy/openclaw-cc-bridge/main/remote-install.sh | bash

# (Optional) Set Telegram group for targeted notifications
echo 'CC_TELEGRAM_GROUP=-100xxxxxxxxxx' >> ~/.openclaw/.env

# Start
openclaw start

# Test (send in Telegram)
cc ~/test-folder create a hello.py that prints hello world
```

**📖 See [WALKTHROUGH.md](WALKTHROUGH.md) for complete step-by-step setup instructions.**

## Commands

| Command | Description |
|---------|-------------|
| `cc <dir> <task>` | Start a task |
| `cc --topic <id> <dir> <task>` | Start task in forum topic |
| `/answer <id> <text>` | Answer a question |
| `/cc-status` | List active tasks |
| `/cc-stop <id>` | Stop a task |
| `/cc-config` | Show notification settings |
| `/cc-config quiet` | Only completion & errors |
| `/cc-config verbose` | All notifications |

## What You'll See

**Task started:**
```
🚀 Task started [task-abc123]
━━━━━━━━━━━━━━━━━━━━━
📁 ~/projects/myapp
📝 "implement user auth"
━━━━━━━━━━━━━━━━━━━━━
```

**Progress:**
```
📄 Created auth.py
📦 pip install bcrypt
🧪 Running tests...
```

**Question:**
```
🤔 Claude Code Question
━━━━━━━━━━━━━━━━━━━━━
Should I use JWT or sessions?
━━━━━━━━━━━━━━━━━━━━━
Reply: /answer q-xxx <your answer>
```

**Completed:**
```
✅ Task completed [task-abc123]
━━━━━━━━━━━━━━━━━━━━━
📁 ~/projects/myapp
⏱️ 5m 23s

📄 Files changed (4):
   + auth.py (new)
   + middleware.py (new)
   ~ app.py (modified)
   + tests/test_auth.py (new)

📋 Summary:
Implemented JWT authentication with login/logout.
All tests passing.
━━━━━━━━━━━━━━━━━━━━━
```

## Architecture

```
Phone (Telegram) → OpenClaw → Claude Code → Your Project
                      ↑            │
                      └── hooks ───┘
```

## Files

```
~/.openclaw/
├── openclaw.json            # OpenClaw config (gateway token, telegram, etc.)
├── .env                     # Optional overrides (CC_TELEGRAM_GROUP, etc.)
├── skills/claude-code/      # The skill that handles cc commands
└── cc-bridge/               # Bridge data
    ├── config.json          # Notification settings
    ├── tasks/               # Active tasks
    ├── questions/           # Pending questions
    └── logs/                # Hook logs

~/.claude/
├── settings.json            # Claude Code settings (hooks registered here)
└── hooks/                   # Hook scripts
    ├── hook-utils.sh        # Shared utilities (sourced by all hooks)
    ├── session-start.sh     # Task started notification
    ├── post-tool-use.sh     # Progress tracking (files, commands, tests)
    ├── post-tool-use-failure.sh  # Error tracking
    ├── notification.sh      # Idle/permission notifications
    ├── elicitation.sh       # Question forwarding (blocking)
    ├── stop.sh              # Milestone progress pings
    └── session-end.sh       # Completion summary
```

## Troubleshooting

**No response from bot?**
```bash
openclaw status
openclaw logs --follow
```

**Hooks not firing?**
```bash
cat ~/.claude/settings.json | jq '.hooks'
ls -la ~/.claude/hooks/
```

**Questions timing out?**
```bash
export CC_ELICITATION_TIMEOUT=600
tail -f ~/.openclaw/cc-bridge/logs/hooks.log
```

## Updating

Re-run the installer — it's idempotent (replaces old bridge hooks, preserves your other hooks):

```bash
curl -fsSL https://raw.githubusercontent.com/zzbyy/openclaw-cc-bridge/main/remote-install.sh | bash
```

## Security

- Tasks use `--dangerously-skip-permissions` — dispatch only trusted tasks
- Keep `OPENCLAW_GATEWAY_TOKEN` secret
- Gateway runs on localhost only by default
