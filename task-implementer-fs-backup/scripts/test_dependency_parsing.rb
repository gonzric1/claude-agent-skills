#!/usr/bin/env ruby
# Test script for dependency parsing logic

require 'fileutils'
require 'date'

# Define paths
SKILLS_DIR = File.expand_path('../..', __dir__)
AGENT_DIR = File.dirname(SKILLS_DIR)
TASKS_DIR = File.join(AGENT_DIR, 'tasks')
TODO_DIR = File.join(TASKS_DIR, 'to-do')
IN_PROGRESS_DIR = File.join(TASKS_DIR, 'in-progress')
TEST_DIR = File.join(TASKS_DIR, 'test-dep-parsing')

# Parse dependencies from ticket file
def get_dependencies(file_path)
  return [] unless File.exist?(file_path)

  dependencies = []
  File.open(file_path, 'r') do |file|
    file.first(15).each do |line|
      if match = line.match(/\*\*Depends On\*\*:\s*(.+)/i)
        deps_string = match[1].strip
        next if deps_string =~ /^none$/i || deps_string.empty?
        dependencies = deps_string.scan(/TICKET-\d{2}/)
        break
      end
    end
  end

  dependencies
end

# Check if a task has unmet dependencies
def has_unmet_dependencies?(file_path, todo_dir, in_progress_dir)
  dependencies = get_dependencies(file_path)
  return false if dependencies.empty?

  incomplete_tickets = []

  [todo_dir, in_progress_dir].each do |dir|
    Dir.glob(File.join(dir, 'TICKET-*.md')).each do |ticket_file|
      filename = File.basename(ticket_file, '.md')
      if match = filename.match(/^(TICKET-\d{2})/)
        incomplete_tickets << match[1]
      end
    end
  end

  dependencies.any? { |dep| incomplete_tickets.include?(dep) }
end

# Setup test environment
FileUtils.mkdir_p(TEST_DIR)
test_todo = File.join(TEST_DIR, 'to-do')
test_progress = File.join(TEST_DIR, 'in-progress')
FileUtils.mkdir_p(test_todo)
FileUtils.mkdir_p(test_progress)

puts "Testing dependency parsing logic..."
puts "=" * 60

# Test 1: Parse dependencies from ticket
puts "\nTest 1: Parse dependencies from ticket content"
ticket1 = File.join(test_todo, 'TICKET-02-test.md')
File.write(ticket1, <<~TICKET)
  # Task Title

  **Priority**: 8/10
  **Status**: Ready
  **Depends On**: TICKET-01

  Content here...
TICKET

deps = get_dependencies(ticket1)
puts "  Parsed dependencies: #{deps.inspect} (expected: ['TICKET-01'])"
puts "  ✓ PASS" if deps == ['TICKET-01']

# Test 2: Parse multiple dependencies
puts "\nTest 2: Parse multiple dependencies"
ticket2 = File.join(test_todo, 'TICKET-04-test.md')
File.write(ticket2, <<~TICKET)
  # Task Title

  **Priority**: 8/10
  **Depends On**: TICKET-01, TICKET-02, TICKET-03

  Content...
TICKET

deps = get_dependencies(ticket2)
puts "  Parsed dependencies: #{deps.inspect} (expected: ['TICKET-01', 'TICKET-02', 'TICKET-03'])"
puts "  ✓ PASS" if deps == ['TICKET-01', 'TICKET-02', 'TICKET-03']

# Test 3: Parse "None" as no dependencies
puts "\nTest 3: Parse 'None' as empty dependencies"
ticket3 = File.join(test_todo, 'TICKET-01-test.md')
File.write(ticket3, <<~TICKET)
  # Task Title

  **Priority**: 9/10
  **Depends On**: None

  Content...
TICKET

deps = get_dependencies(ticket3)
puts "  Parsed dependencies: #{deps.inspect} (expected: [])"
puts "  ✓ PASS" if deps.empty?

# Test 4: No dependencies when TICKET-01 is complete
puts "\nTest 4: No unmet dependencies when dep is complete"
# TICKET-01 is not in to-do or in-progress, so it's considered complete
result = has_unmet_dependencies?(ticket1, test_todo, test_progress)
puts "  TICKET-02 has unmet dependencies: #{result} (expected: false)"
puts "  ✓ PASS" if result == false

# Test 5: Has dependencies when TICKET-01 is in progress
puts "\nTest 5: Has unmet dependencies when dep is in progress"
File.write(File.join(test_progress, 'TICKET-01-in-progress.md'), 'content')

result = has_unmet_dependencies?(ticket1, test_todo, test_progress)
puts "  TICKET-02 has unmet dependencies: #{result} (expected: true)"
puts "  ✓ PASS" if result == true

# Test 6: Multiple deps, some met, some not
puts "\nTest 6: Multiple dependencies - some met, some unmet"
File.write(File.join(test_todo, 'TICKET-03-waiting.md'), 'content')

result = has_unmet_dependencies?(ticket2, test_todo, test_progress)
puts "  TICKET-04 has unmet dependencies: #{result} (expected: true)"
puts "  ✓ PASS" if result == true

# Test 7: Parallel execution - same order number, no mutual deps
puts "\nTest 7: Parallel tickets with no dependencies"
ticket_a = File.join(test_todo, 'TICKET-05-parallel-a.md')
ticket_b = File.join(test_todo, 'TICKET-05-parallel-b.md')

File.write(ticket_a, <<~TICKET)
  # Task A
  **Depends On**: TICKET-03
TICKET

File.write(ticket_b, <<~TICKET)
  # Task B
  **Depends On**: TICKET-03
TICKET

# Both depend on TICKET-03 which is in to-do, so both blocked
result_a = has_unmet_dependencies?(ticket_a, test_todo, test_progress)
result_b = has_unmet_dependencies?(ticket_b, test_todo, test_progress)
puts "  TICKET-05-a blocked: #{result_a}, TICKET-05-b blocked: #{result_b} (expected: both true)"
puts "  ✓ PASS" if result_a && result_b

# Complete TICKET-03, now both should be runnable
FileUtils.rm(File.join(test_todo, 'TICKET-03-waiting.md'))
result_a = has_unmet_dependencies?(ticket_a, test_todo, test_progress)
result_b = has_unmet_dependencies?(ticket_b, test_todo, test_progress)
puts "  After TICKET-03 complete - both runnable: #{!result_a && !result_b} (expected: true)"
puts "  ✓ PASS" if !result_a && !result_b

# Cleanup
FileUtils.rm_rf(TEST_DIR)
puts "\n" + "=" * 60
puts "All tests completed!"
puts "\nKey benefits of this approach:"
puts "  • Explicit dependencies (not order-number based)"
puts "  • Multiple agents can work on parallel tickets"
puts "  • Script-based checking (no AI, no cost)"
puts "  • Self-contained (dependencies in each ticket)"
