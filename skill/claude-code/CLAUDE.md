# Claude Code Integration Instructions

You can dispatch tasks to Claude Code and manage them via these commands.

## How It Works

Users send tasks via **DM** to this bot. Each task automatically gets its own **forum topic**
in the configured Telegram group (`CC_TELEGRAM_GROUP`). All updates — progress, questions,
completion — go to that topic. This keeps DMs clean and lets you track parallel tasks.

```
DM: "cc ~/project implement auth" → Bot creates topic "[abc1] implement auth..."
                                   → All updates land in that topic
                                   → Completion summary posted there too
```

## Dispatching Tasks

When the user sends a message starting with `cc ` or `claude-code `, parse it as a Claude Code task:

**Format**: `cc <directory> <task description>`

**With explicit topic** (optional — topics are auto-created by default):
`cc --topic <topic_id> <directory> <task description>`

**Examples**:
```
cc ~/projects/myapp implement user authentication with JWT tokens
cc ~/projects/api refactor the database layer
```

**Action**: Run the dispatch script:
```bash
~/.agents/skills/claude-code/scripts/dispatch.sh --dir "<directory>" [--topic "<topic_id>"] -- "<task description>"
```

The script auto-creates a forum topic in the group if no `--topic` is specified and
`CC_TELEGRAM_GROUP` is set. The topic is named after the task prompt.

**Response format** (reply in DM to confirm):
```
✅ Task started!
📋 ID: task-xxx
📁 Directory: /path/to/project
🚀 Running in background...

Updates will appear in the group topic.
I'll notify you when:
• Task completes
• Claude Code has questions
• Something needs attention
```

## Handling Claude Code Questions

When you receive a wake event containing `[CC-QUESTION]`:

1. Read the question file from `~/.openclaw/cc-bridge/questions/`
2. Send to user in this format:

```
🤔 Claude Code Question
━━━━━━━━━━━━━━━━━━━━━
Task: [task-id]
━━━━━━━━━━━━━━━━━━━━━

[question text here]

━━━━━━━━━━━━━━━━━━━━━
Reply with: /answer [question-id] <your answer>
```

## Handling Answers

When user sends `/answer <id> <text>`:
```bash
~/.agents/skills/claude-code/scripts/answer.sh "<id>" "<text>"
```

**Response**:
```
✅ Answer sent to Claude Code
```

## Status Commands

`/cc-status` - List all active tasks:
```bash
~/.agents/skills/claude-code/scripts/status.sh
```

`/cc-status <id>` - Get specific task:
```bash
~/.agents/skills/claude-code/scripts/status.sh "<id>"
```

## Stop Command

`/cc-stop <id>` - Stop a task:
```bash
~/.agents/skills/claude-code/scripts/stop-task.sh "<id>"
```

## Configure Notifications

Control which notifications you receive:

`/cc-config` - Show current settings:
```bash
~/.agents/skills/claude-code/scripts/config.sh show
```

`/cc-config <preset>` - Apply a preset:
```bash
~/.agents/skills/claude-code/scripts/config.sh quiet    # Only completion & errors
~/.agents/skills/claude-code/scripts/config.sh minimal  # Start + completion + errors  
~/.agents/skills/claude-code/scripts/config.sh verbose  # All notifications
```

`/cc-config set <key> <on|off>` - Toggle specific notifications:
```bash
~/.agents/skills/claude-code/scripts/config.sh set notifications.progress off
~/.agents/skills/claude-code/scripts/config.sh set notifications.start on
~/.agents/skills/claude-code/scripts/config.sh toggle notifications.complete
```

**Notification types:**
- `notifications.start` - Task started
- `notifications.progress` - Progress updates (files, tests, etc.)
- `notifications.question` - Questions from Claude Code (⚠️ keep on!)
- `notifications.complete` - Completion summary
- `notifications.error` - Error alerts

**Progress sub-filters** (when progress=on):
- `progress_filter.file_created` - New file notifications
- `progress_filter.package_install` - npm/pip/yarn install
- `progress_filter.tests` - Test runs
- `progress_filter.git` - Git commits/push
- `progress_filter.subagent` - Subagent spawns
- `progress_filter.milestone_interval` - Steps between updates (default: 5)

## Event Handling

When you receive wake events from Claude Code hooks:

- `[CC-START] <task-id>` → Acknowledge silently (already notified on dispatch)
- `[CC-PROGRESS] [<task-id>] ...` → Forward progress update to user
- `[CC-COMPLETE] <task-id> ...` → Send completion summary to user
- `[CC-ERROR] [<task-id>] ...` → Notify: "⚠️ Error in task"
- `[CC-QUESTION] <question-id> task:<task-id>` → Forward question to user (see above)
- `[CC-TIMEOUT] [<task-id>] ...` → Notify: "⏰ Question timed out, task may be stuck"
- `[CC-IDLE] ...` → Notify: "⏸️ Waiting for input"
- `[CC-PERMISSION] ...` → Notify: "🔐 Permission needed"

## Quick Reference

| Command | Description |
|---------|-------------|
| `cc <dir> <task>` | Start new Claude Code task |
| `cc --topic <id> <dir> <task>` | Start task in specific topic |
| `/answer <id> <text>` | Answer a question |
| `/cc-status` | List active tasks |
| `/cc-status <id>` | Get task details |
| `/cc-stop <id>` | Stop a task |
| `/cc-config` | Show notification settings |
| `/cc-config quiet` | Only completion & errors |
| `/cc-config minimal` | Start + completion + errors |
| `/cc-config verbose` | All notifications |
| `/cc-config set <key> <on/off>` | Toggle a setting |
