# fs-task-reviewer Workflow Examples

This document provides practical examples of how to use the fs-task-reviewer skill with the beads issue tracking system.

---

## Quick Reference

```bash
# Always start with this
ruby scripts/check_review_status.rb

# If tasks are ready for review
ruby scripts/get_task_for_review.rb

# Run static analysis
bash scripts/review-suite.sh

# If issues found, create normal tickets
bd create --title "Add test coverage" --type task --priority 0
bd create --title "Add YARD docs" --type documentation --priority 1

# Add blocking dependencies
bd dep add <original-task-id> <fix-ticket-id>

# If review passes, approve the task
ruby scripts/approve_task.rb <task-id>
```

---

## Example 1: First Code Review (Task Ready for Review)

### Developer: "I finished implementing the feature, ready for review"

**Step 1: Check review status**
```bash
$ ruby scripts/check_review_status.rb

✅ Tasks Ready for Review (1)
  • PrintMines-abc: Add printer fleet monitoring

⏳ Tasks Awaiting Fixes (0)

Next steps:
  ruby scripts/get_task_for_review.rb
```

**Step 2: Get task for review**
```bash
$ ruby scripts/get_task_for_review.rb

============================================================
TASK READY FOR REVIEW
============================================================

ID: PrintMines-abc
Title: Add printer fleet monitoring
Priority: 1 (major)
Status: open
Labels: ready-for-review

Description:
Implement real-time monitoring for the printer fleet using
WebSocket connections to track status, print progress, and
error conditions.

Acceptance Criteria:
- WebSocket client connects to all printers
- Status updates displayed in UI
- Error alerts shown immediately
- Tests cover connection handling

============================================================
```

**Step 3: Run static analysis**
```bash
$ bash scripts/review-suite.sh
Running RuboCop...
✅ No offenses detected

Running Brakeman...
✅ No security issues found

Running ESLint...
✅ No linting errors

Running tests...
❌ 2 tests failed in printer_monitor_test.rb
```

**Step 4: Manual review finds issues**

Issues found:
- ❌ Tests failing - WebSocket connection timeout not handled (P0 - Critical)
- ❌ No YARD documentation on new MonitorService class (P1 - Major)
- ❌ Error handling swallows exceptions without logging (P2 - Moderate)

**Step 5: Create tickets for issues**

```bash
$ bd create --title "Fix WebSocket timeout test failures" \
  --type bug \
  --priority 0 \
  --description "printer_monitor_test.rb has 2 failing tests due to missing timeout handling in MonitorService#connect" \
  --acceptance "All tests pass. Add timeout parameter (default 5s) to connect method."

Created PrintMines-f1

$ bd create --title "Add YARD documentation to MonitorService" \
  --type documentation \
  --priority 1 \
  --description "MonitorService class and public methods lack YARD docs" \
  --acceptance "Add @param, @return, @raise documentation to all public methods"

Created PrintMines-f2

$ bd create --title "Add error logging to exception handlers" \
  --type task \
  --priority 2 \
  --description "Exception rescue blocks in MonitorService don't log errors before re-raising" \
  --acceptance "Add Rails.logger.error with context before each rescue/re-raise"

Created PrintMines-f3
```

**Step 6: Add blocking dependencies**

```bash
$ bd dep add PrintMines-abc PrintMines-f1
$ bd dep add PrintMines-abc PrintMines-f2
$ bd dep add PrintMines-abc PrintMines-f3

# Optional: Add parent relationships for context
$ bd update PrintMines-f1 --parent PrintMines-abc
$ bd update PrintMines-f2 --parent PrintMines-abc
$ bd update PrintMines-f3 --parent PrintMines-abc
```

**Review Verdict: FAIL ❌**

```
Review verdict: FAIL

Issues found:
- 1 P0 (critical) ticket
- 1 P1 (major) ticket
- 1 P2 (moderate) ticket

Blocking tickets:
- PrintMines-f1: Fix WebSocket timeout test failures
- PrintMines-f2: Add YARD documentation to MonitorService
- PrintMines-f3: Add error logging to exception handlers

Original task (PrintMines-abc) keeps ready-for-review label but is now
blocked by dependencies. Fix tickets appear in: bd ready
```

---

## Example 2: Verification After Fixes

### Developer: "I fixed all the issues, ready for re-review?"

