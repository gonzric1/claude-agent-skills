#!/usr/bin/env ruby
# frozen_string_literal: true

# Approve a task cluster by closing the parent and all its children
# Also cleans up dependencies pointing to closed tasks

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
  result = JSON.parse(output)
  result.is_a?(Array) ? result : [result]
rescue JSON::ParserError => e
  $stderr.puts "Failed to parse JSON: #{e.message}"
  []
end

# Fetch all issues for cluster operations
def fetch_all_issues
  output = run_bd("export")
  return [] if output.nil?

  output.lines.map { |line| JSON.parse(line.strip) rescue nil }.compact
end

# Find children of a task (issues with parent-child dependency to task_id)
def find_children(all_issues, parent_id)
  all_issues.select do |issue|
    next false if issue['status'] == 'closed'
    # Check if issue has a parent-child dependency pointing to parent_id
    deps = issue['dependencies'] || []
    deps.any? do |dep|
      dep['type'] == 'parent-child' && dep['depends_on_id'] == parent_id
    end
  end
end

# Clean up dependencies pointing to closed issues
# This prevents other issues from being blocked by closed issues
def cleanup_dependencies_for(closed_ids, all_issues)
  puts "Cleaning up dependencies..."

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

  if cleaned > 0
    puts "  Cleaned #{cleaned} dependency reference(s)"
  else
    puts "  No stale dependencies found"
  end
end

# Check for task ID argument
target_id = ARGV[0]

if target_id.nil?
  # Query for tasks with ready-for-review label (open=unclaimed, in_progress=claimed)
  output = run_bd("list --label ready-for-review --json")
  all_tasks = parse_json(output)

  # Filter to unblocked tasks only (dependency_count == 0)
  tasks = all_tasks.select { |t| (t['dependency_count'] || 0) == 0 }

  if tasks.empty?
    # Check if there are blocked tasks
    blocked = all_tasks.select { |t| (t['dependency_count'] || 0) > 0 }

    if blocked.any?
      puts "No unblocked tasks ready for review."
      puts ""
      puts "Tasks blocked by dependencies:"
      blocked.each do |task|
        puts "  - #{task['id']}: #{task['title']} (#{task['dependency_count']} blockers)"
      end
      puts ""
      puts "Close the blocking tickets first, then re-run this script."
    else
      puts "No tasks ready for review."
      puts ""
      puts "Tasks with ready-for-review label should have status=in_progress."
      puts "Run check_review_status.rb to see the current state."
    end
    exit 0
  elsif tasks.length == 1
    target_id = tasks.first['id']
  else
    puts "Multiple tasks ready for review. Please specify task ID:"
    tasks.sort_by { |t| t['priority'] || 3 }.each do |task|
      priority = task['priority'] || 3
      puts "  - #{task['id']}: #{task['title']} (P#{priority})"
    end
    exit 1
  end
end

# Verify the task exists and has the right label
output = run_bd("show #{target_id} --json")
task_data = parse_json(output).first

if task_data.nil?
  puts "Error: Task #{target_id} not found."
  exit 1
end

labels = task_data['labels'] || []
unless labels.include?('ready-for-review')
  puts "Warning: Task #{target_id} does not have ready-for-review label."
  puts "Current labels: #{labels.join(', ')}"
  puts "Proceeding anyway..."
end

# Fetch all issues to find children
all_issues = fetch_all_issues

# Find children of the target task (the cluster)
children = find_children(all_issues, target_id)
cluster = [task_data] + children

puts ""
puts "📦 Approving cluster (#{cluster.size} task#{cluster.size == 1 ? '' : 's'}):"
puts "  Parent: #{target_id} - #{task_data['title']}"
if children.any?
  children.each do |child|
    puts "  Child:  #{child['id']} - #{child['title']}"
  end
end
puts ""

# Close all tasks in the cluster
closed_ids = []
cluster.each do |task|
  task_id = task['id']

  # Update labels and close
  if (task['labels'] || []).include?('ready-for-review')
    run_bd("update #{task_id} --add-label review-passed --remove-label ready-for-review", allow_failure: true)
  else
    run_bd("update #{task_id} --add-label review-passed", allow_failure: true)
  end

  run_bd("close #{task_id}", allow_failure: true)
  closed_ids << task_id
  puts "✓ Closed #{task_id}"
end

# Clean up dependencies pointing to all closed tasks
cleanup_dependencies_for(closed_ids, all_issues)

# Sync to persist changes
run_bd("sync", allow_failure: true)

# Count remaining ready-for-review tasks
output = run_bd("list --label ready-for-review --json")
all_remaining = parse_json(output)
remaining_tasks = all_remaining.select { |t| (t['dependency_count'] || 0) == 0 }

if remaining_tasks.any?
  puts ""
  puts "📋 #{remaining_tasks.length} task#{remaining_tasks.length == 1 ? '' : 's'} remaining for review:"
  remaining_tasks.sort_by { |t| t['priority'] || 3 }[0..4].each do |task|
    priority = task['priority'] || 3
    puts "  - #{task['id']}: #{task['title']} (P#{priority})"
  end
  puts "  ... and #{remaining_tasks.length - 5} more" if remaining_tasks.length > 5
else
  puts ""
  puts "✨ No more tasks ready for review!"

  # Check if there are blocked tasks waiting
  blocked = all_remaining.select { |t| (t['dependency_count'] || 0) > 0 }
  if blocked.any?
    puts ""
    puts "📋 #{blocked.length} task#{blocked.length == 1 ? '' : 's'} blocked, waiting for dependencies:"
    blocked[0..2].each do |task|
      puts "  - #{task['id']}: #{task['title']}"
    end
    puts "  ... and #{blocked.length - 3} more" if blocked.length > 3
  end
end
