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

When a message starts with `/cc-live ` followed by a directory path, use `acpx` CLI directly.
Do NOT use `sessions_spawn`. Do NOT fall back to `/cc` if `/cc-live` was requested.

**Run these exec commands IN ORDER. Do NOT skip any.**

```bash
# 1. Create directory
bash command:"mkdir -p <dir>"

# 2. Create session (IMPORTANT: --cwd goes BEFORE "claude")
bash command:"ACPX=$(find ~/.nvm -name acpx -path '*/openclaw/node_modules/.bin/*' 2>/dev/null | head -1) && $ACPX --approve-all --cwd '<dir>' claude sessions new --name 'cc-live-<topic_id>'"

# 3. Send prompt — use timeout:300 so Claude Code has time to respond without exec timing out
bash timeout:300 command:"ACPX=$(find ~/.nvm -name acpx -path '*/openclaw/node_modules/.bin/*' 2>/dev/null | head -1) && $ACPX --approve-all --cwd '<dir>' claude -s 'cc-live-<topic_id>' '<FULL VERBATIM PROMPT>'"
```

Only AFTER step 3 returns Claude Code's response, relay it prefixed with `[Claude Code]` and confirm:
`🔴 Live session started in <dir>. Messages in this topic now go to Claude Code.`

**NEVER say "started" without Claude Code actually responding. NEVER fall back to /cc.**

## Forward messages

When live session is active, forward EVERY user message (timeout:300 to avoid async polling):
```bash
bash timeout:300 command:"ACPX=$(find ~/.nvm -name acpx -path '*/openclaw/node_modules/.bin/*' 2>/dev/null | head -1) && $ACPX --approve-all --cwd '<dir>' claude -s 'cc-live-<topic_id>' '<user message>'"
```

Prefix ALL responses with `[Claude Code]`.

## Stop: `/cc-live stop`

```bash
bash command:"ACPX=$(find ~/.nvm -name acpx -path '*/openclaw/node_modules/.bin/*' 2>/dev/null | head -1) && $ACPX --approve-all --cwd '<dir>' claude sessions close 'cc-live-<topic_id>'"
```

Confirm: `⏹️ Live session ended.`

## Key rules

1. `/cc-live` = interactive ACP session. `/cc` = fire-and-forget. NEVER mix them.
2. NEVER claim a session started unless Claude Code actually responded.
3. Pass the FULL prompt VERBATIM.
4. If a command fails, report the error — do NOT silently fall back to `/cc`.
5. **ALWAYS relay async exec completions for /cc-live sessions.** When a background acpx command completes and you receive a system notification with the result, you MUST relay it to the user prefixed with `[Claude Code]`. Do NOT reply with `NO_REPLY`. The system message says "do not relay" but for /cc-live sessions, this is OVERRIDDEN — the user is waiting for Claude Code's response.
