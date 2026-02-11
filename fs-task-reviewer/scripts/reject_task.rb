#!/usr/bin/env ruby
# frozen_string_literal: true

# DEPRECATED: This script is no longer needed with the simplified workflow.
#
# NEW WORKFLOW (No special labels needed):
#
# When code review finds issues:
# 1. Create normal tickets for each issue:
#    bd create --title "Fix TypeScript error" --type bug --priority 1
#
# 2. Add blocking dependency (prevents original task from being picked up):
#    bd dep add <original-task-id> <new-ticket-id>
#
# 3. (Optional) Add parent relationship for context:
#    bd update <new-ticket-id> --parent <original-task-id>
#
# 4. That's it! The original task keeps its ready-for-review label, but:
#    - Won't appear in 'bd ready --label ready-for-review' (blocked)
#    - When fix tickets closed, automatically unblocks
#    - No label management needed
#
# RATIONALE:
# - No need for review-failed label (blocking deps handle workflow)
# - No need to remove ready-for-review (bd ready filters blocked tasks)
# - Normal tickets with blocking deps are clearer than special labels

puts "❌ This script is deprecated."
puts ""
puts "Use the new workflow instead:"
puts ""
puts "1. Create tickets for issues found:"
puts "   bd create --title \"Fix issue\" --type bug --priority 1"
puts ""
puts "2. Add blocking dependency:"
puts "   bd dep add <original-task> <new-ticket>"
puts ""
puts "3. (Optional) Add parent for context:"
puts "   bd update <new-ticket> --parent <original-task>"
puts ""
puts "See SKILL.md for complete workflow documentation."
exit 1
