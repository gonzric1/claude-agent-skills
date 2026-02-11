#!/usr/bin/env ruby
# frozen_string_literal: true

# Split oversized documentation files into focused sub-documents
#
# This script:
# 1. Finds context files longer than 250 lines
# 2. Analyzes their structure to identify logical sections
# 3. Splits them into focused sub-documents (e.g., "Orders - Models", "Orders - API Endpoints")
# 4. Creates an index file that references all split files
#
# Usage:
#   ruby .claude/skills/context-documenter/scripts/split_oversized_docs.rb [--dry-run] [--threshold=250]
#
# Options:
#   --dry-run      Show what would be split without making changes
#   --threshold=N  Set line count threshold (default: 250)

require 'fileutils'

# Configuration
CONTEXT_DIR = '.agent/context'
DEFAULT_THRESHOLD = 250
DRY_RUN = ARGV.include?('--dry-run')
THRESHOLD = ARGV.find { |arg| arg.start_with?('--threshold=') }&.split('=')&.last&.to_i || DEFAULT_THRESHOLD

# Heading patterns for identifying sections
HEADING_REGEX = /^##\s+(.+)$/
SUBHEADING_REGEX = /^###\s+(.+)$/

class DocumentSplitter
  attr_reader :file_path, :content, :line_count

  def initialize(file_path)
    @file_path = file_path
    @content = File.read(file_path)
    @line_count = @content.lines.count
  end

  def oversized?
    @line_count > THRESHOLD
  end

  def split!
    puts "\n📄 Processing: #{file_path} (#{line_count} lines)"

    sections = extract_sections
    if sections.empty?
      puts "  ⚠️  No clear sections found - skipping split"
      return
    end

    puts "  📑 Found #{sections.size} sections"

    base_name = File.basename(file_path, '.md')
    dir_name = File.dirname(file_path)
    split_dir = File.join(dir_name, base_name)

    unless DRY_RUN
      FileUtils.mkdir_p(split_dir)
    end

    # Create split files
    sections.each do |section|
      split_file_path = File.join(split_dir, sanitize_filename(section[:title]) + '.md')

      if DRY_RUN
        puts "  📝 Would create: #{split_file_path} (#{section[:content].lines.count} lines)"
      else
        File.write(split_file_path, section[:content])
        puts "  ✅ Created: #{split_file_path} (#{section[:content].lines.count} lines)"
      end
    end

    # Create index file
    index_content = generate_index(base_name, sections)
    index_path = File.join(split_dir, 'README.md')

    if DRY_RUN
      puts "  📝 Would create index: #{index_path}"
      puts "\n--- Index Preview ---\n#{index_content.lines.first(20).join}..."
    else
      File.write(index_path, index_content)
      puts "  ✅ Created index: #{index_path}"
    end

    # Rename original file to .old
    old_path = "#{file_path}.old"
    if DRY_RUN
      puts "  📝 Would rename original: #{file_path} -> #{old_path}"
    else
      FileUtils.mv(file_path, old_path)
      puts "  📦 Archived original: #{old_path}"
    end

    puts "  ✨ Split complete!"
  end

  private

  def extract_sections
    sections = []
    current_section = nil
    lines = @content.lines

    # Extract title from first line if it's an H1
    title_match = lines.first&.match(/^#\s+(.+)$/)
    doc_title = title_match ? title_match[1] : File.basename(@file_path, '.md').split('_').map(&:capitalize).join(' ')

    lines.each_with_index do |line, idx|
      # Match H2 headings (## Section Title)
      if (match = line.match(HEADING_REGEX))
        # Save previous section
        sections << current_section if current_section

        # Start new section
        current_section = {
          title: match[1].strip,
          content: "# #{doc_title} - #{match[1].strip}\n\n",
          start_line: idx
        }
      elsif current_section
        # Add line to current section
        current_section[:content] << line
      end
    end

    # Add final section
    sections << current_section if current_section

    # Filter out very small sections (< 20 lines)
    sections.select { |s| s[:content].lines.count >= 20 }
  end

  def generate_index(base_name, sections)
    title = base_name.split(/[-_]/).map(&:capitalize).join(' ')

    content = <<~INDEX
      # #{title}

      This documentation has been split into focused sub-documents for better readability.

      ## Overview

      #{extract_overview}

      ## Documentation Structure

      This feature documentation is organized into the following sections:

    INDEX

    sections.each do |section|
      filename = sanitize_filename(section[:title])
      line_count = section[:content].lines.count
      content << "- **[#{section[:title]}](./#{filename}.md)** - #{extract_section_summary(section)} (#{line_count} lines)\n"
    end

    content << <<~FOOTER

      ## Navigation

      Each sub-document focuses on a specific aspect of the feature. Start with the section most relevant to your task:

      - **Models** - Database schema, validations, and associations
      - **Services** - Business logic and external integrations
      - **Controllers/API** - HTTP endpoints and request handling
      - **Frontend** - React components and user interface
      - **Testing** - Test files and coverage notes
      - **Deployment** - Production considerations and common issues

      ## Contributing

      When updating this documentation:
      1. Update the relevant sub-document (not this index)
      2. Keep each section focused and under 250 lines
      3. Cross-reference related sections using relative links
      4. Run validation: `ruby .claude/skills/context-documenter/scripts/validate_docs.rb`
    FOOTER

    content
  end

  def extract_overview
    # Extract content before first H2 heading
    lines = @content.lines
    overview_lines = []

    lines.each do |line|
      break if line.match?(HEADING_REGEX)
      overview_lines << line unless line.match?(/^#\s+.+$/)
    end

    overview = overview_lines.join.strip
    overview.empty? ? "Feature documentation for #{File.basename(@file_path, '.md')}." : overview
  end

  def extract_section_summary(section)
    # Try to extract first paragraph as summary
    lines = section[:content].lines.drop(2) # Skip title
    summary_lines = []

    lines.each do |line|
      break if line.strip.empty? && !summary_lines.empty?
      break if line.match?(HEADING_REGEX) || line.match?(SUBHEADING_REGEX)
      summary_lines << line.strip unless line.strip.empty?
    end

    summary = summary_lines.join(' ').gsub(/\s+/, ' ')
    summary.length > 100 ? "#{summary[0..100]}..." : summary
  end

  def sanitize_filename(title)
    title
      .downcase
      .gsub(/[^a-z0-9\s-]/, '')
      .gsub(/\s+/, '-')
      .gsub(/-+/, '-')
      .strip
  end
end

# Main execution
def main
  puts "🔍 Scanning #{CONTEXT_DIR} for oversized documentation files (threshold: #{THRESHOLD} lines)"
  puts "   Mode: #{DRY_RUN ? 'DRY RUN (no changes will be made)' : 'LIVE'}"
  puts ""

  files = Dir.glob(File.join(CONTEXT_DIR, '**', '*.md'))
  oversized_files = []

  files.each do |file|
    line_count = File.read(file).lines.count
    if line_count > THRESHOLD
      oversized_files << [file, line_count]
    end
  end

  if oversized_files.empty?
    puts "✅ No oversized files found! All documentation is under #{THRESHOLD} lines."
    exit 0
  end

  puts "📊 Found #{oversized_files.size} oversized files:\n\n"
  oversized_files.sort_by { |_, count| -count }.each do |file, count|
    puts "  #{count.to_s.rjust(4)} lines - #{file}"
  end

  puts "\n" + ("=" * 80) + "\n"

  oversized_files.each do |file_path, _|
    splitter = DocumentSplitter.new(file_path)
    splitter.split!
  end

  puts "\n" + ("=" * 80)
  puts "\n✨ Complete! Processed #{oversized_files.size} files."

  if DRY_RUN
    puts "\n⚠️  This was a DRY RUN. No changes were made."
    puts "   Run without --dry-run to apply changes."
  else
    puts "\n📁 Original files have been renamed to *.md.old"
    puts "   Review the split files and delete .old files when satisfied."
  end
end

main
