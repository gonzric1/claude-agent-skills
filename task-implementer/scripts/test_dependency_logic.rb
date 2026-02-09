#!/usr/bin/env ruby
# Test script for dependency logic

require 'fileutils'
require 'date'

# Define paths
SKILLS_DIR = File.expand_path('../..', __dir__)
AGENT_DIR = File.dirname(SKILLS_DIR)
TASKS_DIR = File.join(AGENT_DIR, 'tasks')
TODO_DIR = File.join(TASKS_DIR, 'to-do')
IN_PROGRESS_DIR = File.join(TASKS_DIR, 'in-progress')
TEST_DIR = File.join(TASKS_DIR, 'test')

# Helper to parse order number from TICKET filename
def get_order_number(file_path)
  filename = File.basename(file_path)
  match = filename.match(/^TICKET-(\d{2})-/)
  match ? match[1].to_i : nil
end

# Check if a task has unmet dependencies
def has_unmet_dependencies?(file_path, in_progress_dir)
  order_num = get_order_number(file_path)
  return false if order_num.nil?

  in_progress_files = Dir.glob(File.join(in_progress_dir, 'TICKET-*.md'))

  in_progress_files.any? do |in_progress_file|
    in_progress_order = get_order_number(in_progress_file)
    in_progress_order && in_progress_order < order_num
  end
end

# Setup test environment
FileUtils.mkdir_p(TEST_DIR)
test_todo = File.join(TEST_DIR, 'to-do')
test_progress = File.join(TEST_DIR, 'in-progress')
FileUtils.mkdir_p(test_todo)
FileUtils.mkdir_p(test_progress)

puts "Testing dependency logic..."
puts "=" * 50

# Test 1: No dependencies (empty in-progress)
puts "\nTest 1: No dependencies (empty in-progress)"
File.write(File.join(test_todo, 'TICKET-01-2026-02-07-first.md'), 'content')
File.write(File.join(test_todo, 'TICKET-02-2026-02-07-second.md'), 'content')

result = has_unmet_dependencies?(File.join(test_todo, 'TICKET-01-2026-02-07-first.md'), test_progress)
puts "  TICKET-01 has dependencies: #{result} (expected: false)"
puts "  ✓ PASS" if result == false

result = has_unmet_dependencies?(File.join(test_todo, 'TICKET-02-2026-02-07-second.md'), test_progress)
puts "  TICKET-02 has dependencies: #{result} (expected: false)"
puts "  ✓ PASS" if result == false

# Test 2: TICKET-01 in progress, TICKET-02 should be blocked
puts "\nTest 2: TICKET-01 in progress blocks TICKET-02"
File.write(File.join(test_progress, 'TICKET-01-2026-02-07-first.md'), 'content')

result = has_unmet_dependencies?(File.join(test_todo, 'TICKET-02-2026-02-07-second.md'), test_progress)
puts "  TICKET-02 has dependencies: #{result} (expected: true)"
puts "  ✓ PASS" if result == true

# Test 3: Same order number (can run in parallel)
puts "\nTest 3: Same order numbers can run in parallel"
# Clear previous test data
FileUtils.rm_rf(Dir.glob(File.join(test_progress, '*.md')))

File.write(File.join(test_todo, 'TICKET-05-2026-02-07-parallel-a.md'), 'content')
File.write(File.join(test_todo, 'TICKET-05-2026-02-07-parallel-b.md'), 'content')
File.write(File.join(test_progress, 'TICKET-05-2026-02-07-parallel-c.md'), 'content')

result = has_unmet_dependencies?(File.join(test_todo, 'TICKET-05-2026-02-07-parallel-a.md'), test_progress)
puts "  TICKET-05 (a) has dependencies: #{result} (expected: false)"
puts "  ✓ PASS" if result == false

# Test 4: Non-TICKET files have no dependencies
puts "\nTest 4: Non-TICKET files always runnable"
File.write(File.join(test_todo, 'CRITICAL-2026-02-07-urgent.md'), 'content')

result = has_unmet_dependencies?(File.join(test_todo, 'CRITICAL-2026-02-07-urgent.md'), test_progress)
puts "  CRITICAL task has dependencies: #{result} (expected: false)"
puts "  ✓ PASS" if result == false

# Cleanup
FileUtils.rm_rf(TEST_DIR)
puts "\n" + "=" * 50
puts "All tests completed!"
