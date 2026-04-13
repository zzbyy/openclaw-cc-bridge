# CC Bridge — MANDATORY

## Rule: NEVER do /cc work yourself

When you see `/cc <dir> <task>` or `cc <dir> <task>`:

1. Do NOT create files, write code, or handle the task
2. Run this EXACTLY:

```bash
bash command:"~/.agents/skills/cc/scripts/cc-entry.sh <dir> <task>"
```

3. Reply with the task ID from the JSON output

That's it. The script spawns Claude Code in the background with full tracking.

## /answer

```bash
bash command:"~/.agents/skills/cc/scripts/answer.sh '<id>' '<text>'"
```

## /cc-status

```bash
bash command:"~/.agents/skills/cc/scripts/status.sh"
```

## /cc-stop

```bash
bash command:"~/.agents/skills/cc/scripts/stop-task.sh '<id>'"
```

## /cc-config

```bash
bash command:"~/.agents/skills/cc/scripts/config.sh show"
bash command:"~/.agents/skills/cc/scripts/config.sh quiet"
bash command:"~/.agents/skills/cc/scripts/config.sh verbose"
```

---

## /cc-live — Interactive Claude Code Session

For complex tasks. Opens a persistent Claude Code session in the current topic.

### Start: `/cc-live <dir> <prompt>`

**Step 1:** Create directory if needed:
```bash
bash command:"mkdir -p <dir>"
```

**Step 2:** Try `sessions_spawn` first:
```json
sessions_spawn({
  "task": "<FULL VERBATIM PROMPT>",
  "runtime": "acp",
  "agentId": "claude",
  "thread": true,
  "mode": "session"
})
```

**Step 3:** If `sessions_spawn` fails, use `acpx` CLI. Run ALL commands:
```bash
ACPX=$(find ~/.nvm -name acpx -path "*/openclaw/node_modules/.bin/*" 2>/dev/null | head -1)

# Create the session (--cwd is a TOP-LEVEL acpx flag)
bash command:"$ACPX --cwd '<dir>' claude sessions new --name cc-live-<topic_id>"

# Send the prompt — WAIT for Claude Code's response
bash command:"$ACPX --cwd '<dir>' claude -s cc-live-<topic_id> '<prompt>'"
```

**Step 4:** Only after Claude Code responds, confirm:
`🔴 Live session started in <dir>. Messages in this topic go directly to Claude Code.`

Then relay Claude Code's response prefixed with `[Claude Code]`.

**NEVER say "Live session started" without actually running the commands and getting a response.**

### Forward messages

When live session is active and user sends a message:
```bash
bash command:"$ACPX claude -s cc-live-<topic_id> '<user message>'"
```

Prefix response with `[Claude Code]`.

### Stop: `/cc-live stop`

```bash
ACPX=$(find ~/.nvm -name acpx -path "*/openclaw/node_modules/.bin/*" 2>/dev/null | head -1)
bash command:"$ACPX claude sessions close cc-live-<topic_id>"
```

Confirm: `⏹️ Live session ended.`
