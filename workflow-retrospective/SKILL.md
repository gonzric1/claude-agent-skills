---
name: workflow-retrospective
description: Analyzes the entire development pipeline (planning, implementation, code review, and retrospective) to identify inefficiencies, bottlenecks, and optimization opportunities. Generates actionable recommendations for improving workflow velocity and quality.
---

# Workflow Retrospective

## Purpose

This skill performs a comprehensive analysis of your development workflow to identify inefficiencies and recommend optimizations. It examines:

1. **Planning Phase**: Ticket creation, priority distribution, dependency management
2. **Implementation Phase**: Task-implementer performance, completion rates, blocked tasks
3. **Review Phase**: fs-task-reviewer findings, approval rates, common issues
4. **Meta-Analysis**: The retrospective process itself

## When to Use This Skill

- **Periodic Reviews**: Run weekly, bi-weekly, or monthly to track workflow health
- **After Major Changes**: Validate that workflow improvements are having the desired effect
- **When Velocity Drops**: Diagnose slowdowns in feature delivery
- **Before Sprint Planning**: Understand current bottlenecks before committing to new work
- **After Workflow Changes**: Measure impact of process improvements (like the priority guideline changes)

## Quick Start

```bash
# Full retrospective analysis
ruby [[ @scripts/analyze_pipeline.rb ]]

# Specific phase analysis
ruby [[ @scripts/analyze_pipeline.rb ]] --phase planning
ruby [[ @scripts/analyze_pipeline.rb ]] --phase implementation
ruby [[ @scripts/analyze_pipeline.rb ]] --phase review

# Time-bounded analysis
ruby [[ @scripts/analyze_pipeline.rb ]] --since "2026-02-01"
ruby [[ @scripts/analyze_pipeline.rb ]] --last 7  # Last 7 days
ruby [[ @scripts/analyze_pipeline.rb ]] --last 30 # Last 30 days

# Export for tracking
ruby [[ @scripts/analyze_pipeline.rb ]] --export metrics.json
```

## Workflow

### Step 1: Data Collection

The retrospective analyzes beads issues to extract:
- Issue creation/closure timestamps
- Priority distribution (P0-P4)
- Status transitions (pending → in_progress → ready-for-review → closed)
- Parent-child relationships (review findings)
- Labels (review-finding, review-passed, polish, documentation)
- Blocking dependencies

### Step 2: Phase-Specific Analysis

**Planning Phase Metrics**:
- Ticket creation rate (tickets/week)
- Priority distribution (% of tickets at each priority)
- Dependency graph complexity
- Time from creation to start (planning lag)
- Orphaned tickets (created but never started)

**Implementation Phase Metrics**:
- Average time to complete (by priority)
- Completion rate (closed/created ratio)
- Blocked task count and duration
- Re-work rate (tasks rejected and re-implemented)
- Task abandonment rate (started but never finished)

**Review Phase Metrics**:
- Review findings per task (by priority)
- Approval rate (pass/fail ratio)
- Common issue patterns (documentation, tests, SOLID violations)
- Time from ready-for-review to approval
- Blocking vs non-blocking finding ratio

**Meta-Analysis**:
- Retrospective frequency
- Action item completion rate
- Workflow change impact (before/after)

### Step 3: Bottleneck Identification

The analyzer identifies:
- **High-frequency pain points**: Issues that appear repeatedly
- **Time sinks**: Phases with longest duration
- **Throughput blockers**: What's preventing task completion
- **Quality issues**: Patterns in review findings

### Step 4: Recommendation Generation

Based on patterns, the skill generates:
- **Actionable Recommendations**: Specific changes to make
- **Priority Scoring**: Which improvements have highest impact
- **Tracking Metrics**: How to measure improvement
- **Implementation Plan**: Steps to apply recommendations

### Step 5: Report Generation

Output includes:
- **Executive Summary**: Key findings and top 3 recommendations
- **Detailed Metrics**: Full breakdown by phase
- **Trend Analysis**: Week-over-week or month-over-month changes
- **Action Items**: Specific tasks to improve workflow
- **Success Criteria**: How to know if improvements worked

## Scripts

### analyze_pipeline.rb

**Purpose**: Main analysis script that examines the entire workflow pipeline

**Usage**:
```bash
ruby scripts/analyze_pipeline.rb [options]

Options:
  --phase PHASE          Analyze specific phase (planning, implementation, review)
  --since DATE           Only analyze issues since DATE (YYYY-MM-DD)
  --last N               Only analyze last N days
  --export FILE          Export metrics to JSON file
  --compare FILE         Compare current metrics with previous export
  --verbose              Show detailed output
  --help                 Show this help
```

**Output**:
- Console report with key findings
- Optional JSON export for tracking over time
- Actionable recommendations with priority scores

