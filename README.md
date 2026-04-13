# OpenClaw + Claude Code + Telegram Bridge

Control Claude Code remotely via Telegram. Send tasks in a DM or group topic, get progress and results right there.

## How It Works

```
Telegram (DM or group topic)
     │
     ▼
OpenClaw bot ──► Claude Code runs in background
     ▲                     │
     │              hooks fire on events
     │                     │
     └── notifications ◄───┘
   (progress, questions, completion)
```

**Two modes:**

- **`/cc` (fire-and-forget)** -- send a task, Claude Code runs in background, get notifications when done
- **`/cc-live` (interactive)** -- open a live Claude Code session in a topic, discuss and iterate directly

Works in DM or group topics.

## Quick Start

```bash
# One-line install
curl -fsSL https://raw.githubusercontent.com/zzbyy/openclaw-cc-bridge/main/remote-install.sh | bash

# Restart the gateway
openclaw gateway restart

# Send to your bot in Telegram (DM or group topic):
/cc ~/test-folder create a hello.py that prints hello world
```

See [WALKTHROUGH.md](WALKTHROUGH.md) for complete step-by-step setup.

## Commands

| Command | Description |
|---------|-------------|
| `/cc <dir> <task>` | Fire-and-forget task |
| `/cc-live <dir> <task>` | Start interactive live session |
| `/cc-live stop` | End live session |
| `/answer <id> <text>` | Answer a question (fire-and-forget mode) |
| `/cc-status` | List active tasks |
| `/cc-stop <id>` | Stop a fire-and-forget task |
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
[CC-PROGRESS] [task-abc123] 📄 Created auth.py
[CC-PROGRESS] [task-abc123] 📦 pip install bcrypt
[CC-PROGRESS] [task-abc123] 🧪 Running tests...
[CC-PROGRESS] [task-abc123] ✓ Ran: python3 test_auth.py (10 steps)
```

**Question:**
```
🤔 Claude Code Question
━━━━━━━━━━━━━━━━━━━━━
Should I use JWT or sessions?
━━━━━━━━━━━━━━━━━━━━━
Reply: /answer q-xxx <your answer>
```

**Completion:**
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

💰 ~10k tokens (est.)
━━━━━━━━━━━━━━━━━━━━━
```

## /cc-live Example

```
You:          /cc-live ~/project build a REST API, ask me what framework to use
Claw:         🔴 Live session started in ~/project.
[Claude Code]: What framework? FastAPI, Flask, Django REST, or something else?

You:          FastAPI with SQLite
[Claude Code]: Got it. Building FastAPI auth API with SQLite...
              [creates files, runs tests]
              Done! 3 endpoints: POST /register, POST /login, GET /me

You:          /cc-live stop
Claw:         ⏹️ Live session ended.
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
openclaw gateway restart
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
