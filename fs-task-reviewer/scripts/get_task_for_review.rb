#!/usr/bin/env ruby
# frozen_string_literal: true

# Get task cluster for review (parent + children)
# Clusters prevent duplicate ticket creation by showing all related work together

require 'json'
require 'open3'

DEFAULT_CLUSTER_SIZE = 5
MAX_CLUSTER_SIZE = 10

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

# Fetch all open/in_progress issues for cluster building
def fetch_all_issues
  output = run_bd("export")
  return [] if output.nil?

  output.lines.map { |line| JSON.parse(line.strip) rescue nil }.compact
end

# Find children of a task (issues with parent-child dependency to task_id)
# Includes BOTH open and closed children - closed ones show what was already fixed
def find_children(all_issues, parent_id, max_count)
  children = all_issues.select do |issue|
    # Check if issue has a parent-child dependency pointing to parent_id
    deps = issue['dependencies'] || []
    deps.any? do |dep|
      dep['type'] == 'parent-child' && dep['depends_on_id'] == parent_id
    end
  end

  # Sort: open first (by priority), then closed (by priority)
  children.sort_by do |t|
    [
      t['status'] == 'closed' ? 1 : 0,  # Open first
      t['priority'] || 3
    ]
  end.first(max_count)
end

# Build a cluster: parent task + its children (including closed for context)
def build_cluster(primary_task, all_issues)
  cluster = [primary_task]
  remaining_slots = MAX_CLUSTER_SIZE - 1  # Allow more for context

  # Find children of the primary task (includes closed for context)
  children = find_children(all_issues, primary_task['id'], remaining_slots)
  cluster.concat(children)

  # If we have room and the primary has a parent, include siblings
  if cluster.size < DEFAULT_CLUSTER_SIZE && primary_task['parent_issue_id']
    parent_id = primary_task['parent_issue_id']
    siblings = all_issues.select do |issue|
      issue['parent_issue_id'] == parent_id &&
        issue['id'] != primary_task['id'] &&
        (issue['status'] == 'open' || issue['status'] == 'in_progress') &&
        (issue['labels'] || []).include?('ready-for-review')
    end

    remaining = DEFAULT_CLUSTER_SIZE - cluster.size
    cluster.concat(siblings.first(remaining))
  end

  cluster.uniq { |t| t['id'] }
end

# Main script
puts "=" * 70
puts "📦 Task Cluster Review"
puts "=" * 70
puts ""

# Find tasks with ready-for-review label
# Query for OPEN tasks with ready-for-review label (unclaimed, awaiting review)
# When we claim them below, status changes to in_progress
output = run_bd("list --status open --label ready-for-review --json")
all_review_tasks = parse_json(output)

# Filter to unblocked tasks only
tasks = all_review_tasks.select { |t| (t['dependency_count'] || 0) == 0 }

if tasks.empty?
  blocked = all_review_tasks.select { |t| (t['dependency_count'] || 0) > 0 }

  if blocked.any?
    puts "No unblocked tasks ready for review."
    puts ""
    puts "Tasks blocked by dependencies (#{blocked.length}):"
    blocked.each do |task|
      puts "  - #{task['id']}: #{task['title']} (#{task['dependency_count']} blockers)"
    end
    puts ""
    puts "Close the blocking tickets first, then re-run this script."
  else
    puts "No tasks ready for review."
    puts ""
    puts "Use check_review_status.rb to see the current review state."
  end
  exit 0
end

# Sort by priority (lower = higher priority)
tasks.sort_by! { |t| t['priority'] || 3 }

# Select the highest priority task as cluster root
primary_task = tasks.first

# Fetch all issues for cluster building
all_issues = fetch_all_issues

# Build the cluster
cluster = build_cluster(primary_task, all_issues)

puts "📦 Review Cluster (#{cluster.size} task#{cluster.size == 1 ? '' : 's'}):"
puts "-" * 70

# Separate parent from children for display
parent = cluster.first
children = cluster[1..]

puts "  Parent: #{parent['id']} - #{parent['title']} (P#{parent['priority'] || 3})"

if children.any?
  open_children = children.select { |c| c['status'] != 'closed' }
  closed_children = children.select { |c| c['status'] == 'closed' }

  puts ""
  puts "  Children (#{children.size} total):"

  if open_children.any?
    puts "    Open (need implementation):"
    open_children.each do |child|
      puts "      ○ #{child['id']}: #{child['title']} (P#{child['priority'] || 3})"
    end
  end

  if closed_children.any?
    puts "    Closed (already fixed):"
    closed_children.each do |child|
      puts "      ✓ #{child['id']}: #{child['title']} (P#{child['priority'] || 3})"
    end
  end
else
  puts "  Children: (none)"
end

puts ""

# Show if there are more tasks that could be added
other_ready = tasks.reject { |t| cluster.any? { |c| c['id'] == t['id'] } }
if other_ready.any?
  puts "Other tasks ready for review (separate clusters):"
  other_ready.first(3).each do |task|
    puts "  - #{task['id']}: #{task['title']} (P#{task['priority'] || 3})"
  end
  puts "  ... and #{other_ready.length - 3} more" if other_ready.length > 3
  puts ""
end

# Claim all tasks in the cluster (except closed ones - they're just for context)
puts "Claiming cluster..."
claimed_count = 0
cluster.each do |task|
  # Skip closed tasks (they're included for context, not to be reopened)
  next if task['status'] == 'closed'
  # Only claim if not already in_progress
  if task['status'] != 'in_progress'
    run_bd("update #{task['id']} --status in_progress", allow_failure: true)
    claimed_count += 1
  end
end
run_bd("sync", allow_failure: true)
open_tasks = cluster.count { |t| t['status'] != 'closed' }
closed_tasks = cluster.count { |t| t['status'] == 'closed' }
if closed_tasks > 0
  puts "✓ Claimed #{open_tasks} task(s) (#{closed_tasks} closed task(s) shown for context)"
else
  puts "✓ Claimed #{open_tasks} task(s)"
end

# Set tmux pane title
if ENV['TMUX']
  pane_title = "REVIEWING: #{parent['title'][0..40]}...".gsub("'", "")
  system("tmux select-pane -T '#{pane_title}'")
  system("tmux set-option -p automatic-rename off")
end

# Display full content of each task in the cluster
puts ""
puts "=" * 70
puts "CLUSTER DETAILS"
puts "=" * 70

cluster.each_with_index do |task, idx|
  puts ""
  puts "--- Task #{idx + 1}/#{cluster.size}: #{task['id']} ---"
  puts run_bd("show #{task['id']}")
end

puts ""
puts "=" * 70
puts "⚠️  REVIEW THIS CLUSTER ONLY"
puts "=" * 70
puts ""
puts "When creating fix tickets, use:"
puts "  ruby scripts/create_fix_ticket.rb #{parent['id']} --title \"...\" --type bug --priority N"
puts ""
puts "This ensures fix tickets are linked to the parent for future cluster reviews."
puts ""
puts "After review, approve the cluster with:"
puts "  ruby scripts/approve_task.rb #{parent['id']}"
