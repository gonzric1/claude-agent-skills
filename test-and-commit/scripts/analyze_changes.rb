#!/usr/bin/env ruby
require 'set'

# Configuration
# Mapping of keywords or paths to categories
CATEGORIES = {
  'infrastructure' => ['Gemfile', 'Dockerfile', 'config/', 'bin/'],
  'database'       => ['db/migrate', 'db/schema.rb', 'db/seeds.rb'],
  'documentation'  => ['.md', 'docs/', '.agent/context/'],
  'agent_skills'   => ['.agent/skills/'],
  'test'           => ['test/', 'spec/']
}

def run_command(command)
  stdout, stderr, status = Open3.capture3(command)
  return stdout.split("\n")
end

def get_changed_files
  require 'open3'
  # Get both staged and unstaged changes
  unstaged = run_command("git diff --name-only")
  staged   = run_command("git diff --cached --name-only")
  (unstaged + staged).uniq.select { |f| File.exist?(f) }
end

def categorize_file(file)
  # 1. Check predefined categories
  CATEGORIES.each do |category, patterns|
    patterns.each do |pattern|
      return category if file.include?(pattern) || file.end_with?(pattern)
    end
  end

  # 2. Domain Feature Heuristic (app/...)
  if file.start_with?('app/')
    parts = file.split('/')
    # e.g., app/models/order.rb -> order
    # e.g., app/controllers/orders_controller.rb -> orders
    # e.g., app/views/orders/index.html.erb -> orders
    
    # Simple extraction of the "feature" name
    # We look at the second segment for standard rails folders (models, controllers, etc)
    if ['models', 'controllers', 'views', 'jobs', 'mailers', 'services'].include?(parts[1])
      # Try to extract feature name from filename or folder
      if parts[1] == 'views'
        return "feature:#{parts[2]}" # views/orders -> feature:orders
      else
        filename = File.basename(file, '.rb')
        # orders_controller -> orders
        feature = filename.sub(/_controller|_job|_mailer|_service/, '').singularize_heuristic
        return "feature:#{feature}"
      end
    end
    
    return 'app:other'
  end

  'other'
end

class String
  def singularize_heuristic
    return self[0..-2] if self.end_with?('s')
    self
  end
end

def main
  puts "🔍 Analyzing changes for commit planning..."
  files = get_changed_files
  
  if files.empty?
    puts "No changed files found."
    exit 0
  end

  groups = Hash.new { |h, k| h[k] = [] }

  files.each do |file|
    category = categorize_file(file)
    groups[category] << file
  end

  puts "\n📊 Suggested Commit Plan:"
  puts "========================"
  
  groups.each do |category, group_files|
    puts "\n📁 Group: #{category.upcase} (#{group_files.size} files)"
    group_files.each { |f| puts "  - #{f}" }
  end

  puts "\n========================"
  if groups.size > 1
    puts "💡 Recommendation: ATOMIC COMMITS"
    puts "   Address each group in a separate commit to keep history clean."
  else
    puts "💡 Recommendation: SINGLE COMMIT"
    puts "   All changes seem related to a single concern."
  end
end

main if __FILE__ == $0
