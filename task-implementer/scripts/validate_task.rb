#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'open3'

# ANSI color codes
RED = "\e[31m"
GREEN = "\e[32m"
YELLOW = "\e[33m"
BLUE = "\e[34m"
RESET = "\e[0m"

# Helper to run commands and capture output
def run_command(cmd, allow_failure: false)
  stdout, stderr, status = Open3.capture3(cmd)
  unless status.success? || allow_failure
    return nil
  end
  stdout.strip
end

# Helper to run bd commands
def run_bd(args)
  cmd = "bd #{args}"
  stdout, stderr, status = Open3.capture3(cmd)

  unless status.success?
    if stderr.include?("No beads repository found")
      puts "#{RED}✗#{RESET} Error: beads not initialized in this project."
      puts "Run 'bd init' to initialize beads tracking."
      exit 1
    end
    $stderr.puts "#{RED}✗#{RESET} Error running '#{cmd}': #{stderr}"
    exit 1
  end

  stdout.strip
end

# Extract commit hashes from text (7+ character hex strings)
def extract_commits(text)
  # Match 7-40 character hex strings (git hashes)
  text.scan(/\b[0-9a-f]{7,40}\b/i).uniq
end

# Extract file paths from text (common patterns)
def extract_file_paths(text)
  paths = []

  # Match paths like app/models/product.rb, test/controllers/api_controller_test.rb
  paths += text.scan(%r{(?:app|test|config|db|lib)/[a-zA-Z0-9_/.\-]+\.[a-zA-Z]+})

  # Match paths mentioned with backticks
  paths += text.scan(/`([a-zA-Z0-9_\/.\-:]+\.[a-zA-Z]+)`/).flatten

  paths.uniq
end

