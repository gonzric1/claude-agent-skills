#!/usr/bin/env ruby
# frozen_string_literal: true

# Get tasks marked as ready-for-review

require 'json'
require 'open3'

# Helper to run bd commands
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

# Helper to parse JSON from bd output
def parse_json(output)
  return [] if output.strip.empty?
  JSON.parse(output)
rescue JSON::ParserError => e
  $stderr.puts "Failed to parse JSON: #{e.message}"
  []
end

# Find tasks with ready-for-review label that are unblocked
# bd ready automatically filters out blocked, in_progress, deferred, and hooked issues
output = run_bd("ready --label ready-for-review --json")
tasks = parse_json(output)

if tasks.empty?
  puts "No tasks ready for review."
  puts ""
  puts "Note: Tasks with ready-for-review label but blocked by dependencies"
  puts "will not appear here. Check 'bd blocked' to see blocked tasks."
  exit 0
end

# Sort by priority (lower = higher priority)
tasks.sort_by! { |t| t['priority'] || 3 }

puts "Tasks ready for review:"
tasks.each_with_index do |task, idx|
  priority = task['priority'] || 3
  puts "  #{idx + 1}. #{task['id']}: #{task['title']} (P#{priority})"
end

# Review the first (highest priority) task
first_task = tasks.first
task_id = first_task['id']

# Set tmux pane title to show task being reviewed
if ENV['TMUX']
  pane_title = "REVIEWING: #{first_task['title'][0..50]}".gsub("'", "")
  system("tmux select-pane -T '#{pane_title}'")
  # Disable automatic-rename to prevent tmux from overwriting our title
  system("tmux set-option -p automatic-rename off")
end

puts "\nReviewing first task: #{task_id}"
puts "\n--- Task Content ---"
puts run_bd("show #{task_id}")
puts "--------------------"
