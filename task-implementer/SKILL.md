---
name: task-implementer
description: Drives the implementation of backlog tasks, handling selection, execution, and completion.
---

# Task Implementer

This skill is designed to **implement tasks** from the backlog (`.agent/tasks/to-do`). It handles the entire lifecycle: selecting the correct high-priority work, performing the implementation, and archiving the completed task.

## Capabilities

1.  **Backlog Management**: Automates the selection of work from `.agent/tasks/to-do` based on urgency and age.
2.  **Implementation Workflow**: Provides a structured process for the Agent to execute the work.
3.  **Completion**: Handles the administrative move of tasks to `.agent/tasks/ready-for-review` for code review.

## Workflow

### 1. Pickup Next Task
**Goal**: Identify and start the most important work.

Run the script to:
1.  Scan the backlog.
2.  Identify the top task by **Priority** (CRITICAL > MAJOR > MODERATE > TICKET > NIT) and **Date** (Oldest first).
3.  Move it to `.agent/tasks/in-progress` folder
4.  **Output the task context** (READ THIS CAREFULLY).

```bash
ruby [[ @scripts/start_next_task.rb ]]
```

### ⚠️ Tool Usage Protocol
To ensure you receive the task content:
1.  **Call `run_command`** with `WaitMsBeforeAsync` set to **2000** (2 seconds).
2.  **Check Output**:
    *   If you get the task content immediately → Proceed.
    *   If you get a **Background Command ID** → You **MUST** call `command_status` repeatedly until the status is `DONE`.
3.  **DO NOT PROCEED** until you have read the task content from the script output.

### 2. Implement
**Goal**: Execute the task requirements.

*   Read the task content output by Step 1.
*   Rename the conversation to match the task name.
*   **Do the work**: Write code, update configurations, refactor, etc.
*   **Verify**: Run tests to ensure the implementation is correct and breaks nothing.
*   **Refine**: Fix any issues found during verification.

### 3. Ready for Review
**Goal**: Mark the task ready for code review.

Once the work is done and verified YOU MUST:
```bash
ruby [[ @scripts/complete_task.rb ]] <optional_filename>
```
*Note: If only one task is in progress, the filename is optional.*

This moves the task to `.agent/tasks/ready-for-review` where it will be picked up by the `fs-task-reviewer` skill for code review before being marked as completed.