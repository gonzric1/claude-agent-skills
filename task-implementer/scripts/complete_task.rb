#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'open3'

# Helper to run bd commands and parse JSON output
def run_bd(args, allow_failure: false)
  cmd = "bd #{args}"
  stdout, stderr, status = Open3.capture3(cmd)

  unless status.success? || allow_failure
    if stderr.include?("No beads repository found")
      puts "Error: beads not initialized in this project."
      puts "Run 'bd init' to initialize beads tracking."
      exit 1
    end
    $stderr.puts "Error running '#{cmd}': #{stderr}"
    exit 1
  end

  stdout
end

# Helper to parse JSON from bd output
def parse_json(output)
  return [] if output.strip.empty?
  JSON.parse(output)
rescue JSON::ParserError => e
  $stderr.puts "Failed to parse JSON: #{e.message}"
  $stderr.puts "Output was: #{output}"
  exit 1
end

# Check for task ID argument
target_id = ARGV[0]

# Find in-progress tasks
output = run_bd("list --status in_progress --json")
in_progress = parse_json(output)

if in_progress.empty?
  puts "No tasks currently in progress."
  exit 0
end

if target_id.nil?
  if in_progress.length == 1
    target_id = in_progress.first['id']
  else
    puts "Multiple tasks in progress. Please specify task ID:"
    in_progress.each do |task|
      puts "  - #{task['id']}: #{task['title']}"
    end
    exit 1
  end
end

# Verify task exists and is in progress
task = in_progress.find { |t| t['id'] == target_id }

unless task
  puts "Task #{target_id} is not in progress."
  puts "\nCurrent in-progress tasks:"
  in_progress.each do |t|
    puts "  - #{t['id']}: #{t['title']}"
  end
  exit 1
end

# Mark task as ready for review by:
# 1. Setting status back to open (so it shows in lists)
# 2. Adding ready-for-review label
run_bd("update #{target_id} --status open --add-label ready-for-review")

# Sync immediately to commit and push the change before the daemon's
# auto-pull can overwrite it with stale remote data (race condition fix)
run_bd("sync", allow_failure: true)

puts "Marked #{target_id} as ready for review."
puts "  - Title: #{task['title']}"
puts "  - Status: open"
puts "  - Added label: ready-for-review"
puts ""
puts "The task will be picked up by fs-task-reviewer for code review."

# Count remaining ready tasks (excluding ready-for-review)
output = run_bd("ready --json")
all_tasks = parse_json(output)
remaining_tasks = all_tasks.reject do |t|
  labels = t['labels'] || []
  labels.include?('ready-for-review')
end

if remaining_tasks.any?
  puts ""
  puts "📋 #{remaining_tasks.length} task#{remaining_tasks.length == 1 ? '' : 's'} remaining to implement:"
  remaining_tasks[0..4].each do |t|
    priority = t['priority'] || 3
    puts "  - #{t['id']}: #{t['title']} (P#{priority})"
  end
  puts "  ... and #{remaining_tasks.length - 5} more" if remaining_tasks.length > 5
else
  puts ""
  puts "✨ No more tasks ready to implement!"
end
