#!/usr/bin/env ruby
# frozen_string_literal: true

##
# create_doc.rb - Interactive documentation creator
#
# Usage: ruby create_doc.rb

require 'fileutils'

project_root = File.expand_path("../../../../", __dir__)
skill_dir = File.expand_path("..", __dir__)
context_dir = File.join(project_root, ".agent/context")

puts "📝 Context Documentation Creator"
puts "=" * 60
puts ""

# Get feature name
print "Feature/component name: "
feature_name = gets.chomp

if feature_name.empty?
  puts "❌ Feature name is required"
  exit 1
end

# Analyze the feature
puts ""
puts "🔍 Analyzing '#{feature_name}'..."
system("ruby #{skill_dir}/scripts/analyze_feature.rb #{feature_name}")

puts ""
puts "=" * 60
puts "Choose a template:"
puts "  1. Feature Integration (third-party APIs)"
puts "  2. Component Architecture (major components)"
puts "  3. Frontend Pattern (React patterns)"
puts "  4. Technical Guide (how-tos, debugging)"
puts ""
print "Template (1-4): "
template_choice = gets.chomp.to_i

template_file = case template_choice
when 1
  "feature-integration.md"
when 2
  "component-architecture.md"
when 3
  "frontend-pattern.md"
when 4
  "technical-guide.md"
else
  puts "❌ Invalid choice"
  exit 1
end

template_path = File.join(skill_dir, "assets", template_file)
unless File.exist?(template_path)
  puts "❌ Template not found: #{template_path}"
  exit 1
end

# Generate filename
doc_filename = "#{feature_name.gsub('_', '-')}.md"
doc_path = File.join(context_dir, doc_filename)

if File.exist?(doc_path)
  print "⚠️  File #{doc_filename} already exists. Overwrite? (y/N): "
  response = gets.chomp.downcase
  unless response == 'y' || response == 'yes'
    puts "Cancelled."
    exit 0
  end
end

# Copy template and replace placeholders
content = File.read(template_path)
feature_title = feature_name.split(/[_-]/).map(&:capitalize).join(' ')
content.gsub!('{{FEATURE_NAME}}', feature_title)
content.gsub!('{{COMPONENT_NAME}}', feature_title)
content.gsub!('{{PATTERN_NAME}}', feature_title)
content.gsub!('{{TOPIC_NAME}}', feature_title)

File.write(doc_path, content)

puts ""
puts "✅ Created: #{doc_path}"
puts ""
puts "Next steps:"
puts "  1. Edit #{doc_filename} and fill in the sections"
puts "  2. Validate with: ruby #{skill_dir}/scripts/validate_docs.rb #{doc_path}"
puts "  3. Commit the documentation"
puts ""
