#!/usr/bin/env ruby
# frozen_string_literal: true

# Check if a review-summary issue exists and verify if blocking issues are resolved

require 'json'
require 'open3'

# Helper to run bd commands
def run_bd(args, allow_failure: false)
  cmd = "bd #{args}"
  stdout, stderr, status = Open3.capture3(cmd)

  unless status.success? || allow_failure
    if stderr.include?("No beads repository found")
      puts "Error: beads not initialized in this project."
      puts "Run 'bd init' to initialize beads tracking."
      exit 1
    end
    $stderr.puts "Error running '#{cmd}': #{stderr}" unless allow_failure
    return nil if allow_failure
    exit 1
  end

  stdout
end

# Helper to parse JSON from bd output
def parse_json(output)
  return [] if output.nil? || output.strip.empty?
  JSON.parse(output)
rescue JSON::ParserError
  []
end

# Find review-summary issues (open issues with review-summary label)
output = run_bd("list --status open --label review-summary --json")
review_summaries = parse_json(output)

if review_summaries.empty?
  puts "❌ No review-summary found"
  puts "\nAction: Perform a full code review of uncommitted changes"
  exit 0
end

# Take the first review summary
review_summary = review_summaries.first
review_id = review_summary['id']

puts "📋 Found review-summary: #{review_id}"
puts "   Title: #{review_summary['title']}"
puts "\n" + "=" * 60

# Get children of the review summary (blocking tickets)
output = run_bd("show #{review_id} --json")
review_details = parse_json(output)
review_details = review_details.first if review_details.is_a?(Array)

children = review_details['children'] || []

if children.empty?
  puts "\n⚠️  No child tickets found for this review."
  puts "The review-summary may need to be manually verified."
  exit 1
end

puts "\n📝 Tickets from review:"

blocking_unresolved = []
all_resolved = true

children.each_with_index do |child_id, idx|
  # Get child status
  child_output = run_bd("show #{child_id} --json")
  child_details = parse_json(child_output)
  child_details = child_details.first if child_details.is_a?(Array)

  next unless child_details

  status = child_details['status']
  labels = child_details['labels'] || []
  title = child_details['title']
  is_blocking = labels.include?('blocks-approval') || labels.include?('critical')

  if status == 'closed'
    icon = "✅"
    status_text = "completed"
  else
    icon = "❌"
    status_text = status
    all_resolved = false
    blocking_unresolved << child_id if is_blocking
  end

  blocking_marker = is_blocking ? " [BLOCKING]" : ""
  puts "  #{idx + 1}. #{icon} #{child_id}: #{title} (#{status_text})#{blocking_marker}"
end

puts "\n" + "=" * 60

if blocking_unresolved.any?
  puts "\n🚫 BLOCKING ISSUES REMAIN:"
  blocking_unresolved.each do |id|
    puts "   - #{id}"
  end
  puts "\n❌ Review NOT complete - address blocking issues first"
  puts "\nNext steps:"
  puts "  1. Work on blocking tickets: bd show <ticket-id>"
  puts "  2. Close completed tickets: bd close <ticket-id>"
  puts "  3. Re-run this check"
  exit 1
elsif !all_resolved
  puts "\n⚠️  Some non-blocking issues remain open."
  puts "These can be addressed in follow-up PRs."
  puts "\n✅ No BLOCKING issues remain!"
  puts "\nClosing review-summary..."

  # Close the review summary
  run_bd("close #{review_id}")
  puts "✅ Closed: #{review_id}"

  puts "\n🎉 Code is ready for approval!"
  puts "\nSuggested next steps:"
  puts "  1. Run final test suite"
  puts "  2. Verify all changes are committed"
  puts "  3. Create pull request or merge to main"
  exit 0
else
  puts "\n✅ All issues resolved!"
  puts "\nClosing review-summary..."

  # Close the review summary
  run_bd("close #{review_id}")
  puts "✅ Closed: #{review_id}"

  puts "\n🎉 Code is ready for approval!"
  puts "\nSuggested next steps:"
  puts "  1. Run final test suite"
  puts "  2. Verify all changes are committed"
  puts "  3. Create pull request or merge to main"
  exit 0
end
