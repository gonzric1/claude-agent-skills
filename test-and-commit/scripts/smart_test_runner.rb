#!/usr/bin/env ruby
require 'open3'
require 'set'

# Configuration
TEST_DIR = 'test'

def run_command(command)
  stdout, stderr, status = Open3.capture3(command)
  return stdout.split("\n"), status.success?
end

def get_changed_files
  # Get both staged and unstaged changes
  unstaged, _ = run_command("git diff --name-only")
  staged, _ = run_command("git diff --cached --name-only")
  (unstaged + staged).uniq.select { |f| File.exist?(f) }
end

def infer_constants(file_path)
  # Basic heuristic to infer constant names from file paths
  # e.g., app/models/user.rb -> User
  # e.g., app/services/etsy/sync_service.rb -> Etsy::SyncService
  parts = file_path.sub(/\.[^.]+$/, '').split('/')
  
  # Remove common prefixes
  parts.shift if %w[app lib].include?(parts.first)
  parts.shift if %w[models services controllers jobs helpers].include?(parts.first)

  # CamelCase
  parts.map { |p| p.split('_').map(&:capitalize).join }.join('::')
end

def find_associated_tests(file_path)
  tests = Set.new
  
  # 1. Direct mapping check (e.g., app/models/foo.rb -> test/models/foo_test.rb)
  if file_path.start_with?('app/')
    test_path = file_path.sub(/^app/, 'test').sub(/\.rb$/, '_test.rb')
    # Handle specific rails folders normalization if needed, but simple sub often works
    tests.add(test_path) if File.exist?(test_path)
  elsif file_path.start_with?('lib/')
    test_path = file_path.sub(/^lib/, 'test/lib').sub(/\.rb$/, '_test.rb')
    tests.add(test_path) if File.exist?(test_path)
  end

  # 2. Grep for usages
  # Skip non-ruby files for constant inference for now, or handle appropriately
  if file_path.end_with?('.rb')
    constant_name = infer_constants(file_path)
    unless constant_name.empty?
      # Grep in test dir
      # -r recursive, -l files with matches
      grep_cmd = "grep -r -l '#{constant_name}' #{TEST_DIR}"
      matching_files, _ = run_command(grep_cmd)
      matching_files.each { |f| tests.add(f) if f.end_with?('_test.rb') }
    end
  end

  tests
end

def main
  puts "🔍 Analyzing changes..."
  changed_files = get_changed_files
  
  if changed_files.empty?
    puts "No changed files found."
    exit 0
  end

  puts "📝 Changed files:"
  changed_files.each { |f| puts "  - #{f}" }

  test_files = Set.new
  changed_files.each do |file|
    # If the changed file is itself a test, run it
    if file.start_with?(TEST_DIR) && file.end_with?('_test.rb')
      test_files.add(file)
    else
      found = find_associated_tests(file)
      test_files.merge(found)
    end
  end

  if test_files.empty?
    # Check if we can safely skip tests (docs, agent skills, etc)
    is_safe_skip = changed_files.all? do |f| 
      f.end_with?('.md', '.txt') || f.start_with?('.agent/')
    end

    if is_safe_skip
      puts "ℹ️  Only documentation or agent configuration changes detected. Skipping tests."
    else
      puts "⚠️  No relevant tests found for code changes."
      puts "Do you want to proceed with commit anyway? (y/n)"
      answer = $stdin.gets.chomp
      exit 0 unless answer.downcase == 'y'
    end
  else
    puts "\n🧪 Running #{test_files.size} test file(s):"
    test_files.each { |t| puts "  - #{t}" }
    
    cmd = "bin/rails test #{test_files.to_a.join(' ')}"
    puts "\n> #{cmd}"
    
    system(cmd)
    unless $?.success?
      puts "\n❌ Tests failed. Aborting commit."
      exit 1
    end
  puts "\n✅ Tests passed!"
  
  puts "\n🚀 Ready to commit."
  puts "The tests have passed. You should now commit the changes."
  puts "Please read `[[ @assets/COMMIT_TEMPLATE.md ]]` to draft your commit message."
  puts "Then run `git commit -m '...'`"
  puts "⚠️  IMPORTANT: Use single quotes for the message to avoid shell errors with backticks."

  # Check for remaining changes
  remaining, _ = run_command("git status --porcelain")
  if remaining.any?
    puts "\n🔄 STATUS: There are still uncommitted changes."
    puts "👉 ACTION: Please REPEAT the workflow (Analyze -> Test -> Commit) for the remaining files."
  else
    puts "\n✨ STATUS: Working directory clean. You are done!"
  end
end
end

main if __FILE__ == $0
