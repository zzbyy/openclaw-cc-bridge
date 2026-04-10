# OpenClaw + Claude Code + Telegram Bridge

Control Claude Code remotely via Telegram. DM tasks to your bot, get updates in organized forum topics.

## How It Works

```
You (DM) ──► OpenClaw bot ──► Claude Code runs in background
                  │                     │
                  │              hooks fire on events
                  │                     │
                  └──── Group topic ◄───┘
                    (progress, questions, completion)
```

1. DM your bot: `cc ~/project implement auth`
2. A forum topic is auto-created in your group
3. Progress, questions, and completion go to that topic
4. Each task gets its own topic -- parallel tasks stay organized

## Quick Start

```bash
# One-line install
curl -fsSL https://raw.githubusercontent.com/zzbyy/openclaw-cc-bridge/main/remote-install.sh | bash

# Set your Telegram group for task topics
echo 'CC_TELEGRAM_GROUP=-100xxxxxxxxxx' >> ~/.openclaw/.env

# Restart the gateway
openclaw gateway --force

# DM your bot in Telegram
cc ~/test-folder create a hello.py that prints hello world
```

See [WALKTHROUGH.md](WALKTHROUGH.md) for complete step-by-step setup.

## Commands

| Command | Description |
|---------|-------------|
| `cc <dir> <task>` | Start a task (auto-creates forum topic) |
| `cc --topic <id> <dir> <task>` | Start task in a specific topic |
| `/answer <id> <text>` | Answer a question |
| `/cc-status` | List active tasks |
| `/cc-stop <id>` | Stop a task |
| `/cc-config` | Show notification settings |
| `/cc-config quiet` | Only completion & errors |
| `/cc-config verbose` | All notifications |

## What You'll See

**In your DM** (confirmation):
```
Task started! ID: task-abc123
Running in ~/projects/myapp
Updates in group topic.
```

**In the group topic** (progress):
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
