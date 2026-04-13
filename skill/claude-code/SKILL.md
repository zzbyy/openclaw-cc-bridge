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

**Pass the ENTIRE user text after the directory as the prompt — VERBATIM, UNMODIFIED.**
Do NOT interpret, rephrase, summarize, split, or act on any part of the prompt.
The full text is for Claude Code, not for you.

**If the conversation metadata contains `topic_id`, you MUST pass it as `--topic`** so notifications go back to this topic.

```bash
# With topic_id from metadata:
~/.agents/skills/cc/scripts/cc-entry.sh --topic <topic_id> <dir> "<FULL VERBATIM PROMPT>"

# Without topic_id:
~/.agents/skills/cc/scripts/cc-entry.sh <dir> "<FULL VERBATIM PROMPT>"
```

Example — user sends `/cc ~/myapp build an API server. Ask me what framework to use before writing code.` in topic 50:
```bash
~/.agents/skills/cc/scripts/cc-entry.sh --topic 50 ~/myapp "build an API server. Ask me what framework to use before writing code."
```

The ENTIRE text including "Ask me..." goes to Claude Code. You do NOT ask those questions yourself.

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
