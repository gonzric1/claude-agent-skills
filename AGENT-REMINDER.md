# 🤖 Agent Reminder: Where to Edit Skills

## ⚠️ CRITICAL: Global Skills Location

**ALL skills MUST be edited in this directory:**
```
~/repos/claude-agent-skills
```

**DO NOT edit skills in any of these locations:**
- ❌ `/path/to/PrintMines/.agent/skills/` (symlink)
- ❌ Any individual project's `.agent/skills/` directory
- ❌ Anywhere else

## Why?

This repository is the **single source of truth** for all agent skills. All projects use **symlinks** to reference this global location:

```
PrintMines/.agent/skills -> ~/repos/claude-agent-skills
OtherProject/.agent/skills -> ~/repos/claude-agent-skills
```

When you edit files here, changes propagate to ALL projects immediately.

## Quick Reference

### Creating a New Skill
```bash
cd ~/repos/claude-agent-skills
mkdir -p new-skill/{scripts,assets}
vim new-skill/SKILL.md
git add new-skill
git commit -m "feat: add new-skill"
```

### Modifying an Existing Skill
```bash
cd ~/repos/claude-agent-skills
vim task-implementer/SKILL.md
git commit -am "fix: improve task-implementer"
```

### Testing Changes
```bash
# Edit in global repo
cd ~/repos/claude-agent-skills
vim task-implementer/scripts/start_next_task.rb

# Test from any project
cd /path/to/PrintMines
ruby .agent/skills/task-implementer/scripts/start_next_task.rb
```

## Documentation

- `README.md` - Installation and usage instructions
- `CONTRIBUTING.md` - Detailed development guidelines
- `.github-setup.md` - GitHub repository setup

## Remember

🎯 **One location to rule them all:** `~/repos/claude-agent-skills`

All changes here are immediately available to every project that uses these skills.
