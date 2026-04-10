---
name: cc
description: 'MANDATORY command router for /cc dispatch. When message starts with /cc or cc followed by a directory path, MUST run cc-entry.sh — never handle the coding task directly. Also handles /answer, /cc-status, /cc-stop, /cc-config.'
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

# /cc — Claude Code Bridge Dispatch

## MANDATORY ROUTING RULE

When a message starts with `/cc ` or `cc ` followed by a path (like `~/...` or `/...`):

**You MUST run the dispatch script. You MUST NOT do the coding work yourself.**

```bash
bash command:"~/.agents/skills/cc/scripts/cc-entry.sh <everything after /cc>"
```

Example — user sends `/cc ~/myapp implement auth`:
```bash
bash command:"~/.agents/skills/cc/scripts/cc-entry.sh ~/myapp implement auth"
```

Then reply with the JSON output from the script.

## Other Commands

| Message | Run this |
|---------|----------|
| `/answer <id> <text>` | `bash command:"~/.agents/skills/cc/scripts/answer.sh '<id>' '<text>'"` |
| `/cc-status` | `bash command:"~/.agents/skills/cc/scripts/status.sh"` |
| `/cc-status <id>` | `bash command:"~/.agents/skills/cc/scripts/status.sh '<id>'"` |
| `/cc-stop <id>` | `bash command:"~/.agents/skills/cc/scripts/stop-task.sh '<id>'"` |
| `/cc-config` | `bash command:"~/.agents/skills/cc/scripts/config.sh show"` |
| `/cc-config <preset>` | `bash command:"~/.agents/skills/cc/scripts/config.sh <preset>"` |
