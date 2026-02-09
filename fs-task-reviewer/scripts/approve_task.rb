#!/usr/bin/env ruby
require 'fileutils'

# Define paths
SKILLS_DIR = File.expand_path('../..', __dir__) # .agent/skills
AGENT_DIR = File.dirname(SKILLS_DIR)            # .agent
TASKS_DIR = File.join(AGENT_DIR, 'tasks')
READY_FOR_REVIEW_DIR = File.join(TASKS_DIR, 'ready-for-review')
COMPLETED_DIR = File.join(TASKS_DIR, 'completed')

FileUtils.mkdir_p(COMPLETED_DIR)

# Check args
target_file = ARGV[0]

if target_file.nil?
  files = Dir.glob(File.join(READY_FOR_REVIEW_DIR, '*.md'))
  if files.empty?
    puts "No tasks ready for review."
    exit 0
  elsif files.length == 1
    target_file = File.basename(files.first)
  else
    puts "Multiple tasks ready for review. Please specify filename:"
    files.each { |f| puts "- #{File.basename(f)}" }
    exit 1
  end
end

source_path = File.join(READY_FOR_REVIEW_DIR, target_file)

# Try exact match first, then checks if user just passed filename without extension or relative path
unless File.exist?(source_path)
  # Check if user passed full path
  if File.exist?(target_file)
    source_path = target_file
    target_file = File.basename(target_file)
  end
end

if File.exist?(source_path)
  dest_path = File.join(COMPLETED_DIR, target_file)
  FileUtils.mv(source_path, dest_path)
  puts "✓ Review passed! Moved #{target_file} to completed."
else
  puts "File not found: #{source_path}"
  exit 1
end
