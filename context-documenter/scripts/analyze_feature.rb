#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'json'

##
# analyze_feature.rb - Analyzes a feature area and suggests documentation structure
#
# Usage: ruby analyze_feature.rb <feature_name>
# Example: ruby analyze_feature.rb etsy

feature_name = ARGV[0]

if feature_name.nil? || feature_name.empty?
  puts "Usage: ruby analyze_feature.rb <feature_name>"
  puts "Example: ruby analyze_feature.rb etsy"
  exit 1
end

# Determine project root (assuming this script is in .agent/skills/context-documenter/scripts)
project_root = File.expand_path("../../../../", __dir__)
Dir.chdir(project_root)

puts "🔍 Analyzing feature: #{feature_name}"
puts "📂 Project root: #{project_root}"
puts ""

# Search for related files
def find_files(pattern)
  `find . -type f -iname "*#{pattern}*" 2>/dev/null`.split("\n").reject do |file|
    file.include?('node_modules') || 
    file.include?('tmp') || 
    file.include?('log') ||
    file.include?('.git')
  end
end

# Analyze file types
models = find_files(feature_name).select { |f| f.include?('app/models') }
services = find_files(feature_name).select { |f| f.include?('app/services') }
controllers = find_files(feature_name).select { |f| f.include?('app/controllers') }
jobs = find_files(feature_name).select { |f| f.include?('app/jobs') }
components = find_files(feature_name).select { |f| f.include?('app/javascript/components') }
tests = find_files(feature_name).select { |f| f.include?('test') }

puts "=" * 60
puts "ANALYSIS RESULTS"
puts "=" * 60
puts ""

# Models
if models.any?
  puts "📊 Models (#{models.count}):"
  models.each { |f| puts "  - #{f}" }
  puts ""
end

# Services
if services.any?
  puts "⚙️  Services (#{services.count}):"
  services.each { |f| puts "  - #{f}" }
  puts ""
end

# Controllers
if controllers.any?
  puts "🎮 Controllers (#{controllers.count}):"
  controllers.each { |f| puts "  - #{f}" }
  puts ""
end

# Jobs
if jobs.any?
  puts "🔄 Jobs (#{jobs.count}):"
  jobs.each { |f| puts "  - #{f}" }
  puts ""
end

# Frontend Components
if components.any?
  puts "⚛️  Components (#{components.count}):"
  components.each { |f| puts "  - #{f}" }
  puts ""
end

# Tests
if tests.any?
  puts "🧪 Tests (#{tests.count}):"
  tests.each { |f| puts "  - #{f}" }
  puts ""
end

# Suggest documentation name
doc_name = "#{feature_name.gsub('_', '-')}.md"
doc_path = File.join(project_root, ".agent/context", doc_name)

puts "=" * 60
puts "SUGGESTED DOCUMENTATION"
puts "=" * 60
puts ""
puts "📄 File name: #{doc_name}"
puts "📍 Full path: #{doc_path}"
puts ""
puts "📋 Suggested sections:"
puts "  1. Overview"
if models.any?
  puts "  2. Core Models"
  models.each do |model|
    model_name = File.basename(model, '.rb').split('_').map(&:capitalize).join
    puts "     - #{model_name}"
  end
end
if services.any?
  puts "  3. Services"
  services.each do |service|
    puts "     - #{service}"
  end
end
if controllers.any?
  puts "  4. Controllers/API Endpoints"
  controllers.each do |controller|
    puts "     - #{controller}"
  end
end
if jobs.any?
  puts "  5. Background Jobs"
end
if components.any?
  puts "  6. Frontend Components"
  components.each do |component|
    puts "     - #{component}"
  end
end
if tests.any?
  puts "  7. Testing"
end

puts ""
puts "✅ Analysis complete!"