**Step 1: Check review status**
```bash
$ ruby scripts/check_review_status.rb

✅ Tasks Ready for Review (0)

⏳ Tasks Awaiting Fixes (1)
  • PrintMines-abc: Add printer fleet monitoring
    Blocked by:
      ✅ PrintMines-f1: Fix WebSocket timeout test failures (closed)
      ❌ PrintMines-f2: Add YARD documentation to MonitorService (open)
      ✅ PrintMines-f3: Add error logging to exception handlers (closed)

Next steps:
  1. Work on blocking tickets (they appear in: bd ready)
  2. Re-run this check after closing blockers
```

**Developer fixes the remaining issue**

```bash
$ bd close PrintMines-f2
```

**Step 2: Check review status again**

```bash
$ ruby scripts/check_review_status.rb

✅ Tasks Ready for Review (1)
  • PrintMines-abc: Add printer fleet monitoring

⏳ Tasks Awaiting Fixes (0)

Next steps:
  ruby scripts/get_task_for_review.rb
```

**Step 3: Review the fixes**

```bash
$ ruby scripts/get_task_for_review.rb
# Shows PrintMines-abc again

$ bash scripts/review-suite.sh
✅ All tests pass
✅ No linting errors
✅ No security issues
```

**Step 4: Approve the task**

```bash
$ ruby scripts/approve_task.rb PrintMines-abc

============================================================
TASK APPROVED
============================================================

Closed: PrintMines-abc
Added label: review-passed

✓ Review passed! Task is complete.
============================================================
```

**Review Verdict: APPROVED ✅**

---

## Example 3: Full Approval (No Issues Found)

### Developer: "Can you review my well-tested feature?"

**Step 1: Check review status**
```bash
$ ruby scripts/check_review_status.rb

✅ Tasks Ready for Review (1)
  • PrintMines-xyz: Implement order sync scheduler

⏳ Tasks Awaiting Fixes (0)
```

**Step 2: Get task and review**
```bash
$ ruby scripts/get_task_for_review.rb
# Shows PrintMines-xyz details

$ bash scripts/review-suite.sh
✅ RuboCop: 0 offenses
✅ Brakeman: 0 warnings
✅ ESLint: 0 errors
✅ Tests: All passing (42 runs, 0 failures)
```

**Step 3: Manual review - everything looks good!**

Agent verifies:
- ✅ Tests cover new logic (schedule creation, error handling, edge cases)
- ✅ YARD documentation present on all public methods
- ✅ Error handling appropriate with proper logging
- ✅ SOLID principles followed (single responsibility maintained)
- ✅ No security issues (no SQL injection, proper input validation)

**Step 4: Approve immediately**

```bash
$ ruby scripts/approve_task.rb PrintMines-xyz

============================================================
TASK APPROVED
============================================================

Closed: PrintMines-xyz
Added label: review-passed

✓ Review passed! Task is complete.
============================================================
```

**Review Verdict: APPROVED ✅**

```
✅ Code Review: PASS

Summary:
- All tests pass (42 runs, 0 failures)
- Test coverage added for new functionality
- YARD documentation complete
- No security vulnerabilities
- SOLID principles maintained
- Code matches architecture patterns

🎉 Code is ready for merge/deployment!

No blocking issues found.
```

---

## Example 4: Review Uncommitted Changes

### Developer: "Can you review my uncommitted work?"

**Step 1: Check uncommitted changes**
```bash
$ ruby scripts/get_uncommitted_changes.rb

📊 Uncommitted Changes Summary
============================================================

Total files changed: 4
  • Staged:    3
  • Unstaged:  1
  • Untracked: 0

📁 By Category:
  • Ruby: 2 files
  • TypeScript: 1 files
  • Tests: 1 files

📝 Changed Files:
------------------------------------------------------------
  [S] app/services/order_sync_service.rb
  [S] app/javascript/components/orders/SyncButton.tsx
  [S] test/services/order_sync_service_test.rb
  [M] app/models/order.rb

✅ Ready for code review
```

**Step 2: Run static analysis and review**

```bash
$ bash scripts/review-suite.sh
✅ All checks pass
```

**Manual review finds issue:**
- ❌ New `sync_orders` method has no test coverage (P0)

**Step 3: Create ticket (no formal task to block)**

```bash
$ bd create --title "Add test coverage for sync_orders method" \
  --type test \
  --priority 0 \
  --description "New method Order#sync_orders has no test coverage" \
  --acceptance "Add tests for success case, API failure, and timeout handling"

Created PrintMines-t1
```

