#!/usr/bin/env ruby
require 'fileutils'

# Define paths relative to current working directory (project root)
AGENT_DIR = File.join(Dir.pwd, '.agent')
TASKS_DIR = File.join(AGENT_DIR, 'tasks')
READY_FOR_REVIEW_DIR = File.join(TASKS_DIR, 'ready-for-review')

# Get all markdown files in ready-for-review
files = Dir.glob(File.join(READY_FOR_REVIEW_DIR, '*.md'))

if files.empty?
  puts "No tasks ready for review."
  exit 0
end

# Sort by modification time (oldest first)
files.sort_by! { |f| File.mtime(f) }

puts "Tasks ready for review:"
files.each_with_index do |file, idx|
  filename = File.basename(file)
  mtime = File.mtime(file).strftime('%Y-%m-%d %H:%M')
  puts "  #{idx + 1}. #{filename} (moved #{mtime})"
end

puts "\nReviewing first task: #{File.basename(files.first)}"
puts "\n--- Task Content ---"
puts File.read(files.first)
puts "--------------------"
