#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'open3'
require_relative 'audit_logger'

# Fix invalid dependency references
#
# Removes dependencies that point to closed or deleted issues

class DependencyFixer
  def initialize(dry_run: false)
    @dry_run = dry_run
    @issues = []
    @all_issues = []
    @fixed = []
    @logger = AuditLogger.new('fix_dependencies') unless dry_run
  end

  def run
    puts "🔧 Dependency Reference Fixer"
    puts "=" * 50
    puts "Mode: #{@dry_run ? 'DRY RUN' : 'LIVE'}"
    puts

    load_issues
    fix_invalid_dependencies
    print_summary

    @logger&.finalize

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

    # Filter to open and in_progress issues (both can have dependencies)
    @issues = @all_issues.select { |i| i['status'] == 'open' || i['status'] == 'in_progress' }

    puts "✓ (#{@issues.size} open/in_progress issues, #{@all_issues.size} total)"
  rescue JSON::ParserError => e
    puts "❌ Failed to parse bd export output: #{e.message}"
    exit 2
  end

  def fix_invalid_dependencies
    puts "\nChecking for invalid dependency references..."

    @issues.each do |issue|
      deps = issue['dependencies'] || []
      blocked_by = deps.select { |d| d['issue_id'] == issue['id'] }.map { |d| d['depends_on_id'] }

      invalid_blockers = blocked_by.reject do |blocker_id|
        blocker = @all_issues.find { |i| i['id'] == blocker_id }
        blocker && (blocker['status'] == 'open' || blocker['status'] == 'in_progress')
      end

      next if invalid_blockers.empty?

      puts "\n⚠️  Found invalid blockers in #{issue['id']}:"
      puts "   Title: #{issue['title']}"
      puts "   Invalid blockers: #{invalid_blockers.join(', ')}"

      blocker_details = invalid_blockers.map do |blocker_id|
        blocker = @all_issues.find { |i| i['id'] == blocker_id }
        status = blocker ? "closed (#{blocker['status']})" : 'deleted'
        puts "      - #{blocker_id}: #{status}"
        { blocker_id: blocker_id, status: status }
      end

      puts "   Action: Remove dependencies"

      # Log the fix
      @logger&.log_fix(
        issue_id: issue['id'],
        issue_title: issue['title'],
        problem: "Invalid dependency references to closed/deleted issues",
        action: "Remove #{invalid_blockers.size} invalid blocker(s): #{invalid_blockers.join(', ')}",
        details: {
          invalid_blockers: blocker_details,
          blocker_count: invalid_blockers.size
        }
      )

      if @dry_run
        puts "   [DRY RUN - no changes made]"
      else
        success = remove_dependencies(issue['id'], invalid_blockers)
        @logger&.log_fix_result(
          issue_id: issue['id'],
          success: success,
          message: success ? "Successfully removed #{invalid_blockers.size} dependency(ies)" : "Failed to remove some dependencies"
        )
      end

      @fixed << issue['id']
    end

    puts "\n✓ No invalid dependencies found" if @fixed.empty?
  end

  def remove_dependencies(issue_id, blocker_ids)
    all_success = true
    blocker_ids.each do |blocker_id|
      cmd = "bd dep remove #{issue_id} #{blocker_id}"
      output, status = run_command(cmd)

      if status.success?
        puts "   ✓ Removed dependency on #{blocker_id}"
      else
        puts "   ❌ Failed to remove dependency: #{output}"
        all_success = false
      end
    end
    all_success
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
      puts "✅ No invalid dependencies to fix"
    end
  end
end

# Parse arguments
dry_run = ARGV.include?('--dry-run')

DependencyFixer.new(dry_run: dry_run).run
