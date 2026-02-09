---
name: test-and-commit
description: Smartly identifies relevant tests, runs them, and commits the code if successful with a template-based message.
---

# Test and Commit

A skill to verify changes by running relevant tests and then committing the code.

## Capabilities
1.  **Smart Test Discovery**: Identifies tests related to the changed files.
2.  **Validation**: Runs the tests to ensure no regressions.
3.  **Commit**: uses a standardized template for commit messages.

## Workflow

1.  **Analyze Changes**:
    - Run `[[ @scripts/analyze_changes.rb ]]` to see a suggested grouping of your changes.
    - Review the suggestion. If the script suggests splitting changes (e.g., Infrastructure vs Feature), plan to run the test-and-commit loop multiple times, adding only the relevant files for each batch (using `git add` manually).

2.  **Identify & Run Tests**:
    - Run `[[ @scripts/smart_test_runner.rb ]]`.
    - This script will:
        - Detect changed files.
        - grep for referencing test files.
        - Run the identified tests.
        - Halt if tests fail.

3.  **Commit**:
    - The script will exit successfully if tests pass.
    - View `[[ @assets/COMMIT_TEMPLATE.md ]]` to draft your commit message.
    - Run `git commit -m '...'` manually.
    - **IMPORTANT**: Use single quotes `'` to wrap the message! Using double quotes `"` will cause backticks \` inside the message to be executed as shell commands.

4.  **Repeat**:
    - **CRITICAL**: Check `git status`. If there are still uncommitted changes, **REPEAT** steps 1-3 until the working directory is clean.

## Usage
Run the following to test your current changes:
```bash
ruby [[ @scripts/smart_test_runner.rb ]]
```
If successful, proceed to commit using the template.