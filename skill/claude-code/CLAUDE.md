# Claude Code Integration Instructions

You can dispatch tasks to Claude Code and manage them via these commands.

**Important**: All Claude Code notifications go to the configured Telegram group/channel (set via `CC_TELEGRAM_GROUP`). Always respond in that same channel, not in DMs.

## Dispatching Tasks

When the user sends a message starting with `cc ` or `claude-code `, parse it as a Claude Code task:

**Format**: `cc <directory> <task description>`

**With topic** (for parallel tasks in separate forum topics):
`cc --topic <topic_id> <directory> <task description>`

**Example**:
```
cc ~/projects/myapp implement user authentication with JWT tokens
```

**With topic** (each task gets its own topic thread):
```
cc --topic 42 ~/projects/api build the REST endpoints
cc --topic 43 ~/projects/frontend create the login form
```

**Action**: Run the dispatch script:
```bash
~/.openclaw/skills/claude-code/scripts/dispatch.sh --dir "<directory>" [--topic "<topic_id>"] -- "<task description>"
```

**Auto-create topic**: If user says "cc in new topic ~/dir task", create a new forum topic first, then dispatch to it.

**Response format**:
```
✅ Task started!
📋 ID: task-xxx
📁 Directory: /path/to/project
🚀 Running in background...

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
~/.openclaw/skills/claude-code/scripts/answer.sh "<id>" "<text>"
```

**Response**:
```
✅ Answer sent to Claude Code
```

## Status Commands

`/cc-status` - List all active tasks:
```bash
~/.openclaw/skills/claude-code/scripts/status.sh
```

`/cc-status <id>` - Get specific task:
```bash
~/.openclaw/skills/claude-code/scripts/status.sh "<id>"
```

## Stop Command

`/cc-stop <id>` - Stop a task:
```bash
~/.openclaw/skills/claude-code/scripts/stop-task.sh "<id>"
```

## Configure Notifications

Control which notifications you receive:

`/cc-config` - Show current settings:
```bash
~/.openclaw/skills/claude-code/scripts/config.sh show
```

`/cc-config <preset>` - Apply a preset:
```bash
~/.openclaw/skills/claude-code/scripts/config.sh quiet    # Only completion & errors
~/.openclaw/skills/claude-code/scripts/config.sh minimal  # Start + completion + errors  
~/.openclaw/skills/claude-code/scripts/config.sh verbose  # All notifications
```

`/cc-config set <key> <on|off>` - Toggle specific notifications:
```bash
~/.openclaw/skills/claude-code/scripts/config.sh set notifications.progress off
~/.openclaw/skills/claude-code/scripts/config.sh set notifications.start on
~/.openclaw/skills/claude-code/scripts/config.sh toggle notifications.complete
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

- `[CC] Task xxx started` → Acknowledge silently (already notified on dispatch)
- `[CC] Response complete` → Notify user: "Claude Code completed a step"
- `[CC] Session ended (exit)` → Notify: "✅ Task [id] completed successfully"
- `[CC] Session ended (error)` → Notify: "⚠️ Task [id] ended with error"
- `[CC-QUESTION]` → Forward question to user (see above)
- `[CC] Question xxx timed out` → Notify: "⏰ Question timed out, task may be stuck"

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
