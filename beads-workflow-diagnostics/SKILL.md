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

## Technical Details

**Scripts:**
- `diagnose.rb` - Main diagnostic that checks all workflow invariants
- `fix_dependencies.rb` - Removes dependencies pointing to closed/deleted issues (most common fix)
- `fix_labels.rb` - Fixes label conflicts automatically
- `fix_parents.rb` - Removes orphaned parent relationships

All fix scripts support `--dry-run` flag to preview changes.

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