### generate_report.rb

**Purpose**: Generates a formatted markdown report from analysis data

**Usage**:
```bash
ruby scripts/generate_report.rb [options]

Options:
  --input FILE           Input metrics JSON (from analyze_pipeline.rb)
  --output FILE          Output markdown file
  --format FORMAT        Report format (summary, detailed, executive)
  --help                 Show this help
```

**Output**:
- Markdown report suitable for sharing or documentation
- Embedded charts (text-based)
- Comparison tables (if comparing two time periods)

### track_metrics.rb

**Purpose**: Track metrics over time for trend analysis

**Usage**:
```bash
ruby scripts/track_metrics.rb [options]

Options:
  --record               Record current metrics to history
  --show                 Show historical trends
  --period PERIOD        Grouping period (day, week, month)
  --help                 Show this help
```

**Output**:
- Historical metrics stored in `.agent/metrics/history.jsonl`
- Trend charts showing improvement or degradation
- Anomaly detection (sudden changes)

## Metrics Tracked

### Planning Phase

| Metric | Description | Target |
|--------|-------------|--------|
| Tickets/Week | Rate of ticket creation | Stable or increasing |
| P0-P2 Ratio | % of high-priority tickets | 30-50% |
| Dependency Depth | Max dependency chain length | < 3 levels |
| Planning Lag | Time from create to start | < 2 days |
| Orphan Rate | % never started | < 10% |

### Implementation Phase

| Metric | Description | Target |
|--------|-------------|--------|
| Cycle Time (P0) | Avg time to complete P0 | < 1 day |
| Cycle Time (P1) | Avg time to complete P1 | < 2 days |
| Cycle Time (P2) | Avg time to complete P2 | < 3 days |
| Completion Rate | Closed/Created ratio | > 90% |
| Blocked Duration | Avg time tasks stay blocked | < 1 day |
| Re-work Rate | % rejected and re-implemented | < 20% |

### Review Phase

| Metric | Description | Target |
|--------|-------------|--------|
| Findings/Review | Avg issues found per review | 2-5 |
| Approval Rate | % passing first review | > 60% |
| P0-P2 Findings | % blocking findings | 40-60% |
| P3-P4 Findings | % polish findings | 40-60% |
| Review Lag | Time from ready to approval | < 1 day |
| Doc Finding Rate | % findings about docs | < 30% |

### Meta Metrics

| Metric | Description | Target |
|--------|-------------|--------|
| Retro Frequency | Days between retrospectives | 7-14 days |
| Action Completion | % of recommendations implemented | > 70% |
| Velocity Trend | Week-over-week completion rate | Stable or increasing |

## Common Findings & Recommendations

### Finding: High Documentation Overhead

**Symptoms**:
- > 30% of review findings are documentation-related
- > 50% of P1 tasks are documentation
- Low completion rate due to doc tasks blocking features

**Recommendations**:
1. Apply NEW vs EXISTING code distinction in review guidelines
2. Downgrade P1 doc tasks for EXISTING code to P3-P4
3. Schedule dedicated polish time for doc work
4. Track polish backlog separately

**Impact**: 30-50% reduction in blocked features

### Finding: Review Bottleneck

**Symptoms**:
- Tasks sit in ready-for-review for > 2 days
- High rejection rate (> 40%)
- Same issues appearing in multiple reviews

**Recommendations**:
1. Add pre-review checklist for implementers
2. Create review finding templates to reduce repeat issues
3. Add automated checks (linters, tests) before review
4. Batch similar reviews together

**Impact**: 50% reduction in review lag time

### Finding: Dependency Gridlock

**Symptoms**:
- Many tasks blocked by dependencies
- Circular dependencies exist
- Avg dependency depth > 3 levels

**Recommendations**:
1. Limit dependency depth to 2 levels
2. Run `bd blocked` regularly to identify gridlock
3. Break large tasks into smaller, independent units
4. Use epic structure for complex features

**Impact**: 40% reduction in blocked time

### Finding: Priority Inflation

**Symptoms**:
- > 70% of tasks are P0-P1
- "Everything is urgent"
- Low completion rate for P2-P4 tasks

**Recommendations**:
1. Enforce priority budgets (max % per priority)
2. Re-calibrate priority guidelines
3. Require justification for P0-P1 assignments
4. Review and downgrade inflated priorities

**Impact**: Better focus, 30% improvement in P0-P1 completion

### Finding: Low Polish Completion

**Symptoms**:
- Growing P3-P4 backlog
- Polish tasks never completed
- Technical debt accumulation

**Recommendations**:
1. Schedule dedicated polish time (Polish Friday)
2. Use `polish_backlog.rb` to prioritize polish work
3. Set weekly polish completion targets
4. Celebrate polish work equally with features

