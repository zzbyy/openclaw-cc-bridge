# OpenClaw + Claude Code + Telegram Bridge

Control Claude Code remotely via Telegram. Send tasks in a group topic, get progress and results right there.

## How It Works

```
Group topic ──► OpenClaw bot ──► Claude Code runs in background
     ▲                                   │
     │                            hooks fire on events
     │                                   │
     └───────── notifications ◄──────────┘
        (progress, questions, completion)
```

1. Create a topic in your Telegram group for the task
2. Send `/cc ~/project implement auth` in that topic
3. Claude Code runs in background
4. Progress, questions, and completion come back to the same topic

## Quick Start

```bash
# One-line install
curl -fsSL https://raw.githubusercontent.com/zzbyy/openclaw-cc-bridge/main/remote-install.sh | bash

# Set your Telegram group
echo 'CC_TELEGRAM_GROUP=-100xxxxxxxxxx' >> ~/.openclaw/.env

# Restart the gateway
openclaw gateway --force

# In a Telegram group topic, send:
/cc ~/test-folder create a hello.py that prints hello world
```

See [WALKTHROUGH.md](WALKTHROUGH.md) for complete step-by-step setup.

## Commands

| Command | Description |
|---------|-------------|
| `/cc <dir> <task>` | Start a task in the current topic |
| `/answer <id> <text>` | Answer a question |
| `/cc-status` | List active tasks |
| `/cc-stop <id>` | Stop a task |
| `/cc-config` | Show notification settings |
| `/cc-config quiet` | Only completion & errors |
| `/cc-config verbose` | All notifications |

## What You'll See

**In your topic** (progress):
```
🚀 Task started [task-abc123]
━━━━━━━━━━━━━━━━━━━━━
📁 ~/projects/myapp
📝 "implement user auth"
━━━━━━━━━━━━━━━━━━━━━
```

```
📄 Created auth.py
📦 pip install bcrypt
🧪 Running tests...
```

**Question** (in topic):
```
🤔 Claude Code Question
━━━━━━━━━━━━━━━━━━━━━
Should I use JWT or sessions?
━━━━━━━━━━━━━━━━━━━━━
Reply: /answer q-xxx <your answer>
```

**Completion** (in topic):
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

## Files

```
~/.agents/skills/cc/ # The skill (SKILL.md, CLAUDE.md, scripts/)

~/.openclaw/
├── openclaw.json            # OpenClaw config (gateway token, telegram, etc.)
├── .env                     # Optional overrides (CC_TELEGRAM_GROUP, etc.)
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
openclaw gateway --force  # restart the gateway
```

**Hooks not firing?**
```bash
jq '.hooks' ~/.claude/settings.json
ls -la ~/.claude/hooks/
```

**Questions timing out?**
```bash
echo 'CC_ELICITATION_TIMEOUT=600' >> ~/.openclaw/.env
tail -f ~/.openclaw/cc-bridge/logs/hooks.log
```

## Updating

Re-run the installer -- it's idempotent (replaces old bridge hooks, preserves your other hooks):

```bash
curl -fsSL https://raw.githubusercontent.com/zzbyy/openclaw-cc-bridge/main/remote-install.sh | bash
```

## Security

- Tasks use `--dangerously-skip-permissions` -- dispatch only trusted tasks
- Gateway token is read from `openclaw.json` -- keep it secret
- Gateway runs on localhost only by default
