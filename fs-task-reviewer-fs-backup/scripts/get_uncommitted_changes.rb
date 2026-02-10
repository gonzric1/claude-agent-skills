#!/usr/bin/env ruby
# frozen_string_literal: true

# Get uncommitted changes for code review

def run_git_command(cmd)
  output = `#{cmd} 2>&1`
  return nil unless $?.success?
  output.strip
end

def check_git_repo
  run_git_command("git rev-parse --git-dir")
end

def get_uncommitted_files
  # Get staged, unstaged, and untracked files
  staged = run_git_command("git diff --cached --name-only")&.split("\n") || []
  unstaged = run_git_command("git diff --name-only")&.split("\n") || []
  untracked = run_git_command("git ls-files --others --exclude-standard")&.split("\n") || []

  {
    staged: staged,
    unstaged: unstaged,
    untracked: untracked,
    all: (staged + unstaged + untracked).uniq.sort
  }
end

def get_file_stats
  files = get_uncommitted_files

  stats = {
    total: files[:all].length,
    staged: files[:staged].length,
    unstaged: files[:unstaged].length,
    untracked: files[:untracked].length
  }

  # Categorize by file type
  categories = {
    ruby: files[:all].select { |f| f.end_with?(".rb") },
    typescript: files[:all].select { |f| f.match?(/\.(ts|tsx)$/) },
    tests: files[:all].select { |f| f.include?("/test/") || f.include?("/__tests__/") },
    docs: files[:all].select { |f| f.end_with?(".md") },
    config: files[:all].select { |f| f.match?(/\.(yml|yaml|json)$/) },
    other: []
  }

  # Calculate "other"
  categorized = categories.values.flatten.uniq
  categories[:other] = files[:all] - categorized

  { stats: stats, files: files, categories: categories }
end

# Main execution
unless check_git_repo
  puts "❌ Not a git repository"
  exit 1
end

result = get_file_stats

if result[:stats][:total].zero?
  puts "✅ No uncommitted changes found"
  puts "\nWorking directory is clean."
  exit 0
end

puts "📊 Uncommitted Changes Summary"
puts "=" * 60
puts "\nTotal files changed: #{result[:stats][:total]}"
puts "  • Staged:    #{result[:stats][:staged]}"
puts "  • Unstaged:  #{result[:stats][:unstaged]}"
puts "  • Untracked: #{result[:stats][:untracked]}"

puts "\n📁 By Category:"
result[:categories].each do |category, files|
  next if files.empty?
  puts "  • #{category.to_s.capitalize}: #{files.length} files"
end

puts "\n📝 Changed Files:"
puts "-" * 60

result[:files][:all].each do |file|
  status = if result[:files][:staged].include?(file)
             "S" # Staged
           elsif result[:files][:unstaged].include?(file)
             "M" # Modified
           else
             "?" # Untracked
           end

  puts "  [#{status}] #{file}"
end

puts "\n" + "=" * 60
puts "\n✅ Ready for code review"
puts "\nNext step: Perform comprehensive audit of these changes"

exit 0
