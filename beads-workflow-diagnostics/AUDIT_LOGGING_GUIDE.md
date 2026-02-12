# Beads Workflow Diagnostics - Audit Logging Guide

## Overview

The beads-workflow-diagnostics skill now includes comprehensive audit logging that captures:
- **What** tickets were changed
- **Why** they were changed (the problem detected)
- **How** they were changed (the fix applied)
- **History** of each affected bead (comments, git log, dependencies)

## Features

### Automatic Logging

All fix scripts now automatically log their actions:
- `fix_dependencies.rb` - Logs removed dependencies and why
- `fix_labels.rb` - Logs removed labels and conflicts
- `fix_parents.rb` - Logs removed parent relationships

### Rich History Capture

For each affected bead, the logger captures:

1. **bd Comments** - Using `bd comments <id> --json`
2. **Git History** - Commits mentioning the issue ID
3. **bd Show Data** - Full issue details from `bd show <id> --json`
4. **Before/After State**:
   - Status
   - Labels
   - Dependencies
   - Assignee
   - Metadata

### JSONL Format

Logs use JSONL (JSON Lines) format for easy parsing and analysis:

```jsonl
{"timestamp":"2026-02-12T14:30:21Z","type":"session_start","fix_type":"fix_dependencies"}
{"timestamp":"2026-02-12T14:30:22Z","issue_id":"PrintMines-abc","problem":"...","action":"..."}
{"timestamp":"2026-02-12T14:30:23Z","issue_id":"PrintMines-abc","type":"result","success":true}
{"timestamp":"2026-02-12T14:30:24Z","type":"summary","total_fixes":3,"successful":3}
```

## Usage

### Running Fixes with Logging

```bash
# Run fix (logging happens automatically)
ruby .agent/skills/beads-workflow-diagnostics/scripts/fix_dependencies.rb

# Output shows log file location:
# 📝 Audit log written to: .agent/logs/beads-diagnostics/fix_dependencies_20260212_143021.jsonl
```

### Viewing Audit Logs

```bash
# View latest log with full details
ruby .agent/skills/beads-workflow-diagnostics/scripts/view_audit_logs.rb

# View all historical logs (summary mode)
ruby .agent/skills/beads-workflow-diagnostics/scripts/view_audit_logs.rb --all

# Detailed view of all logs
ruby .agent/skills/beads-workflow-diagnostics/scripts/view_audit_logs.rb --all --verbose

# View logs for specific issue
ruby .agent/skills/beads-workflow-diagnostics/scripts/view_audit_logs.rb --issue PrintMines-123
```

### Example Output

```
📋 Latest Audit Log: fix_dependencies_20260212_143021.jsonl
   Last modified: 2026-02-12 14:30:21
================================================================================

Fix Type: fix_dependencies
Started: 2026-02-12 14:30:21

Summary:
  Total fixes: 3
  Successful: 3
  Issues affected: PrintMines-9mi, PrintMines-dyp, PrintMines-ha4

Detailed Fixes:
--------------------------------------------------------------------------------

🔧 PrintMines-9mi: Update ProductMappingDashboard to show variation information
   Time: 2026-02-12 14:30:22

   Problem: Invalid dependency references to closed/deleted issues
   Action: Remove 2 invalid blocker(s): PrintMines-b2b, PrintMines-69o

   Details:
     invalid_blockers: PrintMines-b2b (closed), PrintMines-69o (closed)
     blocker_count: 2

   Before State:
     Status: open
     Labels: component, frontend, react
     Dependencies: 2
     Assignee: none

   After State:
     Status: open
     Labels: component, frontend, react
     Dependencies: 0

   History:
     Comments (0):
       (no comments)

     Git History (5 commits):
       - 2026-02-11 15:30:45: feat(ProductMappingDashboard): add variation display
       - 2026-02-11 14:20:12: docs: update product mapping documentation
       - 2026-02-10 16:45:30: chore(beads): create ProductMappingDashboard task
       ... and 2 more

   Result: ✅ Successfully removed 2 dependency(ies)
   ----------------------------------------------------------------------------
```

## Log Entry Types

### 1. Session Start

