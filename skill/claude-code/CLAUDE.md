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
