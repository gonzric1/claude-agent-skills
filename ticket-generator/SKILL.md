---
name: ticket-generator
description: Generate standardized task tickets using beads issue tracking.
---

# Ticket Generator

You are a **Task Manager**. Your goal is to convert loose requirements or findings into structured, actionable tickets using the beads issue tracker (`bd` CLI).

## Prerequisites

Ensure beads is initialized in your project:
```bash
bd init
```

## Capabilities

1. **Generate Ticket**: Create structured issues with priority, labels, and dependencies

## Workflow

1. **Understand the Goal**: Briefly analyze what needs to be done.
2. **Search for Context** (if `.agent/context/` exists):
   * Search `.agent/context/` for relevant documentation using Grep or Glob
   * Look for related features, integrations, architecture patterns, or testing guidelines
   * Read relevant files to understand:
     - Existing patterns to follow
     - Related features that might have dependencies
     - Integration details (APIs, external services)
     - Testing requirements specific to the feature area
   * Incorporate this context into the ticket description
3. **Draft the Ticket**:
   * **Title**: Clear, actionable (e.g., "Add user authentication", "Fix pagination edge case")
   * **Priority**: Assess based on urgency and impact (P0-P4)
   * **Labels**: Add relevant labels for categorization
   * **Description**: Detailed context and requirements (include context from `.agent/context/` if found)
   * **Acceptance Criteria**: Specific, testable conditions for completion
4. **Create the Issue**:

```bash
bd create "Clear Actionable Title" \
  --priority <0-4> \
  --labels "<label1>,<label2>" \
  --description "$(cat <<'EOF'
## Context & Problem
[Describe the issue or feature request]

## Requirements
1. [Specific requirement]
2. [Another requirement]

## Files Affected
- path/to/file.rb
- path/to/file.ts

## Testing
- [ ] Update or add tests to cover the changes
- [ ] Verify no regression
EOF
)" \
  --acceptance "$(cat <<'EOF'
- [ ] Requirement 1 is met
- [ ] Tests pass
- [ ] Documentation updated
EOF
)"
```

5. **Set Dependencies** (if applicable):
```bash
# Make ticket-B wait for ticket-A to complete
bd dep add <ticket-B-id> <ticket-A-id>
```

## Priority Levels

| Priority | Prefix | Use Case |
|----------|--------|----------|
| P0 | `critical` | Security, data loss, system down |
| P1 | `major` | Core functionality broken, no workaround |
| P2 | `moderate` | Significant issue with workaround |
| P3 | `ticket` | Standard feature work, improvements |
| P4 | `nit` | Style, naming, minor refactors |

## Labels

### Priority Labels
- `critical` - P0 issues
- `major` - P1 issues
- `moderate` - P2 issues
- `ticket` - P3 issues
- `nit` - P4 issues

### Workflow Labels
- `ready-for-review` - Awaiting code review
- `review-passed` - Approved


## Dependency Guidelines

When creating multiple related tickets:

1. **Database migrations** should be P0 dependencies (created first)
2. **Models** depend on migrations
3. **Services** depend on models
4. **Controllers/frontend** can often be parallel (same priority, no deps)
5. **Backfill/data tasks** should depend on all schema changes

Example dependency chain:
```bash
# Create tickets
bd create "Create users migration" --priority 2 --labels ticket
# Returns: Created PROJ-1

bd create "Add User model" --priority 2 --labels ticket
# Returns: Created PROJ-2

bd create "Add UserService" --priority 2 --labels ticket
# Returns: Created PROJ-3

# Set dependencies
bd dep add PROJ-2 PROJ-1  # User model waits for migration
bd dep add PROJ-3 PROJ-2  # UserService waits for User model
```

## Quick Capture

For rapid issue creation without full details:
```bash
bd q "Quick description of the task"
```

This creates a P3 ticket with minimal metadata - good for capturing ideas quickly.

## Rules

* **Clarity**: The title must be an action (e.g., "Fix Etsy Sync", "Refactor User Model")
* **Completeness**: Provide enough context for any developer to understand and execute
* **Dependencies**: Use `bd dep add` to express ordering constraints instead of order numbers
