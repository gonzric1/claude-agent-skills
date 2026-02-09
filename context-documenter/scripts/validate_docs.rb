#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'

##
# validate_docs.rb - Validates documentation for broken links and outdated references
#
# Usage: ruby validate_docs.rb <doc_file>
# Example: ruby validate_docs.rb .agent/context/etsy-integration.md

doc_file = ARGV[0]

if doc_file.nil? || doc_file.empty?
  puts "Usage: ruby validate_docs.rb <doc_file>"
  puts "Example: ruby validate_docs.rb .agent/context/etsy-integration.md"
  exit 1
end

unless File.exist?(doc_file)
  puts "❌ Error: File not found: #{doc_file}"
  exit 1
end

project_root = File.expand_path("../../../../", __dir__)
Dir.chdir(project_root)

puts "🔍 Validating documentation: #{doc_file}"
puts ""

content = File.read(doc_file)
errors = []
warnings = []

# Check 1: Find file path references (app/..., test/...)
file_refs = content.scan(%r{(?:app|test|lib|config)/[^\s\)]+\.(?:rb|js|jsx|tsx|ts|yml|yaml)})
puts "📄 Checking file references..."
file_refs.uniq.each do |file_ref|
  file_path = File.join(project_root, file_ref)
  unless File.exist?(file_path)
    errors << "Missing file: #{file_ref}"
  end
end

# Check 2: Find markdown links to other context docs
doc_links = content.scan(/\[([^\]]+)\]\(file:\/\/([^\)]+\.md)\)/)
puts "🔗 Checking documentation links..."
doc_links.each do |label, path|
  unless File.exist?(path)
    errors << "Broken link: [#{label}](#{path})"
  end
end

# Check 3: Look for common placeholder text
puts "🏷️  Checking for placeholders..."
placeholders = ['TODO', 'FIXME', 'XXX', 'PLACEHOLDER', '...']
placeholders.each do |placeholder|
  if content.include?(placeholder)
    warnings << "Found placeholder: #{placeholder}"
  end
end

# Check 4: Verify markdown structure
puts "📋 Checking markdown structure..."
lines = content.lines
h1_count = lines.count { |line| line.start_with?('# ') }
if h1_count == 0
  errors << "No H1 heading found"
elsif h1_count > 1
  warnings << "Multiple H1 headings found (#{h1_count})"
end

# Check 5: Look for common section headings
common_sections = ['Overview', 'Models', 'Services', 'Testing', 'API']
found_sections = common_sections.select do |section|
  content.match?(/^##+ #{section}/i)
end

if found_sections.empty?
  warnings << "Consider adding standard sections: #{common_sections.join(', ')}"
end

# Print results
puts ""
puts "=" * 60
puts "VALIDATION RESULTS"
puts "=" * 60
puts ""

if errors.any?
  puts "❌ Errors (#{errors.count}):"
  errors.each { |error| puts "  - #{error}" }
  puts ""
end

if warnings.any?
  puts "⚠️  Warnings (#{warnings.count}):"
  warnings.each { |warning| puts "  - #{warning}" }
  puts ""
end

if errors.empty? && warnings.empty?
  puts "✅ All checks passed!"
  puts ""
  puts "📊 Stats:"
  puts "  - Lines: #{lines.count}"
  puts "  - File references: #{file_refs.uniq.count}"
  puts "  - Doc links: #{doc_links.count}"
  puts "  - Sections found: #{found_sections.join(', ')}"
else
  puts ""
  puts "Summary: #{errors.count} error(s), #{warnings.count} warning(s)"
end

puts ""

# Exit with appropriate code
exit errors.any? ? 1 : 0
