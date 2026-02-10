#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'open3'

# Helper to run bd commands and parse JSON output
def run_bd(args)
  cmd = "bd #{args}"
  stdout, stderr, status = Open3.capture3(cmd)

  unless status.success?
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

# Attempt to atomically claim a task.
# Returns true if successful, false if already claimed by another agent.
# Exits on other errors.
def try_claim(task_id)
  cmd = "bd update #{task_id} --claim"
  stdout, stderr, status = Open3.capture3(cmd)

  # Check for "already claimed" error in stderr (bd returns exit 0 even on this error)
  if stderr.include?("already claimed")
    return false
  end

  # Check for other errors
  if stderr =~ /Error|error/ && !stderr.strip.empty?
    $stderr.puts "Error claiming #{task_id}: #{stderr}"
    return false
  end

  true
end

# Helper to parse JSON from bd output
def parse_json(output)
  JSON.parse(output)
rescue JSON::ParserError => e
  $stderr.puts "Failed to parse JSON: #{e.message}"
  $stderr.puts "Output was: #{output}"
  exit 1
end

# Priority label to display name mapping
PRIORITY_LABELS = {
  0 => 'P0 (CRITICAL)',
  1 => 'P1 (MAJOR)',
  2 => 'P2 (MODERATE)',
  3 => 'P3 (TICKET)',
  4 => 'P4 (NIT)'
}.freeze

# Get ready tasks (unblocked, not in_progress)
# bd ready --json returns tasks sorted by priority
output = run_bd("ready --json")
tasks = parse_json(output)

if tasks.empty?
  puts "No tasks ready to work on!"
  puts ""

  # Check for in-progress tasks
  in_progress_output = run_bd("list --status in_progress --json")
  in_progress = parse_json(in_progress_output)

  if in_progress.any?
    puts "Current in-progress tasks:"
    in_progress.each do |task|
      puts "  - #{task['id']}: #{task['title']}"
    end
  end

  # Check for blocked tasks
  blocked_output = run_bd("blocked --json")
  blocked = parse_json(blocked_output)

  if blocked.any?
    puts "\nBlocked tasks (waiting for dependencies):"
    blocked.each do |task|
      blockers = task['blocked_by']&.join(', ') || 'unknown'
      puts "  - #{task['id']}: #{task['title']}"
      puts "    Blocked by: #{blockers}"
    end
  end

  puts ""
  puts "INSTRUCTION: Report this to the user and STOP."
  exit 0
end

puts "Strategy: Priority (P0 > P1 > P2 > P3 > P4), then unblocked tasks first"
puts ""

# Try to claim tasks in priority order until one succeeds
claimed_task = nil
skipped_tasks = []

tasks.each do |task|
  task_id = task['id']

  if try_claim(task_id)
    claimed_task = task
    break
  else
    # Task was already claimed by another agent, try the next one
    skipped_tasks << task
    puts "Task #{task_id} already claimed, trying next..."
  end
end

if claimed_task.nil?
  puts "\nAll #{tasks.length} ready tasks were claimed by other agents!"
  puts ""
  puts "INSTRUCTION: Report this to the user and STOP."
  exit 0
end

task_id = claimed_task['id']
priority = claimed_task['priority'] || 3
priority_label = PRIORITY_LABELS[priority] || "P#{priority}"
labels = claimed_task['labels']&.join(', ') || 'none'
blocked_by = claimed_task['blocked_by']&.join(', ') || 'None'

puts "Claimed task: #{task_id}"
puts "  - Title:       #{claimed_task['title']}"
puts "  - Priority:    #{priority_label}"
puts "  - Labels:      #{labels}"
puts "  - Dependencies: #{blocked_by}"

# Show other ready tasks (not yet claimed)
remaining_tasks = tasks - skipped_tasks - [claimed_task]
if remaining_tasks.any?
  puts "\nOther ready tasks:"
  remaining_tasks[0..4].each do |task|
    p = task['priority'] || 3
    puts "  - #{task['id']}: #{task['title']} (P#{p})"
  end
  puts "  ... and #{remaining_tasks.length - 5} more" if remaining_tasks.length > 5
end

# Get full task details
puts "\n--- Task Content ---\n"
task_output = run_bd("show #{task_id}")
puts task_output
puts "\n--------------------"
