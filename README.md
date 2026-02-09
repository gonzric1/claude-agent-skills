# Claude Agent Skills

Reusable Agent Skills for Claude Code across multiple projects.

## Overview

This repository contains a collection of specialized agent skills that extend Claude Code's capabilities for software development workflows. These skills are designed to be project-agnostic and can be used across any repository.

## Skills Included

### Workflow Skills

- **`task-implementer`** - Task execution workflow
  - Picks next high-priority task from backlog
  - Guides implementation and testing
  - Moves completed tasks to review queue

- **`ticket-generator`** - Standardized ticket creation
  - Generates structured task tickets from requirements
  - Includes priority scoring and acceptance criteria

- **`test-and-commit`** - Smart test runner and commit helper
  - Analyzes changed files to identify relevant tests
  - Runs tests and provides commit templates

### Code Quality Skills

- **`fs-task-reviewer`** - Senior engineer code review
  - Reviews code for correctness, edge cases, SOLID principles
  - Checks test coverage and documentation
  - Runs linting and security scans
  - Generates implementation tickets for findings

- **`context-documenter`** - Documentation generator
  - Creates/updates comprehensive documentation
  - Provides templates for features, integrations, and technical guides

### Meta Skills

- **`skill-architect`** - Skill creation and validation
  - Scaffolds new skill directories following agentskills.io spec
  - Validates YAML and directory structure

## Installation

### Prerequisites

Projects must have the following directory structure:
```
.agent/
├── tasks/
│   ├── to-do/
│   ├── in-progress/
│   ├── ready-for-review/
│   └── completed/
└── context/
```

### Option 1: Symlink (Recommended)

This method creates a symbolic link from your project to this global skills repository.

**Automatic Setup:**
```bash
# Download and run the setup script
curl -fsSL https://raw.githubusercontent.com/yourusername/claude-agent-skills/main/install.sh | bash -s /path/to/your-project
```

**Manual Setup:**
```bash
# First time: Clone this repo
git clone https://github.com/yourusername/claude-agent-skills.git ~/repos/claude-agent-skills

# In each project:
cd /path/to/your-project
mkdir -p .agent/{tasks/{to-do,in-progress,ready-for-review,completed},context}
ln -s ~/repos/claude-agent-skills .agent/skills

# Add to .gitignore
echo '.agent/skills' >> .gitignore
```

**Benefits:**
- Single source of truth for all projects
- Update once, available everywhere
- No git submodule complexity

### Option 2: Git Submodule

Use this if you want different projects to use different versions of the skills.

```bash
cd /path/to/your-project
git submodule add https://github.com/yourusername/claude-agent-skills.git .agent/skills
git commit -m "Add agent skills as submodule"

# On new machines:
git clone your-project-repo
git submodule update --init --recursive
```

### Option 3: Direct Copy (Not Recommended)

```bash
# Copy skills directly into project (will diverge over time)
cp -r ~/repos/claude-agent-skills/* /path/to/project/.agent/skills/
```

## Updating Skills

### If Using Symlink
```bash
cd ~/repos/claude-agent-skills
git pull origin main
# All projects automatically get updates
```

### If Using Git Submodule
```bash
cd /path/to/project/.agent/skills
git pull origin main
cd ../..
git add .agent/skills
git commit -m "Update agent skills"
```

## Usage

Once installed, skills are invoked via the `/skill-name` command in Claude Code:

```
/task-implementer     # Start next task from backlog
/fs-task-reviewer     # Review completed work
/ticket-generator     # Create new task ticket
/test-and-commit      # Run tests and commit
/context-documenter   # Generate documentation
/skill-architect      # Create new skill
```

See each skill's `SKILL.md` file for detailed usage instructions.

## Contributing

### Creating New Skills

Use the `/skill-architect` skill to scaffold new skills:

```
/skill-architect
```

### Modifying Existing Skills

**IMPORTANT: Skills should always be edited in this global repository:**

```bash
# Edit skills here (not in individual projects):
cd ~/repos/claude-agent-skills

# Make changes to any skill
vim task-implementer/SKILL.md

# Commit and push
git add .
git commit -m "Update task-implementer skill"
git push origin main

# Changes are immediately available to all projects via symlinks
```

### Skill Structure

Each skill follows the agentskills.io specification:

```
skill-name/
├── SKILL.md          # Main skill definition (YAML frontmatter + markdown)
├── scripts/          # Helper scripts (Ruby, Bash, etc.)
└── assets/           # Templates, config files, etc.
```

## Requirements

- **Ruby** 3.0+ (for Ruby-based helper scripts)
- **Git** (for version control)
- **Claude Code CLI** (for skill execution)

## Directory Paths

Skills use relative path resolution to work correctly regardless of where they're installed. They navigate up from the script location to find the `.agent` directory in the current project.

## License

MIT License - Feel free to modify and distribute.

## Maintenance

This repository is maintained as part of the PrintMines project. For issues or feature requests, please open a GitHub issue.

---

**Note:** When using symlinks, the `.agent/skills` directory should be added to `.gitignore` to avoid committing the symlink to your project repository.
