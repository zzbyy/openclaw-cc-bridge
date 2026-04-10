# Claude Code Bridge Skill

This skill enables OpenClaw to dispatch and manage Claude Code tasks via Telegram.

## Triggers

Activate this skill when the user:
- Wants to run Claude Code on a project
- Uses commands like `cc`, `claude-code`, or mentions "claude code"
- Asks about running development tasks in background
- Wants to check status of Claude Code tasks
- Needs to answer a Claude Code question

## Commands

### Dispatch a task

```
cc <directory> <prompt>
claude-code --dir <directory> [options] <prompt>
```

Options:
- `--agent-teams` or `-t`: Enable Agent Teams mode
- `--model <model>`: Specify model (default: claude-sonnet-4)
- `--timeout <minutes>`: Set timeout (default: 60)

Examples:
```
cc ~/projects/myapp implement user authentication
cc /path/to/repo refactor the database layer with proper error handling
claude-code --dir ~/work/api --agent-teams build a REST API for inventory management
```

### Answer a question

When Claude Code asks a question, reply with:
```
/answer <question-id> <your answer>
```

Or reply directly to the question message.

### Check status

```
/cc-status              # List all active tasks
/cc-status <task-id>    # Get specific task details
```

### View logs

```
/cc-logs <task-id>      # View recent output
/cc-logs <task-id> -n 50  # View last 50 lines
```

### Stop a task

```
/cc-stop <task-id>      # Stop a running task
```

## Implementation

### Dispatching Tasks

When dispatching a task:

1. Parse the command to extract:
   - `directory`: The working directory for Claude Code
   - `prompt`: The task description
   - `options`: Any flags like --agent-teams

2. Generate a task ID: `task-{timestamp}-{random}`

3. Create task file at `~/.openclaw/cc-bridge/tasks/{task-id}.json`:
```json
{
    "task_id": "task-1234567890-abc",
    "prompt": "implement user authentication",
    "cwd": "/Users/you/projects/myapp",
    "options": {
        "agent_teams": false,
        "model": "claude-sonnet-4"
    },
    "status": "pending",
    "created_at": "2026-04-10T10:00:00Z"
}
```

4. Spawn Claude Code in background:
```bash
cd "<directory>" && \
nohup claude --dangerously-skip-permissions \
    -p "<prompt>" \
    --output-format stream-json \
    > ~/.openclaw/cc-bridge/logs/<task-id>.log 2>&1 &
```

5. Confirm to user: "✅ Task `{task-id}` started in `{directory}`"

### Handling Events

Monitor `~/.openclaw/cc-bridge/events/` for new event files.

When `[CC-QUESTION]` wake event arrives:
1. Find the question file in `~/.openclaw/cc-bridge/questions/`
2. Format and send to Telegram:
```
🤔 Claude Code Question [task-id]
─────────────────────────
{question message}
─────────────────────────
Reply: /answer {question-id} <your response>
Or reply directly to this message.
```

When `[CC] Session ended` arrives:
1. Find the completed task in `~/.openclaw/cc-bridge/completed/`
2. Send summary to Telegram:
```
✅ Task [{task-id}] completed
Duration: 5m 23s
Directory: /path/to/project
```

### Handling Answers

When user replies with `/answer {question-id} {answer}`:

1. Write answer file to `~/.openclaw/cc-bridge/answers/{question-id}.json`:
```json
{
    "question_id": "q-1234567890",
    "answer": "Use PostgreSQL with SQLAlchemy",
    "status": "answered",
    "answered_at": "2026-04-10T10:05:00Z"
}
```

2. Confirm: "✅ Answer sent to Claude Code"

The elicitation hook polling loop will pick up the answer file.

### Environment Variables

Required in `~/.openclaw/.env`:
```
OPENCLAW_GATEWAY_URL=http://127.0.0.1:18789
OPENCLAW_GATEWAY_TOKEN=<your-gateway-token>
CC_BRIDGE_DIR=~/.openclaw/cc-bridge
```

## File Locations

- Tasks: `~/.openclaw/cc-bridge/tasks/`
- Questions: `~/.openclaw/cc-bridge/questions/`
- Answers: `~/.openclaw/cc-bridge/answers/`
- Events: `~/.openclaw/cc-bridge/events/`
- Logs: `~/.openclaw/cc-bridge/logs/`
- Completed: `~/.openclaw/cc-bridge/completed/`

## Error Handling

- If Claude Code fails to start, notify user immediately
- If task times out, send timeout notification
- If question times out (5 min default), notify user
- Clean up stale files older than 24 hours

## Security Notes

- Tasks run with `--dangerously-skip-permissions`
- Only allow trusted users to dispatch tasks
- Validate directory paths before use
- Don't expose sensitive info in logs