**Review Verdict: FAIL ❌**

```
Review verdict: FAIL

Issues found:
- 1 P0 (critical) ticket

Tickets created:
- PrintMines-t1: Add test coverage for sync_orders method

Next steps:
  1. Implement the test coverage
  2. Re-request code review when complete
```

---

## Example 5: Multiple Tasks Ready for Review

**Step 1: Check review status**
```bash
$ ruby scripts/check_review_status.rb

✅ Tasks Ready for Review (3)
  • PrintMines-aaa: Add printer status dashboard
  • PrintMines-bbb: Implement inventory tracking
  • PrintMines-ccc: Fix order sync race condition

⏳ Tasks Awaiting Fixes (1)
  • PrintMines-ddd: Add user authentication
    Blocked by:
      ❌ PrintMines-f10: Add session timeout handling (open)
```

**Step 2: Get highest priority task**
```bash
$ ruby scripts/get_task_for_review.rb

Found 3 tasks with ready-for-review label (showing highest priority):

============================================================
TASK READY FOR REVIEW
============================================================

ID: PrintMines-ccc
Title: Fix order sync race condition
Priority: 0 (critical)
Status: open
Labels: ready-for-review, bug

# ... task details ...
```

**Note:** The script automatically shows the highest priority task first.

---

## Workflow Decision Tree

```
Start: User requests code review
  |
  ├─> Run: check_review_status.rb
  |
  ├─> Tasks with ready-for-review label?
  │   |
  │   ├─> YES: Any unblocked?
  │   │   |
  │   │   ├─> YES: Get task with get_task_for_review.rb
  │   │   │        Run static analysis (review-suite.sh)
  │   │   │        Perform manual review
  │   │   │        |
  │   │   │        ├─> Issues found?
  │   │   │        │   |
  │   │   │        │   ├─> YES: Create tickets (bd create)
  │   │   │        │   │        Add dependencies (bd dep add)
  │   │   │        │   │        Keep ready-for-review label
  │   │   │        │   │        → FAIL ❌
  │   │   │        │   │
  │   │   │        │   └─> NO: Approve (approve_task.rb)
  │   │   │        │           Close task + add review-passed
  │   │   │        │           → PASS ✅
  │   │   │        │
  │   │   │        └─> End
  │   │   │
  │   │   └─> NO: All tasks blocked by dependencies
  │   │            Show what's blocking them
  │   │            Next: Fix blocking tickets
  │   │            → WAITING ⏳
  │   │
  │   └─> NO: Check uncommitted changes
  │            get_uncommitted_changes.rb
  │            Review and create tickets as needed
  │            (No formal task to block)
  │
  └─> End
```

---

## Tips

### For Developers

1. **Check review status before starting work**
   - See what's blocked by review findings
   - Prioritize fixing P0/P1 blocking tickets

2. **Close tickets when fixes are complete**
   - Use `bd close <id>` to mark work done
   - Original task automatically unblocks when all dependencies closed

3. **Use proper commit messages**
   - Reference ticket IDs in commits: "Fix timeout handling (closes PrintMines-f1)"

### For Reviewers

1. **Always start with check_review_status.rb**
   - Prevents duplicate reviews
   - Shows which tasks are truly ready (unblocked)
   - Identifies tasks waiting for fixes

2. **Use appropriate issue types**
   - `bug` - Code defects, broken functionality
   - `task` - Work items, improvements, refactoring
   - `documentation` - Missing/incorrect docs
   - `test` - Missing/inadequate test coverage

3. **Set correct priorities**
   - **P0 (0)**: Critical - security, data loss, no tests for core logic
   - **P1 (1)**: Major - SOLID violations, missing docs on public APIs
   - **P2 (2)**: Moderate - maintainability issues, complex methods
   - **P3 (3)**: Standard - general improvements
   - **P4 (4)**: Nit - style, naming, minor refactors

4. **Create blocking dependencies correctly**
   ```bash
   # For each fix ticket, add as blocker to original task
   bd dep add <original-task> <fix-ticket>

   # Optional: Link fix to original for context
   bd update <fix-ticket> --parent <original-task>
   ```

5. **Be specific in ticket descriptions**
   - Bad: "Add more tests"
   - Good: "Add tests for nil user case and timeout handling in UserService#authenticate"
   - Include line numbers when pointing out specific issues
   - Provide code examples or pseudocode when helpful

