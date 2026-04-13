---
name: cc
description: 'MANDATORY command router for /cc (fire-and-forget tasks) and /cc-live (interactive Claude Code sessions). Handles /cc, /cc-live, /cc-live stop, /answer, /cc-status, /cc-stop, /cc-config. When message starts with /cc or cc followed by a directory, run cc-entry.sh. When message starts with /cc-live, start or stop an ACP Claude Code session.'
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

---

# /cc-live — Interactive Claude Code Session (ACP)

For complex tasks where the user wants to discuss, plan, and iterate with Claude Code directly.

## Start a live session

When a message starts with `/cc-live ` followed by a directory path:

**Step 1: Create the directory if it doesn't exist.**

**Step 2: Use `sessions_spawn` to create a thread-bound ACP Claude Code session.**

You MUST include `agentId`:

```json
sessions_spawn({
  "task": "<FULL VERBATIM PROMPT>",
  "runtime": "acp",
  "agentId": "claude",
  "thread": true,
  "mode": "session"
})
```

**Step 3: If `sessions_spawn` fails, use `acpx` CLI as fallback.**

You MUST run ALL of these commands — do NOT skip any or claim success without running them:

```bash
# Find acpx
ACPX=$(find ~/.nvm -name acpx -path "*/openclaw/node_modules/.bin/*" 2>/dev/null | head -1)

# Create session
$ACPX claude sessions new --name "cc-live-<topic_id>"

# Send the initial prompt (this is what starts Claude Code working)
$ACPX claude -s "cc-live-<topic_id>" --cwd "<dir>" "<prompt>"
```

**Step 4: Only AFTER Claude Code responds**, confirm:
`🔴 Live session started in <dir>. Messages in this topic go directly to Claude Code.`

**Do NOT say "Live session started" until you have confirmed Claude Code is actually running and responded.**

## Forward messages in a live session

Once a live session is active, forward user messages to the ACP session:
```bash
$ACPX claude -s "cc-live-<topic_id>" "<user message>"
```

Prefix Claude Code responses with `[Claude Code]`.

## Stop a live session

When user sends `/cc-live stop`:

```bash
ACPX=$(find ~/.nvm -name acpx -path "*/openclaw/node_modules/.bin/*" 2>/dev/null | head -1)
$ACPX claude sessions close "cc-live-<topic_id>"
```

Confirm: `⏹️ Live session ended.`

## Key rules

1. `/cc-live` creates an INTERACTIVE session — the user talks directly to Claude Code
2. NEVER claim a session started unless Claude Code actually responded
3. Pass the FULL prompt VERBATIM — same rule as `/cc`
4. The existing `/cc` (fire-and-forget) continues to work unchanged
