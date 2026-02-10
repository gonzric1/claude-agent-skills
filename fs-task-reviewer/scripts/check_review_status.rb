#!/usr/bin/env ruby
# frozen_string_literal: true

# Check if a review-summary exists and verify if review items have been addressed

require "fileutils"

# Paths
TODO_DIR = ".agent/tasks/to-do"
COMPLETED_DIR = ".agent/tasks/completed"
REVIEW_SUMMARY_PATTERN = /^REVIEW-SUMMARY-.*\.md$/

def find_review_summary
  return nil unless Dir.exist?(TODO_DIR)

  Dir.entries(TODO_DIR)
     .select { |f| f.match?(REVIEW_SUMMARY_PATTERN) }
     .map { |f| File.join(TODO_DIR, f) }
     .first
end

def parse_review_summary(file_path)
  content = File.read(file_path)

  # Extract tickets from the review summary
  tickets = []

  # Look for the "Tickets Created" section or ticket references
  content.scan(/^### \d+\.\s+\*\*(.+?)\*\*.*?\((\d+)\/10\)/) do |title, priority|
    tickets << {
      title: title,
      priority: priority.to_i,
      blocking: priority.to_i >= 10
    }
  end

  # Also look for ticket filenames
  content.scan(/`((?:CRITICAL|MAJOR|\d+)-\d{4}-\d{2}-\d{2}-.+?\.md)`/) do |filename|
    tickets << {
      filename: filename.first,
      from_reference: true
    }
  end

  tickets
end

def check_ticket_exists(ticket_identifier)
  # Check if ticket exists in to-do
  return :exists if File.exist?(File.join(TODO_DIR, ticket_identifier))

  # Check if ticket was completed (moved to completed)
  return :completed if File.exist?(File.join(COMPLETED_DIR, ticket_identifier))

  :missing
end

def extract_blocking_tickets(tickets)
  tickets.select { |t| t[:blocking] || t[:filename]&.start_with?("CRITICAL") }
end

# Main execution
review_summary = find_review_summary

if review_summary.nil?
  puts "❌ No review-summary found in #{TODO_DIR}"
  puts "\nExpected filename pattern: REVIEW-SUMMARY-YYYY-MM-DD-*.md"
  puts "\nAction: Perform a full code review of uncommitted changes"
  exit 0
end

puts "📋 Found review-summary: #{File.basename(review_summary)}"
puts "\n" + "=" * 60

# Parse the review summary
tickets = parse_review_summary(review_summary)

if tickets.empty?
  puts "⚠️  Could not parse tickets from review summary"
  puts "Please review manually: #{review_summary}"
  exit 1
end

puts "\n📝 Tickets from review:"
tickets.each_with_index do |ticket, idx|
  if ticket[:filename]
    status = check_ticket_exists(ticket[:filename])
    icon = case status
           when :completed then "✅"
           when :exists then "❌"
           when :missing then "⚠️"
           end

    puts "  #{idx + 1}. #{icon} #{ticket[:filename]} (#{status})"
  else
    puts "  #{idx + 1}. #{ticket[:title]} (#{ticket[:priority]}/10)"
  end
end

# Check blocking tickets
blocking_tickets = extract_blocking_tickets(tickets)
blocking_unresolved = blocking_tickets.select do |ticket|
  ticket[:filename] && check_ticket_exists(ticket[:filename]) == :exists
end

puts "\n" + "=" * 60

if blocking_unresolved.any?
  puts "\n🚫 BLOCKING ISSUES REMAIN:"
  blocking_unresolved.each do |ticket|
    puts "   - #{ticket[:filename]}"
  end
  puts "\n❌ Review NOT complete - address blocking issues first"
  puts "\nNext steps:"
  puts "  1. Implement tickets in #{TODO_DIR}"
  puts "  2. Run tests to verify fixes"
  puts "  3. Re-run this check"
  exit 1
else
  puts "\n✅ All blocking issues resolved!"
  puts "\nMoving review-summary to completed..."

  # Move review summary to completed
  dest = File.join(COMPLETED_DIR, File.basename(review_summary))
  FileUtils.mkdir_p(COMPLETED_DIR)
  FileUtils.mv(review_summary, dest)

  puts "✅ Moved: #{dest}"
  puts "\n🎉 Code is ready for approval!"
  puts "\nSuggested next steps:"
  puts "  1. Run final test suite: bundle exec rails test"
  puts "  2. Verify all changes are committed"
  puts "  3. Create pull request or merge to main"
  exit 0
end
