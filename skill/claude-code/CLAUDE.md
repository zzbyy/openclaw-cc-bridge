# CC Bridge — Agent Instructions

## Dispatching Tasks

When a message starts with `cc ` or `/cc `, **you MUST use dispatch.sh** — never run `claude` directly.
The bridge creates task files, forum topics, and notification hooks that only work through dispatch.sh.

### Parse the message

```
/cc <directory> <task description>
/cc --topic <id> <directory> <task description>
```

First token after `cc` is the directory (starts with `~/` or `/`). Everything after is the prompt.

### Run dispatch.sh

```bash
bash background:true command:"~/.agents/skills/cc/scripts/dispatch.sh --dir '<directory>' -- '<task description>'"
```

**With explicit topic:**
```bash
bash background:true command:"~/.agents/skills/cc/scripts/dispatch.sh --dir '<directory>' --topic '<topic_id>' -- '<task description>'"
```

The script:
- Auto-creates a forum topic in the group (if `CC_TELEGRAM_GROUP` is set)
- Spawns Claude Code in background
- Returns JSON with `task_id`, `pid`, `topic`

### Confirm to user

After dispatch.sh returns, reply in DM:
```
✅ Task dispatched!
📋 ID: <task_id>
📁 Directory: <directory>
🚀 Updates will appear in the group topic.
```

## Answering Questions

When user sends `/answer <question-id> <answer text>`:

```bash
bash command:"~/.agents/skills/cc/scripts/answer.sh '<question-id>' '<answer text>'"
```

Reply: `✅ Answer sent to Claude Code`

## Status

`/cc-status`:
```bash
bash command:"~/.agents/skills/cc/scripts/status.sh"
```

`/cc-status <id>`:
```bash
bash command:"~/.agents/skills/cc/scripts/status.sh '<task-id>'"
```

Format the JSON output as a readable status message.

## Stop

`/cc-stop <id>`:
```bash
bash command:"~/.agents/skills/cc/scripts/stop-task.sh '<task-id>'"
```

Reply: `⏹️ Task <id> stopped`

## Configure Notifications

`/cc-config`:
```bash
bash command:"~/.agents/skills/cc/scripts/config.sh show"
```

`/cc-config <preset>` (quiet, minimal, verbose):
```bash
bash command:"~/.agents/skills/cc/scripts/config.sh <preset>"
```

`/cc-config set <key> <on|off>`:
```bash
bash command:"~/.agents/skills/cc/scripts/config.sh set <key> <value>"
```

## Wake Events

Claude Code hooks send wake events as tasks progress. When you see these in the session:

- `[CC-START]` — task started (already confirmed on dispatch, ignore)
- `[CC-PROGRESS]` — forward to user if relevant
- `[CC-COMPLETE]` — task finished, forward the summary
- `[CC-ERROR]` — something failed, notify user
- `[CC-QUESTION]` — Claude Code needs input, forward and tell user to `/answer`
- `[CC-TIMEOUT]` — question timed out, notify user