```json
{
  "timestamp": "2026-02-12T14:30:21Z",
  "type": "session_start",
  "fix_type": "fix_dependencies",
  "log_file": ".agent/logs/beads-diagnostics/fix_dependencies_20260212_143021.jsonl"
}
```

### 2. Fix Entry

```json
{
  "timestamp": "2026-02-12T14:30:22Z",
  "issue_id": "PrintMines-9mi",
  "issue_title": "Update ProductMappingDashboard",
  "problem": "Invalid dependency references to closed/deleted issues",
  "action": "Remove 2 invalid blocker(s): PrintMines-b2b, PrintMines-69o",
  "details": {
    "invalid_blockers": [
      {"blocker_id": "PrintMines-b2b", "status": "closed"},
      {"blocker_id": "PrintMines-69o", "status": "closed"}
    ],
    "blocker_count": 2
  },
  "before_state": {
    "status": "open",
    "labels": ["component", "frontend", "react"],
    "dependencies": [...],
    "assignee": null
  },
  "history": {
    "comments": [],
    "git_log": [...],
    "bd_show": {...}
  }
}
```

### 3. Result Entry

```json
{
  "timestamp": "2026-02-12T14:30:23Z",
  "issue_id": "PrintMines-9mi",
  "type": "result",
  "success": true,
  "message": "Successfully removed 2 dependency(ies)",
  "after_state": {
    "status": "open",
    "labels": ["component", "frontend", "react"],
    "dependencies": [],
    "assignee": null
  }
}
```

### 4. Summary Entry

```json
{
  "timestamp": "2026-02-12T14:30:24Z",
  "type": "summary",
  "fix_type": "fix_dependencies",
  "total_fixes": 3,
  "successful": 3,
  "failed": 0,
  "issues_affected": ["PrintMines-9mi", "PrintMines-dyp", "PrintMines-ha4"]
}
```

## Analyzing Patterns

Use audit logs to identify patterns in workflow issues:

```bash
# Find issues that are frequently problematic
grep -h '"issue_id"' .agent/logs/beads-diagnostics/*.jsonl | \
  sort | uniq -c | sort -rn | head -10

# Find most common problem types
grep -h '"problem"' .agent/logs/beads-diagnostics/*.jsonl | \
  sort | uniq -c | sort -rn

# Count fixes by type
ls -1 .agent/logs/beads-diagnostics/ | \
  sed 's/_[0-9]*.jsonl//' | sort | uniq -c
```

## Dry Run Mode

Fix scripts support `--dry-run` which **disables logging** (no changes = no log):

```bash
# Preview changes without logging
ruby scripts/fix_dependencies.rb --dry-run
```

## Log Retention

Audit logs are committed to git and retained indefinitely. This provides:
- Historical context for debugging
- Pattern analysis over time
- Audit trail for workflow changes

To clean old logs:

```bash
# Archive logs older than 30 days
find .agent/logs/beads-diagnostics -name "*.jsonl" -mtime +30 \
  -exec gzip {} \;
```

## Troubleshooting

### No log file created

**Cause**: Dry-run mode was used, or no fixes were applied

**Solution**: Run without `--dry-run`, ensure issues were detected

### Missing history data

**Cause**: bd commands failed or issue doesn't exist

**Solution**: Check that `bd show <id>` works for the issue

### Cannot parse JSONL

**Cause**: Corrupted log file

**Solution**: Each line must be valid JSON. Use `jq` to validate:

```bash
cat log.jsonl | jq -c '.' > validated.jsonl
```

## Integration with Debugging Workflow

When recurring issues occur:

1. Run `/beads-workflow-diagnostics` to detect and fix issues
2. View audit log: `ruby scripts/view_audit_logs.rb`
3. Analyze patterns: Which issues are repeatedly problematic?
4. Investigate root cause:
   - Check git history of affected beads
   - Review comments for context
   - Look for dependency patterns
5. Fix underlying workflow issue (helper scripts, process changes)

## Future Enhancements

Potential additions to audit logging:

- Statistics dashboard showing fix frequency over time
- Automated pattern detection (e.g., "PrintMines-xyz has been fixed 5 times")
- Integration with `bd audit` for unified audit trail
- Export to CSV for spreadsheet analysis
- Slack/email notifications on repeated fixes