**Impact**: Controlled tech debt, improved code quality

## Example Reports

### Executive Summary Format

```markdown
# Workflow Retrospective - Week of 2026-02-05

## Key Findings

✅ **Wins**:
- Feature velocity up 35% (12 tasks vs 9 last week)
- Review approval rate improved to 75% (was 60%)
- P3-P4 polish work separated successfully

⚠️ **Concerns**:
- Average review lag increased to 1.5 days (target: < 1 day)
- Dependency depth reaching 3-4 levels (target: < 3)
- Growing polish backlog (18 tasks, +6 from last week)

## Top 3 Recommendations

1. **[P0] Batch Reviews Daily** - Schedule 2x daily review slots to reduce lag
2. **[P1] Limit Dependency Depth** - Enforce max 2-level dependencies in ticket creation
3. **[P2] Polish Friday Trial** - Dedicate Fridays to polish backlog reduction

## Metrics Snapshot

| Metric | This Week | Last Week | Target | Status |
|--------|-----------|-----------|--------|--------|
| Completion Rate | 92% | 85% | > 90% | ✅ On Target |
| Review Lag | 1.5 days | 1.2 days | < 1 day | ⚠️ Above Target |
| P0-P2 Findings | 55% | 75% | 40-60% | ✅ Improving |
| Doc Finding Rate | 25% | 40% | < 30% | ✅ On Target |
```

## Integration with Other Skills

**ticket-generator**:
- Use retrospective findings to improve ticket quality
- Adjust priority assignment based on inflation metrics
- Template common issue patterns

**task-implementer**:
- Share common implementation pitfalls
- Pre-review checklist from frequent findings
- Blocked task alerts based on dependency metrics

**fs-task-reviewer**:
- Calibrate priority guidelines based on finding distribution
- Share common issue patterns for consistency
- Adjust review scope based on bottleneck analysis

**beads-workflow-diagnostics**:
- Use retrospective data to detect stuck states
- Identify systemic issues vs one-off problems
- Validate diagnostic recommendations

## Best Practices

### Frequency

**Weekly Retrospectives** (Recommended):
- Quick, focused analysis
- Catch issues early
- Track week-over-week trends
- 15-30 minute time investment

**Monthly Retrospectives**:
- Deeper analysis
- Strategic planning
- Major workflow changes
- 1-2 hour time investment

**Ad-Hoc Retrospectives**:
- After major incidents
- Before/after process changes
- When velocity drops significantly

### Action Items

**Make them SMART**:
- **Specific**: "Reduce review lag" → "Schedule 2x daily review slots"
- **Measurable**: "Improve quality" → "Reduce P0 findings by 50%"
- **Actionable**: "Be better" → "Add pre-review checklist"
- **Relevant**: Tied to specific bottleneck or pain point
- **Time-bound**: "This week" or "Next sprint"

**Track Implementation**:
- Create beads issues for action items
- Set due dates
- Review completion in next retrospective
- Measure impact with before/after metrics

### Continuous Improvement

**Build Feedback Loops**:
1. Identify problem → Generate recommendation → Implement change → Measure impact → Iterate
2. Track metrics over time to validate improvements
3. Re-run retrospectives to ensure changes are working
4. Celebrate wins and learn from failures

**Avoid Common Pitfalls**:
- Don't blame individuals, focus on process
- Don't generate too many action items (max 3-5)
- Don't skip retrospectives when busy (that's when you need them most)
- Don't forget to measure before/after

## Troubleshooting

**"Not enough data"**:
- Need at least 2 weeks of issues for meaningful analysis
- Ensure beads sync is working (`bd sync --status`)
- Check that labels and timestamps are set correctly

**"Metrics look wrong"**:
- Verify issue statuses are accurate
- Check for unclosed tasks skewing averages
- Look for outliers (tasks taking weeks when avg is days)
- Use `--verbose` flag for detailed breakdown

**"Recommendations too generic"**:
- Provide more context in issue descriptions
- Use labels consistently (documentation, polish, etc.)
- Track issue types (bug, task, feature)
- Record time estimates vs actual

**"Action items not getting done"**:
- Reduce number of action items (max 3)
- Create beads issues for each action item
- Assign owners and due dates
- Review action item completion in next retro

## References

- **Analysis Methodology**: [[ @references/analysis_methodology.md ]]
- **Metrics Glossary**: [[ @references/metrics_glossary.md ]]
- **Report Templates**: [[ @references/report_templates/ ]]
- **Example Reports**: [[ @references/example_reports/ ]]

## Version History

- **v1.0** (2026-02-12): Initial release
  - Full pipeline analysis
  - Planning/Implementation/Review metrics
  - Recommendation engine
  - JSON export for tracking
