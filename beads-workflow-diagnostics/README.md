# Beads Workflow Diagnostics

Diagnoses and fixes inconsistencies in beads workflow where `bd ready` shows issues but agents report "nothing available to work on".

## Quick Start

```bash
# 1. Run diagnostic
ruby scripts/diagnose.rb

# 2. Fix issues automatically (creates audit logs)
ruby scripts/fix_dependencies.rb
ruby scripts/fix_labels.rb
ruby scripts/fix_parents.rb

# 3. View audit log to see what was fixed
ruby scripts/view_audit_logs.rb

# 4. Sync changes
bd sync
```

## The Problem

You experienced a state where:
- `bd ready` showed many issues
- `task-implementer` reported nothing available
- `fs-task-reviewer` reported nothing available
- No agents were actively working

This state occurs when workflow invariants are violated.

## Root Cause Analysis

The diagnostic found **2 problems** in your workflow:

### 1. Invalid Dependency References (3 issues)

**What happened:**
- `PrintMines-9mi`, `PrintMines-dyp`, and `PrintMines-ha4` were blocked by **closed issues**
- `PrintMines-b2b` (closed) was blocking 2 issues
- `PrintMines-69o` (closed) was blocking 1 issue

**Why this breaks the workflow:**
- These issues appear "blocked" in dependency graph
- `bd ready` filters them out (has blockers)
- But the blockers are actually complete (closed)
- So the issues should be ready, but aren't

**Fix:**
```bash
ruby scripts/fix_dependencies.rb
```

This removes dependencies pointing to closed/deleted issues.

### 2. Ready Queue Inconsistency (1 issue)

**What happened:**
- `PrintMines-57m` should be in `bd ready` (no blockers, no assignee, status=open)
- But it wasn't showing up in the queue

**Why this happens:**
- Usually caused by invalid dependencies (see above)
- After fixing dependencies, this should resolve automatically

## Understanding the Ready Queue

**IMPORTANT**: Tasks with `ready-for-review` labels ARE expected to appear in `bd ready`.

### How Agents Filter Work

Both `task-implementer` and `fs-task-reviewer` use `bd ready` as their starting point:

**task-implementer workflow:**
1. Gets all tasks from `bd ready --json`
2. **Filters OUT** tasks with `ready-for-review` label (client-side)
3. Works on remaining implementation tasks

**fs-task-reviewer workflow:**
1. Gets tasks with `bd list --status open --label ready-for-review --json`
2. These tasks also appear in `bd ready` (open + no blockers)
3. Works on review tasks

**Why this design:**
- `bd ready` is the single source of truth for "unblocked work"
- Agents apply their own filters to find their specific work type
- Tasks waiting for review are technically "ready" (ready for review, not implementation)

## Workflow Invariants Checked

The diagnostic verifies:

1. ✅ **Label Conflicts**: No incompatible label combinations
2. ✅ **Orphaned Parents**: Review issues only reference open parent issues
3. ✅ **Stuck Issues**: No issues in_progress for >24h without updates
4. ✅ **Stuck Review Claims**: No review claims in_progress for >24h
5. ❌ **Valid Dependencies**: Dependencies only point to open issues
6. ❌ **Ready Queue Consistency**: All unblocked issues appear in `bd ready`

## Fix Scripts

All scripts support `--dry-run` for safe preview:

### fix_dependencies.rb (MOST COMMON)

Removes dependencies that point to closed or deleted issues.

```bash
# Preview changes
ruby scripts/fix_dependencies.rb --dry-run

# Apply fixes
ruby scripts/fix_dependencies.rb
```

### fix_labels.rb

Removes conflicting labels based on priority rules (currently none defined).

```bash
ruby scripts/fix_labels.rb --dry-run
ruby scripts/fix_labels.rb
```

### fix_parents.rb

Removes `parent_issue_id` metadata from review issues when parent is closed/deleted.

```bash
ruby scripts/fix_parents.rb --dry-run
ruby scripts/fix_parents.rb
```

