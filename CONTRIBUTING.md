# Contributing to Claude Agent Skills

## For Claude Code Agents: Where to Edit Skills

**IMPORTANT:** All skills should be created and edited in the **global skills repository**:

```
Location: ~/repos/claude-agent-skills
GitHub: https://github.com/yourusername/claude-agent-skills
```

### DO NOT Edit Skills In:
- ❌ `/path/to/PrintMines/.agent/skills/` (this is a symlink)
- ❌ Any individual project's `.agent/skills/` directory
- ❌ Temporary locations or copied versions

### ALWAYS Edit Skills In:
- ✅ `~/repos/claude-agent-skills/` (the source of truth)
- ✅ Changes here automatically propagate to all projects via symlinks

## Making Changes

### Creating a New Skill

```bash
# Navigate to the global skills repo
cd ~/repos/claude-agent-skills

# Use the skill-architect to scaffold
# (This will be run from a project, but creates in this repo)
# Or manually create:
mkdir -p new-skill-name/{scripts,assets}
touch new-skill-name/SKILL.md

# Commit changes
git add new-skill-name
git commit -m "feat: add new-skill-name"
git push origin main
```

### Modifying an Existing Skill

```bash
# Navigate to the global skills repo
cd ~/repos/claude-agent-skills

# Edit the skill
vim task-implementer/SKILL.md
vim task-implementer/scripts/start_next_task.rb

# Test from a project (skills are symlinked)
cd /path/to/any-project
ruby .agent/skills/task-implementer/scripts/start_next_task.rb

# Commit changes
cd ~/repos/claude-agent-skills
git add .
git commit -m "fix: update task-implementer logic"
git push origin main

# Changes are immediately available to all projects!
```

## Skill Development Guidelines

### Path Resolution

All scripts MUST use working directory-relative paths, not script-relative paths:

```ruby
# ✅ CORRECT - Works with symlinks
AGENT_DIR = File.join(Dir.pwd, '.agent')
TASKS_DIR = File.join(AGENT_DIR, 'tasks')

# ❌ WRONG - Breaks when symlinked
SKILLS_DIR = File.expand_path('../..', __dir__)
AGENT_DIR = File.dirname(SKILLS_DIR)
```

**Why:** Skills are symlinked from `~/repos/claude-agent-skills` into each project's `.agent/skills/`. Using `__dir__` resolves to the symlink target, not the project root.

### Directory Structure Requirements

Skills assume projects have this structure:

```
project-root/
└── .agent/
    ├── skills/           # Symlink to ~/repos/claude-agent-skills
    ├── tasks/
    │   ├── to-do/
    │   ├── in-progress/
    │   ├── ready-for-review/
    │   └── completed/
    └── context/
```

### Testing Changes

Always test your skill changes from a real project:

```bash
# Make changes in global repo
cd ~/repos/claude-agent-skills
vim task-implementer/scripts/start_next_task.rb

# Test from a project
cd /path/to/PrintMines  # or any project with symlinked skills
ruby .agent/skills/task-implementer/scripts/start_next_task.rb

# If it works, commit and push
cd ~/repos/claude-agent-skills
git add .
git commit -m "fix: improve task selection logic"
git push
```

## Skill Structure

Each skill follows this structure:

```
skill-name/
├── SKILL.md              # Skill definition (YAML frontmatter + markdown)
├── README.md             # Optional: detailed documentation
├── scripts/              # Helper scripts (Ruby, Bash, etc.)
│   ├── main_script.rb
│   └── helper_script.sh
├── assets/               # Templates, configs, etc.
│   ├── template.md
│   └── config.yml
└── references/           # Documentation, examples
    └── example.md
```

### SKILL.md Format

```markdown
---
name: skill-name
version: 1.0.0
description: Brief description of what the skill does
trigger: /skill-name
category: workflow|quality|meta
---

# Skill Name

Detailed description of the skill...

## Usage

How to use the skill...

## Scripts

- `scripts/main.rb` - Main script
```

## Version Control

### Commit Message Format

Follow conventional commits:

```
feat: add new feature
fix: bug fix
docs: documentation changes
refactor: code refactoring
test: test changes
chore: maintenance tasks
```

### Branching

For significant changes, use feature branches:

```bash
cd ~/repos/claude-agent-skills
git checkout -b feature/improve-reviewer
# Make changes
git commit -m "feat: add rubocop checks to reviewer"
git push origin feature/improve-reviewer
# Create PR on GitHub
```

## Distribution

### Updating Skills on Other Machines

When you push changes to GitHub, other machines can update:

```bash
# On another machine
cd ~/repos/claude-agent-skills
git pull origin main

# All projects with symlinks automatically get updates!
```

### Adding Skills to New Projects

Use the install script:

```bash
# Automatic
curl -fsSL https://raw.githubusercontent.com/yourusername/claude-agent-skills/main/install.sh | bash -s /path/to/project

# Manual
cd /path/to/new-project
mkdir -p .agent/{tasks/{to-do,in-progress,ready-for-review,completed},context}
ln -s ~/repos/claude-agent-skills .agent/skills
echo '.agent/skills' >> .gitignore
```

## Troubleshooting

### "Script can't find .agent directory"

Make sure you're running the script from the project root:

```bash
# ✅ Correct
cd /path/to/project
ruby .agent/skills/task-implementer/scripts/start_next_task.rb

# ❌ Wrong
cd /path/to/project/.agent/skills/task-implementer/scripts
ruby start_next_task.rb  # Can't find ../../.. from here
```

### "Changes not appearing in project"

Check that the symlink is correct:

```bash
ls -la /path/to/project/.agent/skills
# Should show: .agent/skills -> /home/ricky/repos/claude-agent-skills
```

### "Skill not found by Claude Code"

Ensure the SKILL.md file has proper YAML frontmatter and is in the skills directory.

## Questions?

For issues or questions, open an issue on GitHub or check the README.md.
