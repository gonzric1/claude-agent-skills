#!/usr/bin/env ruby
# frozen_string_literal: true

# Create a fix ticket during code review
# REQUIRES parent task ID - enforces parent-child relationship for cluster reviews
#
# Usage:
#   ruby create_fix_ticket.rb <parent_id> --title "..." --type bug --priority 1 \
#     --description "..." --acceptance "..."
#
# This script:
# 1. Creates the ticket with --parent set to the reviewed task
# 2. Automatically adds blocking dependency (parent blocked by new ticket)
# 3. Syncs to prevent race conditions

require 'json'
require 'open3'
require 'optparse'

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

# Parse command line arguments
options = {
  type: 'bug',
  priority: 2
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} <parent_task_id> [options]"

  opts.on("-t", "--title TITLE", "Ticket title (required)") do |v|
    options[:title] = v
  end

  opts.on("--type TYPE", "Issue type: bug, task, documentation, test (default: bug)") do |v|
    options[:type] = v
  end

  opts.on("-p", "--priority PRIORITY", Integer, "Priority 0-4 (default: 2)") do |v|
    options[:priority] = v
  end

  opts.on("-d", "--description DESC", "Detailed description") do |v|
    options[:description] = v
  end

  opts.on("-a", "--acceptance CRITERIA", "Acceptance criteria") do |v|
    options[:acceptance] = v
  end

  opts.on("-l", "--labels LABELS", "Comma-separated labels") do |v|
    options[:labels] = v
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end

parser.parse!

# Parent task ID is required as first positional argument
parent_id = ARGV[0]

if parent_id.nil? || parent_id.empty?
  puts "Error: Parent task ID is required."
  puts ""
  puts "Usage: #{$PROGRAM_NAME} <parent_task_id> --title \"Fix issue\" --type bug --priority 1"
  puts ""
  puts "The parent task ID is the task being reviewed. This ensures:"
  puts "  - Fix tickets are linked to the reviewed task"
  puts "  - Cluster reviews show parent + all children together"
  puts "  - No duplicate tickets are created"
  exit 1
end

# Title is required
if options[:title].nil? || options[:title].empty?
  puts "Error: --title is required."
  puts ""
  puts "Usage: #{$PROGRAM_NAME} #{parent_id} --title \"Fix issue\" --type bug --priority 1"
  exit 1
end

# Verify parent task exists
parent_output = run_bd("show #{parent_id} --json", allow_failure: true)
if parent_output.nil? || parent_output.strip.empty?
  puts "Error: Parent task '#{parent_id}' not found."
  exit 1
end

# Parse parent to show context
begin
  parent_data = JSON.parse(parent_output)
  parent_data = parent_data.first if parent_data.is_a?(Array)
  puts "Creating fix ticket for: #{parent_id}"
  puts "  Parent title: #{parent_data['title']}"
  puts ""
rescue JSON::ParserError
  # Continue anyway, we verified it exists
end

# Build the bd create command (WITHOUT --parent to avoid cycle detection)
# We add blocking dependency first, then set parent afterward
create_args = [
  "create",
  "--title", options[:title].to_s,
  "--type", options[:type].to_s,
  "--priority", options[:priority].to_s
]

if options[:description]
  create_args += ["--description", options[:description].to_s]
end

if options[:acceptance]
  create_args += ["--acceptance", options[:acceptance].to_s]
end

if options[:labels]
  create_args += ["--labels", options[:labels].to_s]
end

# Create the ticket
create_cmd = create_args.map { |a| a.include?(' ') ? "\"#{a}\"" : a }.join(' ')
output = run_bd(create_cmd)

# Extract the new ticket ID from output
# Output format: "✓ Created issue: PrintMines-xxx" or "Created PROJ-xxx"
new_id = nil
if output =~ /Created\s+issue:\s*(\S+)/i
  new_id = $1
elsif output =~ /Created\s+(\S+)/i
  new_id = $1
elsif output =~ /(PrintMines-\w+|\w+-\w+)/
  new_id = $1
end

if new_id.nil?
  puts "Warning: Could not extract new ticket ID from output:"
  puts output
  puts ""
  puts "Please manually add blocking dependency:"
  puts "  bd dep add #{parent_id} <new-ticket-id>"
  exit 1
end

puts "✓ Created: #{new_id}"
puts "  Title: #{options[:title]}"
puts "  Type: #{options[:type]}"
puts "  Priority: P#{options[:priority]}"

# Add blocking dependency (parent is blocked by new ticket)
puts ""
puts "Adding blocking dependency..."
dep_result = run_bd("dep add #{parent_id} #{new_id}", allow_failure: true)
if dep_result
  puts "✓ #{parent_id} is now blocked by #{new_id}"
else
  puts "Warning: Could not add blocking dependency"
end

# Now set parent relationship (after dependency is established)
puts ""
puts "Setting parent relationship..."
parent_result = run_bd("update #{new_id} --parent #{parent_id}", allow_failure: true)
if parent_result
  puts "✓ #{new_id} is now a child of #{parent_id}"
else
  puts "Note: Parent relationship not set (dependency still works)"
end

# Sync to persist changes
run_bd("sync", allow_failure: true)

puts ""
puts "Fix ticket created and linked. The parent task (#{parent_id}) will"
puts "remain blocked until this fix ticket is closed."