## Known Limitations

### Cannot Detect Active Agent Sessions

The diagnostic **cannot** query Claude Code to see if agents are actively working on issues.

**Workaround:**
```bash
# Check for uncommitted work
git status

# If clean, then work is truly stuck
# If dirty, agents may be working but haven't committed yet
```

**"Stuck" Detection:**
- Based on `updated_at` timestamp (last 24h)
- Doesn't reflect actual agent activity
- False positives if agents haven't committed recent work

## Audit Logging

All fix scripts create comprehensive audit logs in `.agent/logs/beads-diagnostics/`:

- **Format**: JSONL (one JSON object per line)
- **Content**: What changed, why it changed, before/after state
- **History**: bd comments and git history for each affected bead
- **Tracking**: Success/failure status for each fix

### View Audit Logs

```bash
# Show latest log with full details
ruby scripts/view_audit_logs.rb

# Show all historical logs
ruby scripts/view_audit_logs.rb --all

# Show logs for a specific issue
ruby scripts/view_audit_logs.rb --issue PrintMines-123

# Detailed view of all logs
ruby scripts/view_audit_logs.rb --all --verbose
```

Each log entry includes:
- Issue ID and title
- Problem detected
- Action taken
- Before/after state (status, labels, dependencies)
- bd comments on the issue
- Git commits mentioning the issue
- Success/failure result

## After Running Fixes

1. View audit log to understand what changed:
   ```bash
   ruby scripts/view_audit_logs.rb
   ```

2. Verify fixes worked:
   ```bash
   ruby scripts/diagnose.rb
   ```

3. Check `bd ready` now shows correct issues:
   ```bash
   bd ready
   ```

4. Sync changes to remote:
   ```bash
   bd sync
   ```

5. Agents should now find work:
   - `task-implementer` skill should pick up implementation tasks
   - `fs-task-reviewer` skill should pick up review tasks

## Preventing Future Issues

1. **Always close blockers before they're marked closed:**
   ```bash
   # Check what's blocked before closing
   bd show <issue-id>

   # Remove dependencies first
   bd dep remove <blocked-issue> <issue-id>

   # Then close
   bd close <issue-id>
   ```

2. **Use helper scripts instead of raw `bd` commands:**
   - `ruby .agent/skills/task-implementer/scripts/start_next_task.rb`
   - `ruby .agent/skills/task-implementer/scripts/complete_task.rb`
   - `ruby .agent/skills/fs-task-reviewer/scripts/approve_task.rb`

   These scripts handle dependency cleanup automatically.

3. **Run diagnostic periodically:**
   ```bash
   # Add to daily workflow
   ruby scripts/diagnose.rb
   ```

## Technical Details

**Data Sources:**
- `bd export` - JSONL format (one JSON object per line)
- `bd ready` - Plain text output (parsed with regex)

**Dependency Format:**
Dependencies stored as array in `bd export`:
```json
{
  "dependencies": [
    {
      "issue_id": "PrintMines-9mi",
      "depends_on_id": "PrintMines-b2b",
      "type": "blocks"
    }
  ]
}
```

**Status Values:**
- `open` - Active issue
- `closed` - Completed/rejected issue
- `in_progress` - Currently being worked (not used in this diagnostic)

## Scripts

- **diagnose.rb** - Main diagnostic script
- **fix_dependencies.rb** - Auto-fix invalid dependencies (with audit logging)
- **fix_labels.rb** - Auto-fix label conflicts (with audit logging)
- **fix_parents.rb** - Auto-fix orphaned parent relationships (with audit logging)
- **check_and_fix.rb** - All-in-one auto-fix (called by skill)
- **audit_logger.rb** - Comprehensive logging module (used by all fix scripts)
- **view_audit_logs.rb** - View and analyze audit logs

## Exit Codes

- `0` - No issues detected, workflow is healthy (or fixes successfully applied)
- `1` - Issues detected (see output for details)
- `2` - Script error (failed to run bd commands)
