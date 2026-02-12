#!/usr/bin/env ruby
# frozen_string_literal: true

# Close a task and clean up dependencies pointing to it
# This prevents parent tasks from being stuck as "blocked" after fix tickets are closed
#
# Usage:
#   ruby close_task.rb <task_id>
#   ruby close_task.rb <task_id1> <task_id2> ...  # Close multiple tasks
#
# This script:
# 1. Closes the specified task(s)
# 2. Removes any dependencies that point to the closed task(s)
# 3. Syncs to persist changes

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

# Fetch all issues for dependency cleanup
def fetch_all_issues
  output = run_bd("export")
  return [] if output.nil?

  output.lines.map { |line| JSON.parse(line.strip) rescue nil }.compact
end

# Clean up dependencies pointing to closed issues
def cleanup_dependencies_for(closed_ids, all_issues)
  cleaned = 0

  all_issues.each do |issue|
    next if issue['status'] == 'closed'
    next if closed_ids.include?(issue['id'])

    deps = issue['dependencies'] || []

    closed_ids.each do |closed_id|
      blocked_by = deps.select { |d| d['issue_id'] == issue['id'] && d['depends_on_id'] == closed_id }
      next if blocked_by.empty?

      result = run_bd("dep remove #{issue['id']} #{closed_id}", allow_failure: true)
      if result
        puts "  ✓ #{issue['id']} no longer blocked by #{closed_id}"
        cleaned += 1
      end
    end
  end

  cleaned
end

# Check for task ID arguments
task_ids = ARGV.dup

if task_ids.empty?
  puts "Usage: #{$PROGRAM_NAME} <task_id> [task_id2 ...]"
  puts ""
  puts "Closes the specified task(s) and cleans up any dependencies pointing to them."
  puts "This ensures parent tasks are unblocked when fix tickets are completed."
  exit 1
end

# Fetch all issues before closing (for dependency cleanup)
all_issues = fetch_all_issues

# Close each task
closed_ids = []
task_ids.each do |task_id|
  # Verify task exists
  output = run_bd("show #{task_id} --json", allow_failure: true)
  if output.nil? || output.strip.empty?
    puts "Warning: Task '#{task_id}' not found, skipping"
    next
  end

  # Close the task
  result = run_bd("close #{task_id}", allow_failure: true)
  if result
    puts "✓ Closed #{task_id}"
    closed_ids << task_id
  else
    puts "Warning: Could not close #{task_id}"
  end
end

if closed_ids.empty?
  puts "No tasks were closed."
  exit 1
end

# Clean up dependencies pointing to closed tasks
puts ""
puts "Cleaning up dependencies..."
cleaned = cleanup_dependencies_for(closed_ids, all_issues)

if cleaned > 0
  puts "  Cleaned #{cleaned} dependency reference(s)"
else
  puts "  No stale dependencies found"
end

# Sync to persist changes
puts ""
run_bd("sync", allow_failure: true)
puts "✓ Changes synced"

# Show what was unblocked
puts ""
puts "Tasks that may now be unblocked:"
all_issues.each do |issue|
  next if issue['status'] == 'closed'
  next if closed_ids.include?(issue['id'])

  deps = issue['dependencies'] || []
  was_blocked_by_closed = deps.any? do |d|
    d['issue_id'] == issue['id'] && closed_ids.include?(d['depends_on_id'])
  end

  if was_blocked_by_closed
    puts "  • #{issue['id']}: #{issue['title']}"
  end
end
