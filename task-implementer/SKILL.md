---
name: task-implementer
description: Drives the implementation of backlog tasks using beads issue tracking.
---

# Task Implementer

This skill implements tasks from the beads issue tracker. It handles the entire lifecycle: selecting high-priority unblocked work, performing the implementation, and marking tasks ready for review.

## ⚠️ CRITICAL: Script Usage Protocol

### MANDATORY Script Usage

This skill provides helper scripts that MUST be used instead of raw `bd` commands.

**Why scripts are mandatory:**
1. **Race condition prevention** - Scripts call `bd sync` immediately after state changes
2. **Label filtering** - Scripts filter tasks agents shouldn't touch
3. **State validation** - Scripts ensure consistent label states
4. **Parent cleanup** - Scripts remove stale relationships

### ❌ PROHIBITED: Raw bd Commands

**NEVER run these directly:**
- `bd update <id> --status in_progress` → Use `start_next_task.rb`
- `bd update <id> --add-label ready-for-review` → Use `complete_task.rb`
- `bd close <id>` → Use `close_task.rb` (cleans up dependencies)
- `bd create` for review findings → Use `fs-task-reviewer/scripts/create_fix_ticket.rb`

**Consequences of bypassing:**
- Race conditions (daemon overwrites your claim)
- Wrong task selection (pick up review tasks by mistake)
- **Stale dependencies** (parent tasks stay blocked after fix tickets close)
- Inconsistent state (missing sync, wrong filters)

### ✅ CORRECT: Use These Scripts

See workflow section below for proper script usage.

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

**If no tasks are found**:
1. Check for workflow corruption by running:
   ```bash
   ruby ~/.claude/skills/beads-workflow-diagnostics/scripts/check_and_fix.rb --verbose
   ```
2. If the script exits with code 0 (fixes applied):
   - Re-run `start_next_task.rb` to try again
   - Inform the user: "Workflow inconsistency detected and fixed. Retrying task selection..."
3. If the script exits with code 1 (no issues):
   - Report to user: "No tasks ready to work on!"
   - Show any in-progress or blocked tasks
   - STOP

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

#### Automatic Validation

**NEW**: Validation is now **automatic** when task descriptions contain commit references.

The `complete_task.rb` script automatically:
1. Detects commit hashes in task description (7+ hex characters matching `/\b[0-9a-f]{7,40}\b/i`)
2. Runs `validate_task.rb` before marking ready-for-review
3. Blocks task completion if validation fails

**Override flags:**
```bash
# Force validation even without commit hashes
ruby [[ @scripts/complete_task.rb ]] <task_id> --validate

# Skip automatic validation (for edge cases)
ruby [[ @scripts/complete_task.rb ]] <task_id> --skip-validation
```