# Extract code patterns from text (things in backticks or code blocks)
def extract_code_patterns(text)
  patterns = []

  # Match single backtick code
  patterns += text.scan(/`([^`]+)`/).flatten

  # Match code block content
  text.scan(/```.*?\n(.*?)```/m).each do |match|
    patterns << match.first
  end

  patterns.reject { |p| p.include?('bash') || p.include?('ruby') || p.length < 5 }.uniq
end

# Check if a commit exists
def commit_exists?(hash)
  result = run_command("git log --oneline --all | grep -i #{hash}", allow_failure: true)
  !result.nil? && !result.empty?
end

# Get commit details
def get_commit_details(hash)
  run_command("git show --name-only --format='%h %s' #{hash}", allow_failure: true)
end

# Get files changed in a commit
def get_commit_files(hash)
  output = run_command("git show --name-only --format='' #{hash}", allow_failure: true)
  return [] if output.nil?
  output.split("\n").reject(&:empty?)
end

# Check if file exists
def file_exists?(path)
  File.exist?(path)
end

# Search for pattern in codebase
def pattern_in_codebase?(pattern)
  # Escape special regex characters
  escaped_pattern = Regexp.escape(pattern)
  result = run_command("grep -r '#{pattern}' app/ 2>/dev/null | head -n 1", allow_failure: true)
  !result.nil? && !result.empty?
end

# Get file from git blame for pattern
def get_blame_commit(file, pattern)
  result = run_command("git blame #{file} 2>/dev/null | grep -i '#{pattern}' | head -n 1", allow_failure: true)
  return nil if result.nil? || result.empty?

  # Extract commit hash from blame output (first 8 characters)
  result[/^(\^?[0-9a-f]+)/, 1]
end

# Main validation function
def validate_task(task_id)
  puts "#{BLUE}⟳#{RESET} Validating task #{task_id}..."
  puts ""

  # Get task details
  output = run_bd("show #{task_id}")

  # Extract description (everything after "DESCRIPTION" and before next section)
  description = output[/DESCRIPTION\n(.*?)(?=\n[A-Z]+\n|\z)/m, 1]

  unless description
    puts "#{RED}✗#{RESET} Could not extract task description"
    return false
  end

  errors = []
  warnings = []

  # 1. Validate commits
  puts "#{BLUE}1.#{RESET} Checking commit references..."
  commits = extract_commits(description)

  if commits.empty?
    puts "  #{YELLOW}ℹ#{RESET} No commit hashes found in description"
  else
    commits.each do |commit|
      if commit_exists?(commit)
        details = get_commit_details(commit)
        puts "  #{GREEN}✓#{RESET} Commit #{commit} exists"
        puts "    #{details.split("\n").first}" if details
      else
        errors << "Commit #{commit} NOT FOUND in git history"
        puts "  #{RED}✗#{RESET} Commit #{commit} NOT FOUND"
      end
    end
  end
  puts ""

  # 2. Validate file paths
  puts "#{BLUE}2.#{RESET} Checking file paths..."
  files = extract_file_paths(description)

  if files.empty?
    puts "  #{YELLOW}ℹ#{RESET} No file paths found in description"
  else
    files.each do |file|
      if file_exists?(file)
        puts "  #{GREEN}✓#{RESET} File exists: #{file}"
      else
        warnings << "File not found: #{file} (may have been moved/renamed)"
        puts "  #{YELLOW}⚠#{RESET} File not found: #{file}"
      end
    end
  end
  puts ""

  # 3. Validate code patterns (basic check)
  puts "#{BLUE}3.#{RESET} Checking code patterns..."
  patterns = extract_code_patterns(description)

  if patterns.empty?
    puts "  #{YELLOW}ℹ#{RESET} No specific code patterns found in description"
  else
    # Only check first 3 patterns to avoid slowness
    patterns.take(3).each do |pattern|
      next if pattern.length > 100 # Skip very long patterns

      if pattern_in_codebase?(pattern)
        puts "  #{GREEN}✓#{RESET} Pattern found: #{pattern[0..60]}#{'...' if pattern.length > 60}"
      else
        warnings << "Pattern not found in codebase: #{pattern[0..60]}"
        puts "  #{YELLOW}⚠#{RESET} Pattern not found: #{pattern[0..60]}#{'...' if pattern.length > 60}"
      end
    end
  end
  puts ""

  # 4. Cross-reference commits and files
  puts "#{BLUE}4.#{RESET} Cross-referencing commits and files..."

  if commits.any? && files.any?
    commits.each do |commit|
      next unless commit_exists?(commit)

      commit_files = get_commit_files(commit)
      matching_files = files & commit_files

      if matching_files.any?
        puts "  #{GREEN}✓#{RESET} Commit #{commit} changed mentioned files:"
        matching_files.each { |f| puts "    - #{f}" }
      else
        non_matching = files - commit_files
        if non_matching.any?
          warnings << "Commit #{commit} did not change mentioned files: #{non_matching.join(', ')}"
          puts "  #{YELLOW}⚠#{RESET} Commit #{commit} did not change mentioned files:"
          non_matching.each { |f| puts "    - #{f}" }
        end
      end
    end
  else
    puts "  #{YELLOW}ℹ#{RESET} Skipping cross-reference (no commits or files to check)"
  end
  puts ""

  # Summary
  puts "#{BLUE}═══════════════════════════════════════════════════════════════#{RESET}"

  if errors.empty? && warnings.empty?
    puts "#{GREEN}✓ VALIDATION PASSED#{RESET}"
    puts ""
    puts "No issues found. Task description appears factually accurate."
    return true
  elsif errors.empty?
    puts "#{YELLOW}⚠ VALIDATION PASSED WITH WARNINGS#{RESET}"
    puts ""
    puts "Warnings (#{warnings.length}):"
    warnings.each { |w| puts "  #{YELLOW}⚠#{RESET} #{w}" }
    puts ""
    puts "#{YELLOW}Note:#{RESET} These warnings may be acceptable if files were renamed or patterns"
    puts "are in different locations than expected. Review manually."
    return true
  else
    puts "#{RED}✗ VALIDATION FAILED#{RESET}"
    puts ""
    puts "Errors (#{errors.length}):"
    errors.each { |e| puts "  #{RED}✗#{RESET} #{e}" }

    if warnings.any?
      puts ""
      puts "Warnings (#{warnings.length}):"
      warnings.each { |w| puts "  #{YELLOW}⚠#{RESET} #{w}" }
    end

    puts ""
    puts "#{RED}Action required:#{RESET} Update task description to correct factual errors."
    puts "Use 'bd update #{task_id} --description=\"...\"' to fix."
    return false
  end
ensure
  puts "#{BLUE}═══════════════════════════════════════════════════════════════#{RESET}"
  puts ""
end

# CLI entry point
if ARGV.empty?
  puts "Usage: #{$PROGRAM_NAME} <task-id>"
  puts ""
  puts "Examples:"
  puts "  #{$PROGRAM_NAME} PrintMines-abc"
  puts "  #{$PROGRAM_NAME} PrintMines-xyz"
  puts ""
  puts "This script validates that task descriptions contain factually accurate"
  puts "information by checking:"
  puts "  1. Referenced commits exist in git history"
  puts "  2. Mentioned files exist (or existed) in the codebase"
  puts "  3. Code patterns are present in the codebase"
  puts "  4. Commits changed the files mentioned in the description"
  exit 0
end

task_id = ARGV[0]
success = validate_task(task_id)
exit(success ? 0 : 1)
