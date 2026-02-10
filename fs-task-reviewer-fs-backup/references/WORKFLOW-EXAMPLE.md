# fs-task-reviewer Workflow Examples

This document provides practical examples of how to use the fs-task-reviewer skill in both verification and full review modes.

---

## Quick Reference

```bash
# Always start with this
ruby scripts/check_review_status.rb

# If no review exists, get changes to review
ruby scripts/get_uncommitted_changes.rb        # For uncommitted changes
# OR
ruby scripts/get_task_for_review.rb           # For formal tasks

# Run static analysis
bash scripts/review-suite.sh

# After creating tickets and review-summary, verify later
ruby scripts/check_review_status.rb

# Once all blocking issues resolved
# Script automatically moves review-summary to completed/
```

---

## Example 1: First Code Review (No Existing Review)

### Developer: "I just fixed a bug, can you review?"

**Step 1: Check for existing review**
```bash
$ ruby scripts/check_review_status.rb
❌ No review-summary found in .agent/tasks/to-do
Expected filename pattern: REVIEW-SUMMARY-YYYY-MM-DD-*.md

Action: Perform a full code review of uncommitted changes
```

**Step 2: See what changed**
```bash
$ ruby scripts/get_uncommitted_changes.rb
📊 Uncommitted Changes Summary
============================================================

Total files changed: 3
  • Staged:    2
  • Unstaged:  1
  • Untracked: 0

📁 By Category:
  • Ruby: 1 files
  • Tests: 1 files
  • Docs: 1 files

📝 Changed Files:
------------------------------------------------------------
  [S] app/services/printer_websocket_monitor.rb
  [S] test/services/printer_websocket_monitor_test.rb
  [M] .agent/context/integrations/centauri_websocket.md

✅ Ready for code review
```

**Step 3: Run static analysis**
```bash
$ bash scripts/review-suite.sh
[RuboCop, Brakeman, ESLint results...]
```

**Step 4: Manual review finds issues**

Issues found:
- ❌ New thread logic but only 4 basic tests (CRITICAL)
- ❌ Missing YARD documentation on new method (MAJOR)
- ❌ Generic error handling in background thread (MODERATE)

**Step 5: Create tickets**

Agent creates:
- `CRITICAL-2026-02-09-add-thread-test-coverage.md`
- `7-2026-02-09-add-yard-documentation.md`
- `5-2026-02-09-improve-error-handling.md`

**Step 6: Create review-summary**

Agent creates:
- `REVIEW-SUMMARY-2026-02-09-centauri-polling-fix.md`

**Review Verdict: REJECTED ❌**

```
5 tickets created:
- CRITICAL (10/10): 1 ticket
- MAJOR (7-9/10): 2 tickets
- MODERATE (4-6/10): 2 tickets

Review-summary: .agent/tasks/to-do/REVIEW-SUMMARY-2026-02-09-centauri-polling-fix.md

Next step: Address blocking issues and re-run check_review_status.rb
```

---

## Example 2: Verification Review (Developer Fixed Issues)

### Developer: "I fixed the critical issue, ready for re-review?"

**Step 1: Check review status**
```bash
$ ruby scripts/check_review_status.rb
📋 Found review-summary: REVIEW-SUMMARY-2026-02-09-centauri-polling-fix.md

============================================================

📝 Tickets from review:
  1. ✅ CRITICAL-2026-02-09-add-thread-test-coverage.md (completed)
  2. ❌ 7-2026-02-09-add-yard-documentation.md (exists)
  3. ❌ 5-2026-02-09-improve-error-handling.md (exists)

============================================================

🚫 BLOCKING ISSUES REMAIN:
   - CRITICAL-2026-02-09-add-thread-test-coverage.md

❌ Review NOT complete - address blocking issues first

Next steps:
  1. Implement tickets in .agent/tasks/to-do
  2. Run tests to verify fixes
  3. Re-run this check
```

