# Beads Workflow Diagnostics

Diagnoses and fixes inconsistencies in beads workflow where `bd ready` shows issues but agents report "nothing available to work on".

## Quick Start

```bash
# 1. Run diagnostic
ruby scripts/diagnose.rb

# 2. Fix issues automatically
ruby scripts/fix_dependencies.rb
ruby scripts/fix_labels.rb
ruby scripts/fix_parents.rb

# 3. Sync changes
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

## Workflow Invariants Checked

The diagnostic verifies:

1. ✅ **Label Conflicts**: No incompatible label combinations
2. ✅ **Orphaned Parents**: Review issues only reference open parent issues
3. ✅ **Stuck Issues**: No issues in_progress for >24h without updates
4. ❌ **Valid Dependencies**: Dependencies only point to open issues
5. ❌ **Ready Queue Consistency**: All ready issues appear in `bd ready`

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

## After Running Fixes

1. Verify fixes worked:
   ```bash
   ruby scripts/diagnose.rb
   ```

2. Check `bd ready` now shows correct issues:
   ```bash
   bd ready
   ```

3. Sync changes to remote:
   ```bash
   bd sync
   ```

4. Agents should now find work:
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

## Exit Codes

- `0` - No issues detected, workflow is healthy
- `1` - Issues detected (see output for details)
- `2` - Script error (failed to run bd commands)
