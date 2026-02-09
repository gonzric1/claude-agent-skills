#!/usr/bin/env bash

# Claude Agent Skills - Installation Script
# Usage: ./install.sh [project-path]

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default paths
SKILLS_REPO_DIR="$HOME/repos/claude-agent-skills"
PROJECT_DIR="${1:-.}"  # Default to current directory

echo -e "${GREEN}Claude Agent Skills - Installation${NC}"
echo "======================================"
echo

# Step 1: Clone skills repo if needed
if [ ! -d "$SKILLS_REPO_DIR" ]; then
  echo -e "${YELLOW}Skills repository not found at $SKILLS_REPO_DIR${NC}"
  echo "Cloning from GitHub..."

  # Check if GitHub URL is set
  if ! git ls-remote https://github.com/gonzric1/claude-agent-skills.git &>/dev/null; then
    echo -e "${RED}Error: Repository not found on GitHub${NC}"
    echo "Please update the GitHub URL in this script or clone manually:"
    echo "  git clone YOUR_REPO_URL $SKILLS_REPO_DIR"
    exit 1
  fi

  git clone https://github.com/gonzric1/claude-agent-skills.git "$SKILLS_REPO_DIR"
  echo -e "${GREEN}✓ Skills repository cloned${NC}"
else
  echo -e "${GREEN}✓ Skills repository found at $SKILLS_REPO_DIR${NC}"

  # Update if already exists
  echo "Updating skills repository..."
  cd "$SKILLS_REPO_DIR"
  git pull origin main
  cd - > /dev/null
fi

echo

# Step 2: Validate project directory
if [ ! -d "$PROJECT_DIR" ]; then
  echo -e "${RED}Error: Project directory does not exist: $PROJECT_DIR${NC}"
  exit 1
fi

cd "$PROJECT_DIR"
echo "Installing to project: $(pwd)"
echo

# Step 3: Create .agent directory structure
echo "Creating .agent directory structure..."
mkdir -p .agent/{tasks/{to-do,in-progress,ready-for-review,completed},context}
echo -e "${GREEN}✓ Directory structure created${NC}"

# Step 4: Create symlink
if [ -L ".agent/skills" ]; then
  echo -e "${YELLOW}Symlink already exists at .agent/skills${NC}"
  CURRENT_TARGET=$(readlink .agent/skills)
  echo "  Current target: $CURRENT_TARGET"

  if [ "$CURRENT_TARGET" != "$SKILLS_REPO_DIR" ]; then
    echo -e "${YELLOW}Updating symlink target...${NC}"
    rm .agent/skills
    ln -s "$SKILLS_REPO_DIR" .agent/skills
    echo -e "${GREEN}✓ Symlink updated${NC}"
  fi
elif [ -d ".agent/skills" ] && [ ! -L ".agent/skills" ]; then
  echo -e "${YELLOW}Warning: .agent/skills exists as a directory (not symlink)${NC}"
  echo "Backing up to .agent/skills.backup..."
  mv .agent/skills .agent/skills.backup
  ln -s "$SKILLS_REPO_DIR" .agent/skills
  echo -e "${GREEN}✓ Symlink created (old directory backed up)${NC}"
else
  ln -s "$SKILLS_REPO_DIR" .agent/skills
  echo -e "${GREEN}✓ Symlink created${NC}"
fi

# Step 5: Update .gitignore
if [ -f ".gitignore" ]; then
  if ! grep -q "^\.agent/skills$" .gitignore; then
    echo "Adding .agent/skills to .gitignore..."
    echo "" >> .gitignore
    echo "# Agent skills (symlinked globally)" >> .gitignore
    echo ".agent/skills" >> .gitignore
    echo -e "${GREEN}✓ .gitignore updated${NC}"
  else
    echo -e "${GREEN}✓ .gitignore already configured${NC}"
  fi
else
  echo -e "${YELLOW}No .gitignore found, creating one...${NC}"
  cat > .gitignore << 'EOF'
# Agent skills (symlinked globally)
.agent/skills
EOF
  echo -e "${GREEN}✓ .gitignore created${NC}"
fi

echo
echo -e "${GREEN}Installation complete!${NC}"
echo
echo "Available skills:"
ls -1 .agent/skills | sed 's/^/  - /'
echo
echo "Usage in Claude Code:"
echo "  /task-implementer     - Execute next task"
echo "  /fs-task-reviewer     - Review code changes"
echo "  /ticket-generator     - Create task ticket"
echo "  /test-and-commit      - Run tests and commit"
echo "  /context-documenter   - Generate documentation"
echo "  /skill-architect      - Create new skill"
echo
