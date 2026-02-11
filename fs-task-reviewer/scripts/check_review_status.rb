#!/usr/bin/env ruby
# frozen_string_literal: true

# Check status of tasks in review (tasks with ready-for-review label)
# Shows which tasks are ready for review and which are blocked by dependencies

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

  # Find where JSON starts
  lines = output.split("\n")
  json_start_idx = lines.index { |line| line.strip.start_with?('{') || line.strip.start_with?('[') }
  return [] if json_start_idx.nil?

  json_text = lines[json_start_idx..].join("\n")
  result = JSON.parse(json_text)
  result.is_a?(Hash) ? [result] : result
rescue JSON::ParserError
  []
end

puts "=" * 70
puts "📋 Review Status Check"
puts "=" * 70
puts ""

# Find all tasks with ready-for-review label (both blocked and unblocked)
all_output = run_bd("list --status open --label ready-for-review --json")
all_review_tasks = parse_json(all_output)

if all_review_tasks.empty?
  puts "✅ No tasks currently in review"
  puts ""
  puts "Action: Use 'bd list --status open' to see available work,"
  puts "        or perform a code review of uncommitted changes."
  exit 0
end

# Check which are actually unblocked (ready for review NOW)
ready_output = run_bd("ready --label ready-for-review --json")
ready_tasks = parse_json(ready_output)

ready_ids = ready_tasks.map { |t| t['id'] }
blocked_tasks = all_review_tasks.reject { |t| ready_ids.include?(t['id']) }

# Show unblocked tasks (ready for review now)
if ready_tasks.any?
  puts "✅ Tasks Ready for Review (#{ready_tasks.length})"
  puts "-" * 70
  ready_tasks.each do |task|
    priority = task['priority'] || '?'
    puts "  • #{task['id']} (P#{priority}): #{task['title']}"
  end
  puts ""
end

# Show blocked tasks (awaiting fixes)
if blocked_tasks.any?
  puts "⏳ Tasks Awaiting Fixes (#{blocked_tasks.length})"
  puts "-" * 70

  blocked_tasks.each do |task|
    priority = task['priority'] || '?'
    puts "  • #{task['id']} (P#{priority}): #{task['title']}"

    # Show what's blocking it
    show_output = run_bd("show #{task['id']} --json")
    details = parse_json(show_output).first

    if details && details['blocked_by']&.any?
      puts "    Blocked by:"
      details['blocked_by'].each do |blocker_id|
        # Get blocker status
        blocker_output = run_bd("show #{blocker_id} --json", allow_failure: true)
        blocker = parse_json(blocker_output).first

        if blocker
          status = blocker['status']
          icon = status == 'closed' ? '✅' : '❌'
          puts "      #{icon} #{blocker_id}: #{blocker['title']} (#{status})"
        else
          puts "      ⚠️  #{blocker_id}: (not found)"
        end
      end
    end
    puts ""
  end
end

puts "=" * 70

# Summary and next steps
if ready_tasks.any?
  puts "\n✅ #{ready_tasks.length} task(s) ready for review"
  puts ""
  puts "Next steps:"
  puts "  ruby .agent/skills/fs-task-reviewer/scripts/get_task_for_review.rb"
  puts "  (or run: bd ready --label ready-for-review)"
elsif blocked_tasks.any?
  puts "\n⏳ All tasks in review are blocked by dependencies"
  puts ""
  puts "Next steps:"
  puts "  1. Check blocked task details: bd show <task-id>"
  puts "  2. Work on blocking tickets (they appear in: bd ready)"
  puts "  3. Re-run this check after closing blockers"
  puts ""
  puts "Tasks will automatically become ready for review when blockers are closed."
end

puts ""
