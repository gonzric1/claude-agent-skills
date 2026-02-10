#!/usr/bin/env ruby
require 'fileutils'
require 'date'
require 'yaml'

# Define paths relative to current working directory (project root)
# This allows the script to work from any location (global skills repo or local)
AGENT_DIR = File.join(Dir.pwd, '.agent')
TASKS_DIR = File.join(AGENT_DIR, 'tasks')
TODO_DIR = File.join(TASKS_DIR, 'to-do')
IN_PROGRESS_DIR = File.join(TASKS_DIR, 'in-progress')

# Ensure directories exist
FileUtils.mkdir_p(IN_PROGRESS_DIR)

# Get all markdown files
files = Dir.glob(File.join(TODO_DIR, '*.md'))

if files.empty?
  puts "No tasks found in #{TODO_DIR}"
  exit 0
end

# Priority mapping for filename-based priorities
PRIORITY_MAP = {
  'CRITICAL' => 10,
  'MAJOR'    => 7,
  'MODERATE' => 4,
  'TICKET'   => 2,
  'NIT'      => 1
}

# Helper to parse priority
def get_priority(file_path)
  filename = File.basename(file_path, '.md') # Remove extension
  
  # Check filename first
  # Expecting: CRITICAL-YYYY-MM-DD-title
  if match = filename.match(/^(CRITICAL|MAJOR|MODERATE|TICKET|NIT)-/i)
    return PRIORITY_MAP[match[1].upcase]
  end

  # Fallback to content
  content = File.read(file_path)
  match = content.match(/\*\*Priority\*\*:\s*(\d+)(\/10)?/i)
  match ? match[1].to_i : 0
end

# Helper to parse date from filename
def get_date(file_path)
  filename = File.basename(file_path)
  # Look for distinct date pattern anywhere in string to handle both:
  # YYYY-MM-DD-title.md
  # CRITICAL-YYYY-MM-DD-title.md
  match = filename.match(/(\d{4}-\d{2}-\d{2})/)
  match ? Date.parse(match[1]) : Date.today + 365 # Default to far future so dated tasks come first
end

# Helper to parse order number from TICKET filename
# Returns nil if not a TICKET or no order number
def get_order_number(file_path)
  filename = File.basename(file_path)
  # Match TICKET-##-YYYY-MM-DD-title.md format
  match = filename.match(/^TICKET-(\d{2})-/)
  match ? match[1].to_i : nil
end

# Parse dependencies from ticket YAML frontmatter
# Returns array of ticket IDs (e.g., ["TICKET-01", "TICKET-02"]) or empty array
def get_dependencies(file_path)
  return [] unless File.exist?(file_path)

  begin
    content = File.read(file_path)

    # Extract YAML frontmatter (between --- markers)
    if content =~ /\A---\s*\n(.*?)\n---\s*\n/m
      frontmatter = YAML.safe_load($1)

      # Get depends_on field (can be array or nil)
      deps = frontmatter['depends_on'] || []
      return Array(deps) # Ensure it's always an array
    end
  rescue StandardError => e
    # If YAML parsing fails, return empty array (fail safe)
    puts "Warning: Could not parse YAML frontmatter for #{File.basename(file_path)}: #{e.message}"
  end

  []
end

# Check if a task has unmet dependencies
# Returns true if any dependency is still in to-do or in-progress
def has_unmet_dependencies?(file_path)
  dependencies = get_dependencies(file_path)
  return false if dependencies.empty?

  # Get all incomplete ticket IDs (in to-do or in-progress)
  incomplete_tickets = []

  [TODO_DIR, IN_PROGRESS_DIR].each do |dir|
    Dir.glob(File.join(dir, 'TICKET-*.md')).each do |ticket_file|
      filename = File.basename(ticket_file, '.md')
      # Extract TICKET-## from filename
      if match = filename.match(/^(TICKET-\d{2})/)
        incomplete_tickets << match[1]
      end
    end
  end

  # Check if any dependency is incomplete
  dependencies.any? { |dep| incomplete_tickets.include?(dep) }
end

# Sort files
sorted_files = files.sort_by do |file|
  priority = get_priority(file)
  date = get_date(file)
  order_num = get_order_number(file) || 999 # Non-TICKETs get high order for sorting

  # Sort by:
  # 1. Order number (for TICKETs) - lower numbers first
  # 2. Priority DESC (-priority)
  # 3. Date ASC (date)
  [order_num, -priority, date]
end

# Filter out tasks with unmet dependencies
available_files = sorted_files.reject { |file| has_unmet_dependencies?(file) }

if available_files.empty?
  puts "No tasks available to run!"
  puts "All tasks have unmet dependencies (waiting for lower-numbered TICKETs to complete)."
  puts "\nIn-progress tasks:"
  Dir.glob(File.join(IN_PROGRESS_DIR, '*.md')).each do |file|
    puts "  - #{File.basename(file)}"
  end
  exit 0
end

next_task = available_files.first
filename = File.basename(next_task)
destination = File.join(IN_PROGRESS_DIR, filename)

priority = get_priority(next_task)
date = get_date(next_task)
order_num = get_order_number(next_task)
dependencies = get_dependencies(next_task)

puts "Strategy: Order # (TICKETs), then Priority High->Low (CRITICAL=10, MAJOR=7, etc), then Date Oldest->Newest"
puts "Running task: #{filename}"
puts "  - Detected Order:    #{order_num || 'N/A'}"
puts "  - Detected Priority: #{priority}"
puts "  - Detected Date:     #{date}"
puts "  - Dependencies:      #{dependencies.empty? ? 'None' : dependencies.join(', ')}"

# Show skipped tasks if any
skipped = sorted_files - available_files
if !skipped.empty?
  puts "\nSkipped tasks (unmet dependencies):"
  skipped.each do |file|
    deps = get_dependencies(file)
    puts "  - #{File.basename(file)}"
    puts "    Waiting for: #{deps.join(', ')}" unless deps.empty?
  end
end

FileUtils.mv(next_task, destination)

puts "\n--- Task Content ---\n"
puts File.read(destination)
puts "\n--------------------"
