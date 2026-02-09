#!/usr/bin/env ruby
require 'fileutils'

# Define paths
SKILLS_DIR = File.expand_path('../..', __dir__) # .agent/skills
AGENT_DIR = File.dirname(SKILLS_DIR)            # .agent
TASKS_DIR = File.join(AGENT_DIR, 'tasks')
IN_PROGRESS_DIR = File.join(TASKS_DIR, 'in-progress')
READY_FOR_REVIEW_DIR = File.join(TASKS_DIR, 'ready-for-review')

FileUtils.mkdir_p(READY_FOR_REVIEW_DIR)

# Check args
target_file = ARGV[0]

if target_file.nil?
  files = Dir.glob(File.join(IN_PROGRESS_DIR, '*.md'))
  if files.empty?
    puts "No tasks in progress."
    exit 0
  elsif files.length == 1
    target_file = File.basename(files.first)
  else
    puts "Multiple tasks in progress. Please specify filename:"
    files.each { |f| puts "- #{File.basename(f)}" }
    exit 1
  end
end

source_path = File.join(IN_PROGRESS_DIR, target_file)

# Try exact match first, then checks if user just passed filename without extension or relative path
unless File.exist?(source_path)
  # Check if user passed full path
  if File.exist?(target_file)
    source_path = target_file
    target_file = File.basename(target_file)
  end
end

if File.exist?(source_path)
  dest_path = File.join(READY_FOR_REVIEW_DIR, target_file)
  FileUtils.mv(source_path, dest_path)
  puts "Moved #{target_file} to ready-for-review."
else
  puts "File not found: #{source_path}"
  exit 1
end
