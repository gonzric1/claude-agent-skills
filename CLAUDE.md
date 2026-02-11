# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a collection of reusable Agent Skills for Claude Code. Skills are project-agnostic extensions that can be symlinked into any project's `.agent/skills` directory. The skills repository is the single source of truth - changes here propagate to all projects using symlinks.

## Installation

```bash
# Install skills into a project
./install.sh /path/to/project

# Manual setup (beads-based workflow)
bd init  # Initialize beads issue tracking
ln -s ~/repos/claude-agent-skills /project/.agent/skills
```

## Skills Architecture

Each skill follows this structure:
```
skill-name/
├── SKILL.md          # YAML frontmatter + instructions (invoked via /skill-name)
├── scripts/          # Ruby helper scripts
└── assets/           # Templates and configs
```

### Path Resolution in Scripts

Scripts MUST use working directory-relative paths (not script-relative):

```ruby
# CORRECT - works with symlinks
AGENT_DIR = File.join(Dir.pwd, '.agent')
TASKS_DIR = File.join(AGENT_DIR, 'tasks')

# WRONG - breaks when symlinked
SKILLS_DIR = File.expand_path('../..', __dir__)
```

## Available Skills

| Skill | Purpose |
|-------|---------|
| `/task-implementer` | Pick and execute tasks from beads backlog |
| `/fs-task-reviewer` | Senior engineer code review with ticket generation |
| `/ticket-generator` | Create structured beads issues |
| `/test-and-commit` | Smart test discovery and commit workflow |
| `/context-documenter` | Documentation generation for `.agent/context` |
| `/skill-architect` | Scaffold new skills |

## Beads Workflow

These skills use beads (`bd` CLI) for issue tracking. Beads provides git-backed, dependency-aware task management.

### Quick Start

```bash
# Initialize beads in a project
bd init

# Create a task
bd create "Implement user authentication" --priority 2 --labels ticket

# View ready tasks (unblocked)
bd ready

# Start working on a task
bd update PROJ-1 --claim

# Complete task (mark for review)
bd update PROJ-1 --status open --add-label ready-for-review

# Close completed task
bd close PROJ-1
```

### Status Workflow

| Status | Description |
|--------|-------------|
| `open` | Task is in backlog or ready for review |
| `in_progress` | Task is being worked on (via `--claim`) |
| `closed` | Task is completed |

### Priority Levels

| Priority | Label | Description |
|----------|-------|-------------|
| P0 | `critical` | Security, data loss, critical bugs |
| P1 | `major` | Core functionality broken |
| P2 | `moderate` | Significant issue with workaround |
| P3 | `ticket` | Standard feature work |
| P4 | `nit` | Style, naming, minor refactors |

### Label Conventions

**Workflow Labels:**
- `ready-for-review` - Awaiting code review
- `review-passed` - Approved by code review

**Note:** Review-generated tickets use normal issue types (bug, task, documentation) with blocking dependencies. No special labels needed.

**Priority Labels:**
- `critical`, `major`, `moderate`, `ticket`, `nit`

### Dependencies

```bash
# Make PROJ-2 wait for PROJ-1 to complete
bd dep add PROJ-2 PROJ-1

# View blocked tasks
bd blocked

# View ready tasks (unblocked)
bd ready
```

### Command Reference

| Action | Command |
|--------|---------|
| Create ticket | `bd create "Title" -p 2 -l ticket` |
| Quick capture | `bd q "Title"` |
| Start task | `bd update <id> --claim` |
| Mark for review | `bd update <id> --add-label ready-for-review` |
| Approve | `bd close <id>` |
| List ready | `bd ready` |
| List blocked | `bd blocked` |
| Add dependency | `bd dep add <blocked> <blocker>` |
| Show task | `bd show <id>` |

## Testing Scripts

Run scripts from the project root (not from within the skills directory):

```bash
cd /path/to/project
ruby .agent/skills/task-implementer/scripts/start_next_task.rb
```

## Key Constraints

- All scripts use Ruby (shebang: `#!/usr/bin/env ruby`)
- The `name` in SKILL.md YAML must match the directory name exactly
- Projects must have beads initialized (`bd init`)
- Never edit skills in project symlink locations - always edit here

## Migration from File-Based Tasks

If you have an existing `.agent/tasks/` directory structure, you can migrate to beads:

1. Initialize beads: `bd init`
2. For each task file in `to-do/`:
   ```bash
   bd create "Task title" --priority 2 --labels ticket \
     --description "Content from task file"
   ```
3. Set up dependencies using `bd dep add`
4. Remove the old `.agent/tasks/` directories (optional - beads uses `.beads/`)
