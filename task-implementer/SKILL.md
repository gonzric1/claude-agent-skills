---
name: task-implementer
description: Drives the implementation of backlog tasks using beads issue tracking.
---

# Task Implementer

This skill implements tasks from the beads issue tracker. It handles the entire lifecycle: selecting high-priority unblocked work, performing the implementation, and marking tasks ready for review.

## Prerequisites

Initialize beads in your project if not already done:
```bash
bd init
```

## Capabilities

1. **Task Selection**: Automatically selects the highest-priority, unblocked task using `bd ready`
2. **Implementation Workflow**: Provides a structured process for executing work
3. **Completion**: Marks tasks as ready for code review

## Workflow

### 1. Pickup Next Task
**Goal**: Identify and start the most important unblocked work.

Run the script to:
1. Query ready tasks (unblocked, sorted by priority)
2. Claim the top task (sets status to `in_progress`)
3. Output the task content

```bash
ruby [[ @scripts/start_next_task.rb ]]
```

**If no tasks are found**: The script will output "No tasks ready to work on!" and show any in-progress or blocked tasks. Report this to the user and STOP.

### ⚠️ Tool Usage Protocol
To ensure you receive the task content:
1. **Call `run_command`** with `WaitMsBeforeAsync` set to **2000** (2 seconds).
2. **Check Output**:
    * If you get the task content immediately → Proceed.
    * If you get a **Background Command ID** → You **MUST** call `command_status` repeatedly until the status is `DONE`.
3. **DO NOT PROCEED** until you have read the task content from the script output.

### 2. Implement
**Goal**: Execute the task requirements.

* Read the task content output by Step 1.
* Rename the conversation to match the task title.
* **Do the work**: Write code, update configurations, refactor, etc.
* **Verify**: Run tests to ensure the implementation is correct and breaks nothing.
* **Refine**: Fix any issues found during verification.

### 3. Ready for Review
**Goal**: Mark the task ready for code review.

Once the work is done and verified:
```bash
ruby [[ @scripts/complete_task.rb ]] <optional_task_id>
```
*Note: If only one task is in progress, the task ID is optional.*

This adds the `ready-for-review` label to the task. The `fs-task-reviewer` skill will pick it up for code review.

## Priority Levels

| Priority | Label | Description |
|----------|-------|-------------|
| P0 | `critical` | Security, data loss, critical bugs |
| P1 | `major` | SOLID violations, missing tests for core logic |
| P2 | `moderate` | Maintainability issues, complex methods |
| P3 | `ticket` | Standard feature work |
| P4 | `nit` | Style, naming, minor refactors |

## Useful Commands

```bash
# View all ready tasks
bd ready

# View blocked tasks
bd blocked

# View in-progress tasks
bd list --status in_progress

# View task details
bd show <task-id>

# Add dependency between tasks
bd dep add <blocked-task> <blocker-task>
```
