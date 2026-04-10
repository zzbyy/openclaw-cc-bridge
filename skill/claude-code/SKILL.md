---
name: cc
description: 'Dispatch Claude Code tasks with bridge tracking, auto forum topics, progress notifications, and interactive Q&A. Use when: messages start with "cc " or "/cc ", user sends /answer, /cc-status, /cc-stop, /cc-config. NOT for: general coding questions (answer directly), simple one-liner fixes (just do it), or tasks the agent should handle itself.'
user-invocable: true
metadata:
  {
    "openclaw":
      {
        "emoji": "🤖",
        "requires": { "anyBins": ["claude"] },
      },
  }
---

# Claude Code Bridge (`/cc`)

Dispatch Claude Code tasks from Telegram with full lifecycle tracking.

## When to Use This Skill

**ALWAYS use this skill when:**
- Message starts with `cc ` or `/cc ` (this is the bridge dispatch command)
- User sends `/answer`, `/cc-status`, `/cc-stop`, or `/cc-config`
- User asks to "run claude code on" or "dispatch to claude code"

**NOT for:**
- General coding questions (answer directly, no dispatch needed)
- Simple one-liner fixes (just do it yourself)
- Tasks you can handle without spawning a background agent
- Thread-bound ACP harness requests (use `sessions_spawn`)

## How It Works

Each `/cc` task:
1. Creates a **forum topic** in the configured Telegram group
2. Spawns **Claude Code in background** via `dispatch.sh`
3. Claude Code **hooks** send progress, questions, and completion to that topic
4. User answers questions via `/answer` — the hook polls for the answer file

## Commands

| Command | Action |
|---------|--------|
| `/cc <dir> <task>` | Dispatch a task (auto-creates topic) |
| `/cc --topic <id> <dir> <task>` | Dispatch to a specific topic |
| `/answer <id> <text>` | Answer a Claude Code question |
| `/cc-status` | List active tasks |
| `/cc-status <id>` | Get task details |
| `/cc-stop <id>` | Stop a running task |
| `/cc-config` | Show notification settings |
| `/cc-config quiet\|minimal\|verbose` | Apply preset |

## Critical Rules

1. **ALWAYS use `dispatch.sh`** to spawn Claude Code — never run `claude` directly.
   The bridge needs the task file for tracking, topic routing, and notification hooks.
2. **Run dispatch.sh via the exec tool** with `background:true` (see CLAUDE.md for exact commands).
3. **Parse `cc` messages carefully** — first arg after `cc` is the directory, rest is the prompt.
