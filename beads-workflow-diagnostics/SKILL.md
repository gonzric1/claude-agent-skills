---
name: beads-workflow-diagnostics
description: 'Diagnoses beads workflow inconsistencies where bd ready shows issues but task-implementer and fs-task-reviewer report nothing available. Detects stuck states, label conflicts, and orphaned dependencies.'
compatibility: 'Ruby 3.x, beads CLI'
---

# beads-workflow-diagnostics

## When to use this skill

Use this skill when experiencing beads workflow anomalies:
- `bd ready` shows issues but agents report "nothing available"
- Issues are stuck without any agent working on them
- Labels seem inconsistent with issue state
- Dependencies appear orphaned or circular
- Need to audit the entire workflow state

## Step-by-step instructions

1. Run the main diagnostic: `ruby [[ @scripts/diagnose.rb ]]`
   - Checks for label conflicts
   - Identifies orphaned parent relationships
   - Detects issues stuck in_progress with no recent activity
   - Finds circular dependencies
   - Reports issues that should be in `bd ready` but aren't

2. Review the output for specific issues:
   - **Label Conflicts**: Issues with incompatible labels
   - **Orphaned Parents**: Review issues referencing deleted/closed parents
   - **Stuck Issues**: Issues in_progress for >24h without updates
   - **Dependency Problems**: Circular or invalid dependencies

3. Use fix scripts as needed:
   - `ruby [[ @scripts/fix_dependencies.rb ]]` - Remove invalid dependency references (MOST COMMON)
   - `ruby [[ @scripts/fix_labels.rb ]]` - Auto-fix label conflicts
   - `ruby [[ @scripts/fix_parents.rb ]]` - Clean orphaned parent relationships
   - Add `--dry-run` flag to preview changes without making them
   - Manual intervention may be required for complex cases

4. Verify fix with `bd ready` and rerun diagnostic

5. View audit logs to understand what changed:
   - `ruby [[ @scripts/view_audit_logs.rb ]]` - View latest log with full details
   - `ruby [[ @scripts/view_audit_logs.rb ]] --all` - View all historical logs
   - `ruby [[ @scripts/view_audit_logs.rb ]] --issue <id>` - View logs for specific issue

## Technical Details

**Scripts:**
- `diagnose.rb` - Main diagnostic that checks all workflow invariants
- `fix_dependencies.rb` - Removes dependencies pointing to closed/deleted issues (most common fix)
- `fix_labels.rb` - Fixes label conflicts automatically
- `fix_parents.rb` - Removes orphaned parent relationships
- `audit_logger.rb` - Comprehensive logging module (used by fix scripts)
- `view_audit_logs.rb` - View audit logs from previous fixes

All fix scripts support `--dry-run` flag to preview changes.

**Audit Logging:**
All fix scripts now create comprehensive audit logs in `.agent/logs/beads-diagnostics/`:
- JSONL format (one JSON object per line)
- Captures what changed, why it changed, and the history of affected beads
- Includes before/after state of each issue
- Records bd comments and git history for each affected bead
- Timestamp and success/failure tracking

View logs:
```bash
ruby scripts/view_audit_logs.rb                     # Show latest log
ruby scripts/view_audit_logs.rb --all               # Show all logs
ruby scripts/view_audit_logs.rb --issue PrintMines-123  # Logs for specific issue
ruby scripts/view_audit_logs.rb --all --verbose     # Detailed view of all logs
```

**Workflow Invariants Checked:**
1. No incompatible label combinations
2. Review issues must have valid parent references (not deleted/closed)
3. Issues `in_progress` should have recent activity (last 24h)
4. No circular dependencies
5. No invalid dependency references (pointing to deleted issues)
6. Issues in `bd ready` must match expected criteria (open, no blockers, no assignee, no special labels)

**Known Limitations:**
- Cannot query active Claude Code agent sessions to check if work is in progress
- "Stuck" detection relies on `updated_at` timestamp, not actual agent activity
- If agents are working but haven't committed, issues appear stuck
- Workaround: Check for uncommitted changes with `git status` before concluding work is truly stuck

**Exit Codes:**
- 0: No issues detected
- 1: Issues detected (details in output)
- 2: Script error

**Common Issues Found:**
1. **Invalid Dependencies**: Issues referencing deleted/closed blockers - prevents proper `bd ready` calculation
2. **Label Conflicts**: Incompatible label combinations (currently none defined)
3. **Orphaned Parents**: Review issues with parent_issue_id pointing to closed/deleted tasks
4. **Ready Queue Mismatch**: Issues should be in `bd ready` but aren't (usually due to invalid dependencies)

**Audit Log Format:**
Each fix creates a JSONL log file with entries:
- `session_start`: Fix session metadata (fix type, timestamp)
- Fix entries: One per issue fixed, includes:
  - `issue_id`, `issue_title`: What was fixed
  - `problem`: Why it needed fixing
  - `action`: What action was taken
  - `details`: Additional context (e.g., which labels removed)
  - `before_state`: Issue state before fix (status, labels, dependencies)
  - `after_state`: Issue state after fix
  - `history`: Comprehensive bead history:
    - `comments`: bd comments on the issue
    - `git_log`: git commits mentioning the issue
    - `bd_show`: Full issue details from bd
- `result` entries: Success/failure of each fix
- `summary`: Session summary (total fixes, successes, failures, issues affected)

Logs are persisted to `.agent/logs/beads-diagnostics/` and committed to git for historical analysis.