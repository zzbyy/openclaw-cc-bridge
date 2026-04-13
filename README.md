# OpenClaw + Claude Code + Telegram Bridge

Control Claude Code remotely via Telegram. Two modes: fire-and-forget for simple tasks, live interactive sessions for complex work.

## Two Modes

### /cc -- Fire and Forget
Send a task, Claude Code runs in the background, get progress and completion notifications.
Best for: clear tasks that don't need discussion.

```
/cc ~/myapp implement JWT auth with login and registration
```

### /cc-live -- Interactive Session
Open a persistent Claude Code session. Discuss, plan, iterate -- Claude Code responds directly in the conversation.
Best for: complex tasks, planning, code review, anything that needs back-and-forth.

```
/cc-live ~/myapp build a REST API, ask me about the tech stack first
```

Both work in DM chats or group topics.

## Quick Start

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/zzbyy/openclaw-cc-bridge/main/remote-install.sh | bash

# Restart gateway
openclaw gateway restart

# Test in Telegram
/cc ~/test-folder create a hello.py that prints hello world
```

See [WALKTHROUGH.md](WALKTHROUGH.md) for complete setup.

## Commands

| Command | Description |
|---------|-------------|
| `/cc <dir> <task>` | Fire-and-forget task |
| `/cc-live <dir> <task>` | Start interactive live session |
| `/cc-live stop` | End live session |
| `/answer <id> <text>` | Answer a question (/cc mode) |
| `/cc-status` | List active tasks |
| `/cc-stop <id>` | Stop a /cc task |
| `/cc-config` | Show notification settings |
| `/cc-config quiet\|minimal\|verbose` | Apply preset |

## /cc Notifications

**Start:**
```
🚀 Task started [task-abc123]
━━━━━━━━━━━━━━━━━━━━━
📁 ~/myapp
📝 "implement JWT auth"
━━━━━━━━━━━━━━━━━━━━━
```

**Progress:**
```
[CC-PROGRESS] [task-abc123] 📄 Created auth.py
[CC-PROGRESS] [task-abc123] 📦 pip install bcrypt
[CC-PROGRESS] [task-abc123] ✓ Ran: python3 test_auth.py (10 steps)
```

**Completion:**
```
✅ Task completed [task-abc123]
━━━━━━━━━━━━━━━━━━━━━
📁 ~/myapp
⏱️ 2m 15s

📄 Files changed (3):
   + auth.py (new)
   + requirements.txt (new)
   ~ app.py (modified)

📋 Summary:
Implemented JWT auth with register and login endpoints.

💰 ~10k tokens (est.)
━━━━━━━━━━━━━━━━━━━━━
```

## /cc-live Example

```
You:           /cc-live ~/myapp build a REST API, ask me about the stack
Claw:          🔴 Live session started.

[Claude Code]  What framework? FastAPI, Flask, Django REST?
               And database — SQLite, PostgreSQL, MongoDB?

You:           FastAPI with SQLite
[Claude Code]  Got it. Building...
               [creates files, installs deps, runs tests]
               Done! 3 endpoints: POST /register, POST /login, GET /me

You:           add rate limiting to the login endpoint
[Claude Code]  Added slowapi rate limiter — 5 attempts per minute per IP.

You:           /cc-live stop
Claw:          ⏹️ Live session ended.
```

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  Telegram (DM or group topic)                                │
│                                                              │
│  /cc mode:      send task → get notifications back           │
│  /cc-live mode: open live session → talk to Claude Code      │
└───────────────────────┬──────────────────────────────────────┘
                        │
                        ▼
┌──────────────────────────────────────────────────────────────┐
│  OpenClaw Gateway                                            │
│                                                              │
│  /cc      → cc skill → dispatch.sh → Claude Code (-p mode)  │
│              hooks send notifications back to topic           │
│                                                              │
│  /cc-live → cc skill → acpx CLI → Claude Code (ACP session) │
│              responses flow directly through conversation     │
└──────────────────────────────────────────────────────────────┘
```

## Files

```
~/.agents/skills/cc/         # Skill (SKILL.md, CLAUDE.md, scripts/)

~/.openclaw/
├── openclaw.json            # Gateway token, Telegram config
├── .env                     # CC_TELEGRAM_GROUP, optional overrides
└── cc-bridge/               # /cc mode bridge data
    ├── config.json          # Notification settings
    ├── tasks/               # Active task files
    └── logs/                # Hook logs

~/.claude/
├── settings.json            # Hook registrations
└── hooks/                   # /cc mode hook scripts
    ├── hook-utils.sh        # Shared utilities
    ├── session-start.sh     # Start notification
    ├── post-tool-use.sh     # Progress tracking
    ├── elicitation.sh       # Question forwarding
    └── session-end.sh       # Completion summary
```

## Troubleshooting

**No response from bot?**
```bash
openclaw status
openclaw gateway restart
```

**Hooks not firing? (/cc mode)**
```bash
jq '.hooks | keys' ~/.claude/settings.json
ls -la ~/.claude/hooks/
tail -f ~/.openclaw/cc-bridge/logs/hooks.log
```

**Permission denied on hooks?**
```bash
chmod +x ~/.claude/hooks/*.sh
chmod +x ~/.agents/skills/cc/scripts/*.sh
```

## Updating

```bash
curl -fsSL https://raw.githubusercontent.com/zzbyy/openclaw-cc-bridge/main/remote-install.sh | bash
```

Idempotent -- replaces old hooks, preserves your other hooks.

## Security

- `/cc` uses `--dangerously-skip-permissions` -- dispatch only trusted tasks
- `/cc-live` uses `--approve-all` -- auto-approves all permission requests
- Gateway token is read from `openclaw.json` -- keep it secret
- Gateway runs on localhost only by default
