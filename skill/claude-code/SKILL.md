---
name: cc
description: 'MANDATORY command router for /cc and cc dispatch. When message starts with /cc or cc followed by a directory path (~/ or /), MUST run cc-entry.sh via bash — never handle the coding task directly. Also handles /answer, /cc-status, /cc-stop, /cc-config commands via dedicated scripts.'
metadata:
  {
    "openclaw":
      {
        "emoji": "🤖",
        "requires": { "anyBins": ["claude"] },
      },
  }
---

# /cc — Claude Code Bridge Dispatch

## MANDATORY ROUTING RULE

When a message starts with `/cc ` or `cc ` followed by a path (`~/...` or `/...`):

**You MUST run cc-entry.sh. You MUST NOT do the coding work yourself.**

```bash
~/.agents/skills/cc/scripts/cc-entry.sh <everything after /cc>
```

Example — user sends `/cc ~/myapp implement auth`:
```bash
~/.agents/skills/cc/scripts/cc-entry.sh ~/myapp implement auth
```

This spawns Claude Code in the background with task tracking, progress notifications, and question forwarding. Notifications come back to the same topic where the command was sent.

## Other Commands

| Message | Run this |
|---------|----------|
| `/answer <id> <text>` | `~/.agents/skills/cc/scripts/answer.sh '<id>' '<text>'` |
| `/cc-status` | `~/.agents/skills/cc/scripts/status.sh` |
| `/cc-status <id>` | `~/.agents/skills/cc/scripts/status.sh '<id>'` |
| `/cc-stop <id>` | `~/.agents/skills/cc/scripts/stop-task.sh '<id>'` |
| `/cc-config` | `~/.agents/skills/cc/scripts/config.sh show` |
| `/cc-config <preset>` | `~/.agents/skills/cc/scripts/config.sh <preset>` |

## Why cc-entry.sh?

The dispatch script creates task tracking files and spawns Claude Code with hooks that report progress, questions, and completion back to the current conversation topic. If you run `claude` directly, none of the tracking or notification infrastructure works.
