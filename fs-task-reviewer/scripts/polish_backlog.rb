#!/usr/bin/env ruby
# frozen_string_literal: true

# Polish Backlog Manager
#
# Shows polish tasks (P3-P4) that can be worked on during downtime
# Helps prioritize and batch polish work for dedicated time slots
#
# Usage:
#   ruby polish_backlog.rb                    # Show all polish tasks
#   ruby polish_backlog.rb --limit 10         # Show top 10 by priority
#   ruby polish_backlog.rb --type documentation  # Filter by type
#   ruby polish_backlog.rb --stats            # Show statistics only

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
  limit: nil,
  type: nil,
  stats_only: false
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

  opts.on("-l", "--limit N", Integer, "Limit results to N tasks") do |v|
    options[:limit] = v
  end

  opts.on("-t", "--type TYPE", "Filter by type (documentation, bug, task, test)") do |v|
    options[:type] = v
  end

  opts.on("-s", "--stats", "Show statistics only") do
    options[:stats_only] = true
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    puts ""
    puts "Examples:"
    puts "  #{$PROGRAM_NAME}                      # Show all polish tasks"
    puts "  #{$PROGRAM_NAME} --limit 10           # Show top 10"
    puts "  #{$PROGRAM_NAME} --type documentation # Documentation polish only"
    puts "  #{$PROGRAM_NAME} --stats              # Statistics only"
    exit
  end
end

parser.parse!

# Get all polish tasks
output = run_bd("list --label polish --status open --json")

if output.nil? || output.strip.empty?
  puts "No polish tasks found."
  puts ""
  puts "Polish tasks are P3-P4 non-blocking improvements that can be"
  puts "completed during downtime when no feature work is available."
  exit 0
end

# Parse JSON
begin
  tasks = JSON.parse(output)
rescue JSON::ParserError => e
  puts "Error parsing bd output: #{e.message}"
  exit 1
end

# Filter by type if specified
if options[:type]
  tasks = tasks.select { |t| t['type'] == options[:type] }
end

# Sort by priority (ascending) then by created date (oldest first)
tasks.sort_by! { |t| [t['priority'] || 999, t['created_at'] || ''] }

# Group by type and priority
by_type = tasks.group_by { |t| t['type'] || 'unknown' }
by_priority = tasks.group_by { |t| t['priority'] }

# Calculate statistics
total_count = tasks.count
doc_count = by_type['documentation']&.count || 0
p3_count = by_priority[3]&.count || 0
p4_count = by_priority[4]&.count || 0

# Display statistics
puts "=" * 80
puts "POLISH BACKLOG SUMMARY"
puts "=" * 80
puts ""
puts "Total polish tasks: #{total_count}"
puts "  P3 (Standard): #{p3_count}"
puts "  P4 (Nit):      #{p4_count}"
puts ""
puts "By Type:"
by_type.each do |type, type_tasks|
  puts "  #{type.capitalize}: #{type_tasks.count}"
end
puts ""

if options[:stats_only]
  exit 0
end

# Display tasks
puts "=" * 80
puts "POLISH TASKS (Sorted by Priority)"
puts "=" * 80
puts ""

limit = options[:limit] || tasks.count
tasks.first(limit).each_with_index do |task, index|
  priority_label = case task['priority']
  when 3 then 'P3'
  when 4 then 'P4'
  else "P#{task['priority']}"
  end

  type_label = task['type'] || 'task'

  puts "#{index + 1}. [#{priority_label}] [#{type_label}] #{task['id']}"
  puts "   #{task['title']}"

  # Show labels if present
  labels = task['labels'] || []
  labels_without_polish = labels - ['polish']
  if labels_without_polish.any?
    puts "   Labels: #{labels_without_polish.join(', ')}"
  end

  puts ""
end

if tasks.count > limit
  puts "... (#{tasks.count - limit} more tasks)"
  puts "    Use --limit to show more"
  puts ""
end

# Recommendations
puts "=" * 80
puts "RECOMMENDATIONS"
puts "=" * 80
puts ""
puts "1. Schedule 'Polish Friday' or dedicated polish time slots"
puts "2. Pick 3-5 tasks from the top of this list during downtime"
puts "3. Focus on P3 tasks first (higher value than P4)"
puts "4. Consider batching by type (all documentation, then all refactoring)"
puts ""
puts "To work on a task:"
puts "  bd update <task-id> --status in_progress"
puts "  # Complete the work"
puts "  bd close <task-id>"
puts ""
puts "To filter further:"
puts "  #{$PROGRAM_NAME} --type documentation --limit 5"