**Developer fixed it, but script shows "exists" because ticket is still in to-do/**

**Step 2: Verify tests actually pass**
```bash
$ bundle exec rails test test/services/printer_websocket_monitor_test.rb
Running 10 tests in a single process
..........

Finished in 0.234s, 42.74 runs/s
10 runs, 15 assertions, 0 failures, 0 errors, 0 skips
```

**Step 3: Move completed ticket to completed folder**
```bash
$ mv .agent/tasks/to-do/CRITICAL-2026-02-09-add-thread-test-coverage.md \
     .agent/tasks/completed/
```

**Step 4: Re-check review status**
```bash
$ ruby scripts/check_review_status.rb
📋 Found review-summary: REVIEW-SUMMARY-2026-02-09-centauri-polling-fix.md

============================================================

📝 Tickets from review:
  1. ✅ CRITICAL-2026-02-09-add-thread-test-coverage.md (completed)
  2. ❌ 7-2026-02-09-add-yard-documentation.md (exists)
  3. ❌ 5-2026-02-09-improve-error-handling.md (exists)

============================================================

✅ All blocking issues resolved!

Moving review-summary to completed...
✅ Moved: .agent/tasks/completed/REVIEW-SUMMARY-2026-02-09-centauri-polling-fix.md

🎉 Code is ready for approval!

Suggested next steps:
  1. Run final test suite: bundle exec rails test
  2. Verify all changes are committed
  3. Create pull request or merge to main
```

**Review Verdict: APPROVED ✅**

Note: Non-blocking tickets (7, 5) can be addressed in follow-up work.

---

## Example 3: Full Approval (No Issues)

### Developer: "Can you review my well-tested feature?"

**Step 1: Check for existing review**
```bash
$ ruby scripts/check_review_status.rb
❌ No review-summary found in .agent/tasks/to-do
Action: Perform a full code review
```

**Step 2: Review uncommitted changes**
```bash
$ ruby scripts/get_uncommitted_changes.rb
[Shows changes...]
```

**Step 3: Static analysis passes**
```bash
$ bash scripts/review-suite.sh
✅ RuboCop: 0 offenses
✅ Brakeman: 0 warnings
✅ Tests: All passing
```

**Step 4: Manual review - everything looks good!**

Agent verifies:
- ✅ Tests cover new logic
- ✅ YARD documentation present
- ✅ Error handling appropriate
- ✅ SOLID principles followed
- ✅ No security issues

**Review Verdict: APPROVED ✅**

```
✅ Code Review: PASS

Summary:
- All tests pass (426 runs, 0 failures)
- Test coverage added for new functionality
- YARD documentation complete
- No security vulnerabilities
- SOLID principles maintained
- Code matches architecture patterns

🎉 Code is ready for merge/deployment!

No tickets created - no issues found.
```

---

## Example 4: Mixed Priority Issues

### Scenario: Some blocking, some non-blocking issues

```bash
$ ruby scripts/check_review_status.rb
📋 Found review-summary: REVIEW-SUMMARY-2026-02-10-api-changes.md

📝 Tickets from review:
  1. ✅ CRITICAL-2026-02-10-add-authentication-tests.md (completed)
  2. ✅ CRITICAL-2026-02-10-fix-sql-injection.md (completed)
  3. ❌ 8-2026-02-10-add-rate-limiting.md (exists)
  4. ❌ 5-2026-02-10-refactor-controller.md (exists)
  5. ❌ 3-2026-02-10-improve-naming.md (exists)

============================================================

✅ All blocking issues resolved!
```

**Result:** Non-blocking tickets (8, 5, 3) remain, but they don't block approval. They can be addressed in follow-up work.

---

## Workflow Decision Tree

```
Start: User requests code review
  |
  ├─> Run: check_review_status.rb
  |
  ├─> Review-summary exists?
  │   |
  │   ├─> YES: Parse tickets
  │   │   |
  │   │   ├─> All CRITICAL tickets completed?
  │   │   │   |
  │   │   │   ├─> YES: Move review-summary to completed/ ✅
  │   │   │   │        Notify: "Code ready for approval!"
  │   │   │   │
  │   │   │   └─> NO: Report remaining blocking issues ❌
  │   │   │           Notify: "Fix CRITICAL tickets first"
  │   │   │
  │   │   └─> End
  │   │
  │   └─> NO: Continue to full review
  │
  ├─> Get changes to review
  │   ├─> get_uncommitted_changes.rb (for uncommitted work)
  │   └─> get_task_for_review.rb (for formal tasks)
  │
  ├─> Run static analysis
  │   └─> review-suite.sh
  │
  ├─> Manual review
  │   |
  │   ├─> Issues found?
  │   │   |
  │   │   ├─> YES: Create tickets + review-summary ❌
  │   │   │        File: REVIEW-SUMMARY-YYYY-MM-DD-*.md
  │   │   │        Location: .agent/tasks/to-do/
  │   │   │
  │   │   └─> NO: Approve ✅
  │   │           No review-summary needed
  │   │
  │   └─> End
```

---

## Tips

### For Developers

1. **Check review status before making changes**
   - Prevents working on code that's already blocked by review
   - Shows what needs to be fixed first

2. **Move tickets to completed/ when done**
   - Script checks ticket location to verify completion
   - Tickets in to-do/ are considered "not done"

3. **Address CRITICAL tickets first**
   - Only blocking tickets prevent approval
   - Lower priority items can be follow-up

### For Reviewers

1. **Always start with check_review_status.rb**
   - Prevents duplicate reviews
   - Verifies fixes instead of re-reviewing

2. **Create detailed review-summaries**
   - Include all ticket filenames (exact match)
   - List blocking issues clearly
   - Provide next steps

3. **Be specific in ticket acceptance criteria**
   - "Add 6 test cases" not "Add more tests"
   - Include code examples where helpful
   - Reference line numbers when pointing out issues

---

## File Locations Quick Reference

```
.agent/tasks/
├── to-do/                    # Pending work
│   ├── CRITICAL-*.md         # Blocking issues (10/10)
│   ├── [7-9]-*.md           # Major issues
│   ├── [4-6]-*.md           # Moderate issues
│   ├── [1-3]-*.md           # Minor issues
│   └── REVIEW-SUMMARY-*.md  # Active review needing fixes
│
├── ready-for-review/         # Formal tasks awaiting review
│
├── in-progress/              # Currently being worked on
│
├── completed/                # Finished work
│   └── REVIEW-SUMMARY-*.md  # Approved reviews
│
└── archived/                 # Old/obsolete work
```

---

## Common Questions

**Q: What if I fix issues but forget to move tickets?**
A: The script will see them in `to-do/` and report "NOT complete". Move completed tickets to `completed/` folder.

**Q: Can I fix non-blocking tickets later?**
A: Yes! Only CRITICAL (10/10) tickets block approval. Others can be follow-up work.

**Q: What if I disagree with a ticket?**
A: Discuss with reviewer. You can:
1. Argue why it's not needed (comment in ticket)
2. Downgrade priority (reviewer decision)
3. Move to backlog (defer to later)

**Q: How do I know which tickets are blocking?**
A: CRITICAL tickets (10/10) are always blocking. Script checks for these.

**Q: What if ticket filenames don't match review-summary?**
A: Script won't find them. Use exact filenames from review-summary.

**Q: Can I edit the review-summary?**
A: Yes, but don't change ticket filenames. Script parses them for verification.

---

## Script Exit Codes

**check_review_status.rb:**
- `0` - No review-summary found OR all blocking issues resolved
- `1` - Blocking issues remain OR parse error

**get_uncommitted_changes.rb:**
- `0` - Success (changes found or clean)
- `1` - Not a git repo

**get_task_for_review.rb:**
- `0` - Success (tasks found or none)

---

## Integration with Other Skills

**With task-implementer:**
```bash
# task-implementer picks a ticket from to-do/
# After completion, marks ticket as done
# Reviewer runs check_review_status.rb to verify
```

**With test-and-commit:**
```bash
# After implementing fix, use test-and-commit
# If tests pass, commit the changes
# Then move ticket to completed/
# Run check_review_status.rb
```

**With ticket-generator:**
```bash
# Reviewer creates tickets during review
# ticket-generator can format them properly
# All go to .agent/tasks/to-do/
```