**Why validation matters:**
- Prevents false commit claims (e.g., claiming commit X contains changes it doesn't have)
- Catches user errors where uncommitted changes are mistaken for committed work
- Ensures task descriptions are factually accurate for future reference
- See `.agent/context/workflow/task-validation-incident-2026-02-12.md` for real incident example

**What validation checks:**
- ✓ Referenced commits exist in git history
- ✓ Mentioned files exist in the codebase
- ✓ Claimed code patterns are present in specified commits
- ✓ Commits actually changed the files mentioned in the task

**Automatic validation triggers when:**
- ✅ Task description contains commit hashes (e.g., `abc1234`, `58d9104ef`)
- ✅ Task claims code changes were made in specific files
- ✅ Task references specific commits in its description

**Example:**
```bash
# Task claims work was completed in commit abc1234
$ ruby [[ @scripts/complete_task.rb ]] PrintMines-xyz --validate

✓ Commit abc1234 exists
✓ File exists: app/javascript/types/index.ts
✓ Pattern found: Record<string, string>
✓ Commit abc1234 changed app/javascript/types/index.ts
✓ VALIDATION PASSED
Task PrintMines-xyz marked ready-for-review
```

If validation fails, the task will NOT be marked ready for review. Fix the task description to be factually accurate before retrying.

See `[[ @assets/validation-checklist.md ]]` for full validation criteria and manual verification steps.

This adds the `ready-for-review` label to the task. The `fs-task-reviewer` skill will pick it up for code review.

## Priority Levels

| Priority | Label | Description | Blocking |
|----------|-------|-------------|----------|
| P0 | `critical` | Security, data loss, critical bugs | Yes |
| P1 | `major` | SOLID violations, missing tests for core logic | Yes |
| P2 | `moderate` | Maintainability issues, complex methods | Yes |
| P3 | `ticket` | Standard feature work | No (`polish`) |
| P4 | `nit` | Style, naming, minor refactors | No (`polish`) |

### Polish Tasks

Tasks labeled `polish` are low-priority (P3-P4) follow-up work created during code review. They are:
- **Non-blocking**: Don't hold up parent task approval
- **Deferred by default**: `start_next_task.rb` skips them when feature work exists
- **Automatic fallback**: Picked up when no other work is available

**To explicitly work on polish tasks:**
```bash
ruby [[ @scripts/start_next_task.rb ]] --polish
```

**To list all polish tasks:**
```bash
bd list --label polish
```

### 4. Closing Fix Tickets

When completing fix tickets (created by fs-task-reviewer), use the close script:

```bash
ruby [[ @scripts/close_task.rb ]] <task_id>
```

**Why use this script instead of `bd close`:**
- Automatically removes dependencies pointing to the closed task
- Unblocks parent tasks that were waiting for this fix
- Syncs changes immediately

**Example:**
```bash
# Fix ticket PROJ-fix1 was blocking PROJ-parent
$ ruby scripts/close_task.rb PROJ-fix1
✓ Closed PROJ-fix1
Cleaning up dependencies...
  ✓ PROJ-parent no longer blocked by PROJ-fix1
✓ Changes synced
```

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

# Close a task (use script to clean up dependencies)
ruby .agent/skills/task-implementer/scripts/close_task.rb <task-id>

# Validate task description for factual accuracy
ruby .agent/skills/task-implementer/scripts/validate_task.rb <task-id>
```

## Task Validation

The validation system helps prevent tasks from being created with factually incorrect information (e.g., claiming a commit contains changes it doesn't have).

### Validation Script

Run standalone validation:
```bash
ruby .agent/skills/task-implementer/scripts/validate_task.rb <task-id>
```

This checks:
1. **Git commits** - Verifies referenced commits exist in git history
2. **File paths** - Checks mentioned files exist in the codebase
3. **Code patterns** - Searches for claimed code patterns
4. **Cross-references** - Validates commits changed the mentioned files

### Integrated Validation

Run validation automatically before marking tasks ready for review:
```bash
ruby .agent/skills/task-implementer/scripts/complete_task.rb --validate
```

If validation fails, the task will not be marked ready for review.

### Validation Checklist

See `[[ @assets/validation-checklist.md ]]` for:
- Detailed validation criteria
- Manual verification steps
- Common mistakes to avoid
- Best practices for task descriptions
- Examples of good vs. bad task descriptions

### When to Use Validation

**Always validate when:**
- Task description references specific commits
- Task claims code changes were made in specific files
- Task closes another task as "already completed"
- Task description contains technical claims about implementation

**Optional for:**
- Simple bug fixes with no commit references
- Tasks created during implementation (not after the fact)
- Documentation-only tasks

### Example Validation Output

**Passing validation:**
```
✓ Commit 58d9104 exists
✓ File exists: app/javascript/types/index.ts
✓ Pattern found: Record<string, string>
✓ VALIDATION PASSED
```

**Failing validation:**
```
✗ Commit efea1b1 NOT FOUND in git history
✗ VALIDATION FAILED
  Action required: Update task description to correct factual errors.
```
