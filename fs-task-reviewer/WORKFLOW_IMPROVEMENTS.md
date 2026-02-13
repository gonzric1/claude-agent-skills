# Workflow Improvements - 2026-02-12

This document describes recent improvements to the fs-task-reviewer workflow to reduce time spent on non-essential polish work.

## Problem Statement

Analysis of 169 closed issues revealed:
- 22.5% of all tasks were documentation-related
- 71% of P1 (high-priority) tasks were documentation tasks
- 15 documentation tasks were over-prioritized as P0-P2 when they should have been P3-P4
- Excessive time spent on polish work instead of shipping features

## Solutions Implemented

### 1. Updated Priority Guidelines

**Key Change**: Distinguish between NEW code (just written) vs EXISTING code (already there)

**New Priority Mapping**:
- **P0**: Blocks build/deploy (compilation errors, security, missing tests for NEW logic)
- **P1**: Correctness/Architecture (logic bugs, SOLID violations in NEW code, docs for NEW public APIs)
- **P2**: Quality/Maintainability (complex methods, docs for NEW internal methods)
- **P3**: Polish/Improvement (docs for EXISTING code, general improvements)
- **P4**: Cosmetic (style, typos, adding examples to existing docs)

**Decision Tree**: Added a 4-step decision tree for documentation prioritization:
1. Does it compile? (No → P0)
2. Is this NEW code? (No → P3 polish)
3. Public API or internal? (Internal → P3 polish)
4. Critical integration? (Yes → P1, No → P2)

### 2. Real-World Prioritization Examples

Added concrete scenarios showing how to apply guidelines:
- NEW feature implementation (P0-P1 for tests/docs)
- Bug fixes (P3 for existing code docs)
- UI components (P2 for new components, P3 for existing)
- Documentation-only changes (P3-P4)

### 3. Auto-Labeling Enhancement

**Script**: `create_fix_ticket.rb`

Automatically adds "documentation" label to tickets that match documentation keywords:
- YARD, TSDoc, JSDoc
- @see, @param, @return, @example
- "Add docs", "Update docs"

**Benefits**:
- Easy filtering: `bd list --label documentation`
- Better tracking of documentation debt
- Can prioritize or defer doc work as a category

### 4. Polish Backlog Manager

**Script**: `scripts/polish_backlog.rb`

New tool for managing P3-P4 non-blocking polish work:

```bash
# Show all polish tasks
ruby scripts/polish_backlog.rb

# Show top 10 by priority
ruby scripts/polish_backlog.rb --limit 10

# Filter by type
ruby scripts/polish_backlog.rb --type documentation

# Statistics only
ruby scripts/polish_backlog.rb --stats
```

**Features**:
- Shows all tasks labeled 'polish'
- Sorts by priority (P3 before P4) then by age
- Groups by type (documentation, bug, task, test)
- Provides statistics and recommendations
- Suggests batching strategies

**Usage Pattern**:
1. Schedule dedicated polish time (e.g., "Polish Friday")
2. Run `polish_backlog.rb --limit 5` to get top items
3. Batch similar work together (all docs, then all refactoring)
4. Complete 3-5 tasks per session when no feature work is blocked

## Expected Impact

Based on analysis of historical data:

**Metrics**:
- Documentation tasks: 22.5% → 10% (55% reduction)
- P1 documentation tasks: 71% → 20% (72% reduction)
- Feature completion time: 30-40% improvement
- Polish backlog visibility: 100% (was invisible before)

**Workflow Benefits**:
- Developers work on blocking issues first
- Polish work is scheduled deliberately, not ad-hoc
- Feature velocity improves significantly
- Quality standards maintained for NEW code

## Migration Notes

**For Existing Projects**:

1. **Update SKILL.md**: Changes are in global repo, automatically propagated via symlinks
2. **Re-train Agents**: Review agents should read new guidelines on next invocation
3. **Re-prioritize Open Tasks**: Consider running retrospective on open P1-P2 documentation tasks
4. **Schedule Polish Time**: Add weekly or bi-weekly polish sessions to workflow

**For Existing Polish Tasks**:

```bash
# Find existing high-priority doc tasks that should be downgraded
bd list --status open --label documentation | grep P1

# Downgrade to P3 and add polish label
bd update <task-id> --priority 3 --add-label polish

# Remove blocking dependency if needed
bd dep remove <parent-id> <doc-task-id>
```

## Additional Workflow Recommendations

### 1. Priority Budgets (Future Enhancement)

Limit review findings per review:
- Max 3 P0 findings (forces prioritization)
- Max 5 P1 findings
- Unlimited P3-P4

### 2. Review Metrics Dashboard (Future Enhancement)

Track:
- Average findings per review
- P0-P2 vs P3-P4 ratio
- Time to resolution by priority
- Polish backlog size over time

### 3. Polish Friday Pattern

Recommended weekly schedule:
- Monday-Thursday: Feature work (P0-P2 only)
- Friday: Polish work (pick 3-5 from `polish_backlog.rb`)

## Scripts Reference

### create_fix_ticket.rb

**Enhanced with**:
- Auto-labeling for documentation tasks
- Better output showing label assignments

**Usage unchanged**:
```bash
ruby scripts/create_fix_ticket.rb <parent-id> \
  --title "Add YARD docs" --type documentation --priority 3 \
  --description "..." --acceptance "..."
```

### polish_backlog.rb (NEW)

**Purpose**: Manage and prioritize polish tasks

**Options**:
- `--limit N`: Show top N tasks
- `--type TYPE`: Filter by type
- `--stats`: Statistics only

**Examples**:
```bash
# Quick check
ruby scripts/polish_backlog.rb --limit 5

# Documentation polish only
ruby scripts/polish_backlog.rb --type documentation

# Full backlog with stats
ruby scripts/polish_backlog.rb
```

## Monitoring Success

**Weekly Check-In Questions**:
1. How many P0-P2 review findings this week?
2. How many were documentation vs code quality?
3. How many features shipped vs previous week?
4. Is polish backlog growing or shrinking?

**Red Flags**:
- P1 documentation tasks > 30% of review findings
- Polish backlog growing faster than completion rate
- Feature velocity not improving after 2 weeks

**Green Flags**:
- P3-P4 tasks are 50%+ of review findings
- Features shipping faster
- Polish work scheduled and completed regularly
- Team understands NEW vs EXISTING distinction

## Rollback Plan

If the new guidelines cause issues:

1. **Revert SKILL.md**: Restore from git history
2. **Re-prioritize Tasks**: Upgrade P3-P4 tasks back to P1-P2 if needed
3. **Document Issues**: Create GitHub issue with specific problems
4. **Iterate**: Adjust guidelines based on feedback

## Related Documents

- `.agent/logs/task-prioritization-analysis-2026-02-12.md` - Original analysis
- `SKILL.md` - Updated skill definition
- `scripts/create_fix_ticket.rb` - Enhanced ticket creation
- `scripts/polish_backlog.rb` - New polish management tool
