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

Use `sessions_spawn` to create a thread-bound ACP session:

```json
sessions_spawn({
  "task": "<FULL VERBATIM PROMPT>",
  "runtime": "acp",
  "agentId": "claude",
  "thread": true,
  "mode": "session"
})
```

**Fallback** (if `sessions_spawn` unavailable):
```bash
ACPX=$(find ~/.nvm -name acpx -path "*/openclaw/node_modules/.bin/*" 2>/dev/null | head -1)
bash command:"$ACPX claude sessions new --name cc-live-<topic_id>"
bash command:"$ACPX claude -s cc-live-<topic_id> --cwd '<dir>' '<prompt>'"
```

Confirm: `🔴 Live session started in <dir>. Messages in this topic go directly to Claude Code.`

### Stop: `/cc-live stop`

```bash
ACPX=$(find ~/.nvm -name acpx -path "*/openclaw/node_modules/.bin/*" 2>/dev/null | head -1)
bash command:"$ACPX claude sessions close cc-live-<topic_id>"
```

Confirm: `⏹️ Live session ended.`

### Rules

- Pass the FULL prompt VERBATIM (same as /cc)
- Once live session is active, forward user messages to the ACP session
- Prefix Claude Code responses with `[Claude Code]`