---

## Common Questions

**Q: What happens to the ready-for-review label when I add blocking dependencies?**

A: The label stays on the task, but it won't appear in `bd ready --label ready-for-review` until all blocking tickets are closed. This is automatic - you don't need to remove the label.

**Q: Can I fix some issues and leave others for later?**

A: Yes! Close the tickets you've fixed. When you re-run `check_review_status.rb`, it will show which blockers remain. The original task stays blocked until all dependencies are resolved.

**Q: What if I disagree with a review finding?**

A: Discuss with the reviewer. Options:
1. Comment on the ticket explaining your position
2. Ask reviewer to downgrade priority or close as won't-fix
3. If it's truly not needed, reviewer can close the ticket

**Q: How do I know which tickets are blocking a review?**

A: Run `bd show <task-id>` to see the `blocked_by` list, or use `check_review_status.rb` which shows all blockers and their status.

**Q: What's the difference between parent and blocking relationships?**

A:
- **Parent** (`--parent`): Organizational only, for context. Doesn't affect workflow.
- **Blocking** (`bd dep add`): Workflow enforcement. Blocks task from appearing in `bd ready`.

**Q: Can I have multiple tasks in review at once?**

A: Yes! Each task independently tracks its own blocking dependencies. `check_review_status.rb` shows all tasks and their individual status.

---

## Beads Commands Quick Reference

### Finding Work
```bash
bd ready --label ready-for-review    # Tasks ready for review (unblocked)
bd list --status open --label ready-for-review  # All review tasks (includes blocked)
bd show <id>                          # Detailed view with dependencies
```

### Creating Issues
```bash
bd create --title "..." --type bug|task|documentation|test --priority 0-4
```

### Dependencies
```bash
bd dep add <parent-id> <blocker-id>   # parent depends on blocker
bd dep remove <parent-id> <blocker-id>  # Remove dependency
```

### Closing Tasks
```bash
bd close <id>                         # Close single task
bd close <id1> <id2> <id3>           # Close multiple (more efficient)
```

### Updating Tasks
```bash
bd update <id> --parent <parent-id>   # Add parent relationship
bd update <id> --parent ""            # Remove parent
bd update <id> --add-label review-passed  # Add label
```

---

## Integration with Other Skills

### With task-implementer

```bash
# task-implementer picks next ready task
$ ruby .agent/skills/task-implementer/scripts/start_next_task.rb

# Implements the fix
# Marks complete with ready-for-review label

# Reviewer verifies
$ ruby scripts/check_review_status.rb
```

### With test-and-commit

```bash
# After implementing fix, run smart test runner
$ ruby .agent/skills/test-and-commit/scripts/smart_test_runner.rb

# If tests pass, commit and close ticket
$ git commit -m "Fix timeout handling (closes PrintMines-f1)"
$ bd close PrintMines-f1
```

---

## Script Behavior

### check_review_status.rb

**Shows:**
- Tasks with `ready-for-review` label that are unblocked (ready NOW)
- Tasks with `ready-for-review` label that are blocked (awaiting fixes)
- For blocked tasks: what's blocking them and blocker status

**Exit codes:**
- `0` - Success (tasks found or none available)
- Non-zero - Error

### get_task_for_review.rb

**Shows:**
- All unblocked tasks with `ready-for-review` label
- Highest priority task first
- Full task details for review

**Exit codes:**
- `0` - Success (tasks found or none available)

### approve_task.rb

**Does:**
- Closes the specified task
- Adds `review-passed` label
- Confirms approval

**Usage:**
```bash
ruby scripts/approve_task.rb <task-id>
# OR
ruby scripts/approve_task.rb  # Prompts for highest priority task
```

---

## Labels Used

### Workflow Labels
- `ready-for-review` - Task awaits code review (may be blocked by dependencies)
- `review-passed` - Code review approved, task closed

### Type Labels (automatic from issue type)
- `bug` - Defects and broken functionality
- `task` - Work items and improvements
- `documentation` - Documentation issues
- `test` - Test coverage issues
- `feature` - New features
- `epic` - Large multi-task initiatives

### Priority Labels (automatic from priority)
- `critical` - P0 issues
- `major` - P1 issues
- `moderate` - P2 issues
- Standard - P3 (no label)
- Backlog - P4 (no label)
