#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'open3'

# Fix label conflicts automatically
#
# Removes conflicting labels based on priority rules:
# - If both 'ready-for-review' and 'review-finding' exist, remove 'review-finding'

class LabelFixer
  CONFLICT_RULES = {
    # [keep_label, remove_label]
    ['ready-for-review', 'review-finding'] => 'review-finding'
  }.freeze

  def initialize(dry_run: false)
    @dry_run = dry_run
    @issues = []
    @fixed = []
  end

  def run
    puts "🔧 Label Conflict Fixer"
    puts "=" * 50
    puts "Mode: #{@dry_run ? 'DRY RUN' : 'LIVE'}"
    puts

    load_issues
    fix_conflicts
    print_summary

    exit(@fixed.any? ? 0 : 1)
  end

  private

  def load_issues
    print "Loading issues... "
    output, status = run_command('bd export')

    unless status.success?
      puts "❌ Failed to load issues"
      exit 2
    end

    # Parse JSONL (one JSON object per line)
    all_issues = output.lines.map { |line| JSON.parse(line.strip) }

    # Filter to open issues only
    @issues = all_issues.select { |i| i['status'] == 'open' }

    puts "✓ (#{@issues.size} open issues)"
  rescue JSON::ParserError => e
    puts "❌ Failed to parse bd export output: #{e.message}"
    exit 2
  end

  def fix_conflicts
    puts "\nChecking for conflicts..."

    @issues.each do |issue|
      labels = issue['labels'] || []

      CONFLICT_RULES.each do |(keep, remove), label_to_remove|
        next unless labels.include?(keep) && labels.include?(remove)

        puts "\n⚠️  Found conflict in #{issue['id']}:"
        puts "   Title: #{issue['title']}"
        puts "   Labels: #{labels.join(', ')}"
        puts "   Action: Remove '#{label_to_remove}'"

        if @dry_run
          puts "   [DRY RUN - no changes made]"
        else
          remove_label(issue['id'], label_to_remove)
        end

        @fixed << issue['id']
      end
    end

    puts "\n✓ No conflicts found" if @fixed.empty?
  end

  def remove_label(issue_id, label)
    cmd = "bd label remove #{issue_id} #{label}"
    output, status = run_command(cmd)

    if status.success?
      puts "   ✓ Removed label '#{label}'"
    else
      puts "   ❌ Failed to remove label: #{output}"
    end
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
      puts "✅ No conflicts to fix"
    end
  end
end

# Parse arguments
dry_run = ARGV.include?('--dry-run')

LabelFixer.new(dry_run: dry_run).run
