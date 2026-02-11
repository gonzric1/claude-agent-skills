#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'open3'
require 'yaml'

# Fix orphaned parent relationships
#
# Removes parent_issue_id metadata from review issues when the parent is closed/deleted

class ParentFixer
  def initialize(dry_run: false)
    @dry_run = dry_run
    @issues = []
    @all_issues = []
    @fixed = []
  end

  def run
    puts "🔧 Orphaned Parent Fixer"
    puts "=" * 50
    puts "Mode: #{@dry_run ? 'DRY RUN' : 'LIVE'}"
    puts

    load_issues
    fix_orphaned_parents
    print_summary

    exit(@fixed.any? ? 0 : 1)
  end

  private

  def load_issues
    print "Loading all issues... "
    output, status = run_command('bd export')

    unless status.success?
      puts "❌ Failed to load issues"
      exit 2
    end

    # Parse JSONL (one JSON object per line)
    @all_issues = output.lines.map { |line| JSON.parse(line.strip) }

    # Filter to open issues
    @issues = @all_issues.select { |i| i['status'] == 'open' }

    puts "✓ (#{@issues.size} open issues, #{@all_issues.size} total)"
  rescue JSON::ParserError => e
    puts "❌ Failed to parse bd export output: #{e.message}"
    exit 2
  end

  def fix_orphaned_parents
    puts "\nChecking for orphaned parents..."
    all_issue_ids = @all_issues.map { |i| i['id'] }

    @issues.each do |issue|
      next unless issue['issue_type'] == 'review'

      metadata = issue['metadata'] || {}
      parent_id = metadata['parent_issue_id']
      next unless parent_id

      # Check if parent exists and is open
      parent = @issues.find { |i| i['id'] == parent_id }

      if parent.nil?
        reason = if all_issue_ids.include?(parent_id)
          'closed'
        else
          'deleted'
        end

        puts "\n⚠️  Found orphaned parent in #{issue['id']}:"
        puts "   Title: #{issue['title']}"
        puts "   Parent: #{parent_id} (#{reason})"
        puts "   Action: Remove parent_issue_id metadata"

        if @dry_run
          puts "   [DRY RUN - no changes made]"
        else
          remove_parent_metadata(issue['id'])
        end

        @fixed << issue['id']
      end
    end

    puts "\n✓ No orphaned parents found" if @fixed.empty?
  end

  def remove_parent_metadata(issue_id)
    # Read the issue YAML file directly
    issue_file = ".beads/issues/#{issue_id}.yaml"

    unless File.exist?(issue_file)
      puts "   ❌ Issue file not found: #{issue_file}"
      return
    end

    issue_data = YAML.load_file(issue_file)

    if issue_data['metadata'] && issue_data['metadata']['parent_issue_id']
      issue_data['metadata'].delete('parent_issue_id')

      # Write back
      File.write(issue_file, YAML.dump(issue_data))
      puts "   ✓ Removed parent_issue_id metadata"

      # Commit the change
      run_command("git add #{issue_file}")
      run_command("git commit -m 'fix: remove orphaned parent_issue_id from #{issue_id}'")
    else
      puts "   ⚠️  No parent_issue_id found in metadata"
    end
  rescue => e
    puts "   ❌ Failed to fix: #{e.message}"
  end

  def run_command(cmd)
    output, status = Open3.capture2(cmd)
    [output, status]
  end

  def print_summary
    puts "\n" + "=" * 50
    puts "📊 Summary"
    puts "=" * 50

    if @fixed.any?
      puts "✅ Fixed #{@fixed.size} issues:"
      @fixed.each { |id| puts "   - #{id}" }

      unless @dry_run
        puts "\n💡 Run 'bd sync' to push changes to remote"
      end
    else
      puts "✅ No orphaned parents to fix"
    end
  end
end

# Parse arguments
dry_run = ARGV.include?('--dry-run')

ParentFixer.new(dry_run: dry_run).run
