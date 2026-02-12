# Task Closure Validation Checklist

## Purpose

This checklist ensures task descriptions contain factually accurate information before marking tasks as ready for review or closing them as complete. It prevents false claims about commits, code changes, or implementation status.

## When to Use

Run this validation:
1. Before marking a task ready for review (`complete_task.rb`)
2. Before closing a task as complete (`close_task.rb`)
3. When creating new tasks that reference existing commits or code

## Validation Categories

### 1. Git Commit Verification

**What to verify:**
- Commits referenced in task descriptions actually exist
- Commit hashes are correct and complete
- Commits contain the changes claimed in the description

**How to verify:**
```bash
# Check if a commit exists
git log --oneline | grep <commit-hash>

# View full commit details
git show <commit-hash>

# Check if specific files were changed in a commit
git show --name-only <commit-hash>

# View specific file changes in a commit
git show <commit-hash>:<file-path>
```

**Red flags:**
- ✗ Commit hash not found in git log
- ✗ Commit message doesn't match claimed changes
- ✗ Files mentioned aren't in the commit's changeset
- ✗ Code changes don't align with task description

**Examples:**
- ✓ GOOD: "Commit 58d9104 changed variation_pattern to Record<string, string>" (verified via `git show 58d9104`)
- ✗ BAD: "Commit efea1b1 changed variation_pattern types" (commit doesn't exist)

### 2. Code State Verification

**What to verify:**
- Files mentioned actually exist at claimed paths
- Code changes described are present in current state
- Type definitions match claimed signatures
- Test coverage exists for claimed functionality

**How to verify:**
```bash
# Check if file exists
ls -la <file-path>

# Search for specific code patterns
grep -r "pattern" <directory>

# Check TypeScript types
grep -A 5 "interface ProductListing" <file>

# Find test files
find test/ -name "*product_listing*"
```

**Red flags:**
- ✗ File doesn't exist at claimed path
- ✗ Code pattern not found in file
- ✗ Type signature doesn't match description
- ✗ No tests for claimed functionality

**Examples:**
- ✓ GOOD: "ProductListing.variation_pattern is Record<string, string> | null" (verified in types file)
- ✗ BAD: "Added validation in ProductController" (no such validation exists)

### 3. Cross-Reference Validation

**What to verify:**
- Changes claimed align with git blame history
- Related files are consistently updated
- Dependencies between tasks are accurate
- Blockers are still valid

**How to verify:**
```bash
# Check who last changed a line
git blame <file-path> | grep <pattern>

# View file history
git log -p <file-path>

# Check related files in same commit
git show --name-only <commit-hash>

# View task dependencies
bd show <task-id>
```

**Red flags:**
- ✗ git blame shows different author/commit than claimed
- ✗ Related files not updated consistently
- ✗ Task blocks/depends on closed/invalid tasks
- ✗ Description contradicts git history

**Examples:**
- ✓ GOOD: "parseVariationPattern returns Record<string, string> per commit 58d9104" (matches git blame)
- ✗ BAD: "Function added in commit abc123" (git blame shows it was added in commit xyz789)

### 4. Scope Verification

**What to verify:**
- Task description matches actual work done
- Acceptance criteria align with implementation
- No unrelated changes bundled in
- All claimed changes are in the changeset

**How to verify:**
```bash
# View current git diff
git diff

# View staged changes
git diff --staged

# View changes in a commit
git show <commit-hash>

# Compare acceptance criteria to actual files
diff <(cat .beads/issues/<task-id>.md) <(git diff)
```

**Red flags:**
- ✗ Task claims work in commit X, but work was in commit Y
- ✗ Acceptance criteria don't match implementation
- ✗ Unrelated file changes bundled with task
- ✗ Some acceptance criteria not met

**Examples:**
- ✓ GOOD: Task says "add variation_pattern column", commit adds migration and model field
- ✗ BAD: Task says "fix type validation", commit changes unrelated ProductMappingDashboard UI

## Automated Validation Script

For automated verification, use:
```bash
ruby .agent/skills/task-implementer/scripts/validate_task.rb <task-id>
```

This script will:
1. Extract all commit hashes from task description
2. Verify each commit exists in git history
3. Check that claimed files exist
4. Cross-reference with git log/blame
5. Report any discrepancies

## Manual Verification Steps

Before marking a task ready for review:

**Step 1: Read the task description**
```bash
bd show <task-id>
```

**Step 2: Extract all factual claims**
Look for:
- Commit hashes (efea1b1, 58d9104, etc.)
- File paths (app/models/product_listing.rb)
- Code patterns ("variation_pattern: Record<string, string>")
- Function signatures ("parseVariationPattern returns...")

**Step 3: Verify each claim**
For each commit:
```bash
git log --oneline | grep <hash>
git show <hash>
```

For each file:
```bash
cat <file-path>
grep "<pattern>" <file-path>
```

**Step 4: Check consistency**
```bash
git diff <task-files>
git log -p <task-files>
```

**Step 5: Document findings**
If discrepancies found:
- Update task description with correct information
- Create new task for actual missing work
- Add comment explaining the correction

## Prevention: Best Practices

**When creating tasks:**
1. Verify claims before writing description
2. Use exact commit hashes from `git log --oneline`
3. Copy/paste file paths (don't type from memory)
4. Quote actual code snippets from files
5. Link to line numbers when referencing code

**When closing tasks:**
1. Run validation script before closing
2. Verify acceptance criteria are met
3. Check git history matches claims
4. Ensure all files mentioned were actually changed
5. Cross-reference with related tasks

**When referencing commits:**
```bash
# Get exact hash
git log --oneline -n 20

# Verify it's the right commit
git show <hash>

# Use full hash in task description (or at least 7 chars)
# GOOD: "Commit 58d9104 fixed..."
# BAD: "A recent commit fixed..." (which one?)
```

## Example Workflow

**Before marking task ready for review:**

```bash
# 1. View the task
bd show PrintMines-abc

# 2. Extract commit referenced in description
# Description says: "Completed in commit efea1b1"

# 3. Verify commit exists
git log --oneline | grep efea1b1
# → No results? RED FLAG!

# 4. Find actual commit
git log --oneline --grep="variation_pattern"
# → 58d9104 fix(types): use Record<string, string> for variation_pattern types

# 5. Update task description
bd update PrintMines-abc --description="Completed in commit 58d9104 (not efea1b1 - that commit doesn't exist)"

# 6. Now mark ready for review
ruby .agent/skills/task-implementer/scripts/complete_task.rb PrintMines-abc
```

## Common Mistakes to Avoid

1. **Referencing non-existent commits**
   - Always verify `git log | grep <hash>` before claiming a commit did something

2. **Confusing similar commits**
   - Check commit message and files changed, not just the hash

3. **Claiming work in wrong commit**
   - Use `git log -p <file>` to find which commit actually changed the file

4. **Assuming code exists without checking**
   - Grep for the actual code pattern before claiming it exists

5. **Bundling unrelated changes**
   - Review `git diff` to ensure only task-related files are changed

## Validation Script Output

Expected output from automated validation:

```
✓ Validating task PrintMines-abc: Fix type validation
✓ Commit 58d9104 exists
✓ Commit contains expected files:
  - app/javascript/types/product.ts
  - app/services/product_listing_service.rb
✓ Code pattern 'Record<string, string>' found in app/javascript/types/product.ts:12
✓ git blame confirms changes in commit 58d9104
✓ All acceptance criteria files exist

✓ VALIDATION PASSED
```

Failure output:

```
✗ Validating task PrintMines-pra: Close task as already completed
✗ Commit efea1b1 NOT FOUND in git history
✓ Code pattern 'Record<string, string>' found in app/javascript/types/product.ts:12
  ℹ Actual commit for this change: 58d9104 (via git blame)

✗ VALIDATION FAILED
  Issue: Referenced commit efea1b1 does not exist
  Suggestion: Update task description to reference commit 58d9104 instead
```
