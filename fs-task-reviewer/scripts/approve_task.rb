#!/usr/bin/env ruby
# frozen_string_literal: true

# Approve a task by closing it and adding review-passed label

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

# Check for task ID argument
target_id = ARGV[0]

if target_id.nil?
  # Find tasks with ready-for-review label that are unblocked
  # bd ready automatically filters out blocked tasks
  output = run_bd("ready --label ready-for-review --json")
  tasks = parse_json(output)

  if tasks.empty?
    puts "No tasks ready for review."
    puts ""
    puts "Note: Tasks with ready-for-review label but blocked by dependencies"
    puts "will not appear here. Check 'bd blocked' to see blocked tasks."
    exit 0
  elsif tasks.length == 1
    target_id = tasks.first['id']
  else
    puts "Multiple tasks ready for review. Please specify task ID:"
    tasks.each do |task|
      puts "  - #{task['id']}: #{task['title']}"
    end
    exit 1
  end
end

# Add review-passed label and close the task
run_bd("update #{target_id} --add-label review-passed --remove-label ready-for-review")
run_bd("close #{target_id}")

puts "✓ Review passed! Closed #{target_id}."
