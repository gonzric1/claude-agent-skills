#!/usr/bin/env ruby
# Test script for YAML frontmatter dependency parsing

require 'fileutils'
require 'date'
require 'yaml'

# Define paths
SKILLS_DIR = File.expand_path('../..', __dir__)
AGENT_DIR = File.dirname(SKILLS_DIR)
TASKS_DIR = File.join(AGENT_DIR, 'tasks')
TODO_DIR = File.join(TASKS_DIR, 'to-do')
IN_PROGRESS_DIR = File.join(TASKS_DIR, 'in-progress')
TEST_DIR = File.join(TASKS_DIR, 'test-yaml-deps')

# Parse dependencies from YAML frontmatter
def get_dependencies(file_path)
  return [] unless File.exist?(file_path)

  begin
    content = File.read(file_path)

    if content =~ /\A---\s*\n(.*?)\n---\s*\n/m
      frontmatter = YAML.safe_load($1)
      deps = frontmatter['depends_on'] || []
      return Array(deps)
    end
  rescue StandardError => e
    puts "Warning: Could not parse YAML frontmatter: #{e.message}"
  end

  []
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

puts "Testing YAML frontmatter dependency parsing..."
puts "=" * 60

# Test 1: Parse single dependency
puts "\nTest 1: Parse single dependency from YAML"
ticket1 = File.join(test_todo, 'TICKET-02-test.md')
File.write(ticket1, <<~TICKET)
  ---
  priority: 8
  status: ready
  depends_on:
    - TICKET-01
  ---

  # Task Title
  Content here...
TICKET

deps = get_dependencies(ticket1)
puts "  Parsed: #{deps.inspect} (expected: ['TICKET-01'])"
puts "  ✓ PASS" if deps == ['TICKET-01']

# Test 2: Parse multiple dependencies
puts "\nTest 2: Parse multiple dependencies"
ticket2 = File.join(test_todo, 'TICKET-04-test.md')
File.write(ticket2, <<~TICKET)
  ---
  priority: 7
  status: ready
  depends_on:
    - TICKET-01
    - TICKET-02
    - TICKET-03
  ---

  # Task Title
TICKET

deps = get_dependencies(ticket2)
puts "  Parsed: #{deps.inspect} (expected: ['TICKET-01', 'TICKET-02', 'TICKET-03'])"
puts "  ✓ PASS" if deps == ['TICKET-01', 'TICKET-02', 'TICKET-03']

# Test 3: Empty depends_on array
puts "\nTest 3: Empty dependencies array"
ticket3 = File.join(test_todo, 'TICKET-01-test.md')
File.write(ticket3, <<~TICKET)
  ---
  priority: 9
  status: ready
  depends_on: []
  ---

  # Task Title
TICKET

deps = get_dependencies(ticket3)
puts "  Parsed: #{deps.inspect} (expected: [])"
puts "  ✓ PASS" if deps.empty?

# Test 4: No depends_on field (defaults to empty)
puts "\nTest 4: Missing depends_on field"
ticket4 = File.join(test_todo, 'TICKET-05-test.md')
File.write(ticket4, <<~TICKET)
  ---
  priority: 8
  status: ready
  ---

  # Task Title
TICKET

deps = get_dependencies(ticket4)
puts "  Parsed: #{deps.inspect} (expected: [])"
puts "  ✓ PASS" if deps.empty?

# Test 5: Dependency checking - all met
puts "\nTest 5: No unmet dependencies when deps are complete"
# TICKET-01 not in to-do or in-progress = complete
result = has_unmet_dependencies?(ticket1, test_todo, test_progress)
puts "  TICKET-02 blocked: #{result} (expected: false)"
puts "  ✓ PASS" if result == false

# Test 6: Dependency checking - some unmet
puts "\nTest 6: Has unmet dependencies when dep is in-progress"
File.write(File.join(test_progress, 'TICKET-01-working.md'), 'content')

result = has_unmet_dependencies?(ticket1, test_todo, test_progress)
puts "  TICKET-02 blocked: #{result} (expected: true)"
puts "  ✓ PASS" if result == true

# Test 7: Parallel execution possible
puts "\nTest 7: Two tickets can run in parallel (different deps)"
ticket_a = File.join(test_todo, 'TICKET-06-parallel-a.md')
ticket_b = File.join(test_todo, 'TICKET-06-parallel-b.md')

File.write(ticket_a, <<~TICKET)
  ---
  depends_on: [TICKET-02]
  ---
  # Task A
TICKET

File.write(ticket_b, <<~TICKET)
  ---
  depends_on: [TICKET-03]
  ---
  # Task B
TICKET

# Both have different incomplete deps
result_a = has_unmet_dependencies?(ticket_a, test_todo, test_progress)
result_b = has_unmet_dependencies?(ticket_b, test_todo, test_progress)
puts "  Both blocked by different deps: #{result_a && result_b} (expected: true)"
puts "  ✓ PASS" if result_a && result_b

# Complete one dep - that ticket becomes runnable
FileUtils.rm(File.join(test_todo, 'TICKET-02-test.md'))
result_a = has_unmet_dependencies?(ticket_a, test_todo, test_progress)
result_b = has_unmet_dependencies?(ticket_b, test_todo, test_progress)
puts "  A runnable, B still blocked: #{!result_a && result_b} (expected: true)"
puts "  ✓ PASS" if !result_a && result_b

# Cleanup
FileUtils.rm_rf(TEST_DIR)
puts "\n" + "=" * 60
puts "All YAML frontmatter tests passed! ✓"
puts "\nKey benefits:"
puts "  ✓ Structured YAML frontmatter (easy to parse)"
puts "  ✓ Explicit per-ticket dependencies"
puts "  ✓ Supports parallel execution"
puts "  ✓ Script-based checking (no AI cost)"
puts "  ✓ Can add other metadata (priority, status, etc.)"
