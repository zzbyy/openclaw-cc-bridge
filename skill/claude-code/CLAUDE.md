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

Use `acpx` CLI directly. Do NOT use `sessions_spawn`. Do NOT fall back to `/cc`.

### Start: `/cc-live <dir> <prompt>`

Run IN ORDER:
```bash
bash command:"mkdir -p <dir>"
bash command:"ACPX=$(find ~/.nvm -name acpx -path '*/openclaw/node_modules/.bin/*' 2>/dev/null | head -1) && $ACPX --approve-all --cwd '<dir>' claude sessions new --name 'cc-live-<topic_id>'"
bash command:"ACPX=$(find ~/.nvm -name acpx -path '*/openclaw/node_modules/.bin/*' 2>/dev/null | head -1) && $ACPX --approve-all --cwd '<dir>' claude -s 'cc-live-<topic_id>' '<FULL VERBATIM PROMPT>'"
```

Relay response with `[Claude Code]` prefix, then confirm:
`🔴 Live session started in <dir>. Messages in this topic now go to Claude Code.`

### Forward messages

```bash
bash command:"ACPX=$(find ~/.nvm -name acpx -path '*/openclaw/node_modules/.bin/*' 2>/dev/null | head -1) && $ACPX --approve-all --cwd '<dir>' claude -s 'cc-live-<topic_id>' '<user message>'"
```

Prefix response with `[Claude Code]`.

### Stop: `/cc-live stop`

```bash
bash command:"ACPX=$(find ~/.nvm -name acpx -path '*/openclaw/node_modules/.bin/*' 2>/dev/null | head -1) && $ACPX --approve-all --cwd '<dir>' claude sessions close 'cc-live-<topic_id>'"
```

Confirm: `⏹️ Live session ended.`
