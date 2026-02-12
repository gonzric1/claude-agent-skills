#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'open3'
require_relative 'audit_logger'

# Fix label conflicts automatically
#
# Enforces label whitelist and removes invalid/obsolete labels.

class LabelFixer
  # Allowed labels (managed by skills or valid category labels)
  WORKFLOW_LABELS = %w[
    ready-for-review
    review-passed
  ].freeze

  PRIORITY_LABELS = %w[
    critical
    major
    moderate
    ticket
    nit
  ].freeze

  CATEGORY_LABELS = %w[
    api
    backend
    component
    controller
    core-feature
    database
    documentation
    frontend
    integration
    migration
    model
    react
    refactoring
    service
    test
    testing
    typescript
    types
    workflow
  ].freeze

  # Complete whitelist
  ALLOWED_LABELS = (WORKFLOW_LABELS + PRIORITY_LABELS + CATEGORY_LABELS).freeze

  # Obsolete labels to always remove
  OBSOLETE_LABELS = %w[
    review-finding
    review-failed
    review-summary
    blocks-approval
    pre-existing
  ].freeze

  CONFLICT_RULES = {
    # No known conflict pairs currently
  }.freeze

  def initialize(dry_run: false)
    @dry_run = dry_run
    @issues = []
    @fixed = []
    @logger = AuditLogger.new('fix_labels') unless dry_run
  end

  def run
    puts "🔧 Label Conflict Fixer"
    puts "=" * 50
    puts "Mode: #{@dry_run ? 'DRY RUN' : 'LIVE'}"
    puts

    load_issues
    fix_conflicts
    remove_invalid_labels
    print_summary

    @logger&.finalize

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

        @logger&.log_fix(
          issue_id: issue['id'],
          issue_title: issue['title'],
          problem: "Label conflict: has both '#{keep}' and '#{remove}'",
          action: "Remove conflicting label '#{label_to_remove}'",
          details: {
            conflicting_labels: [keep, remove],
            label_to_remove: label_to_remove,
            all_labels: labels
          }
        )

        if @dry_run
          puts "   [DRY RUN - no changes made]"
        else
          success = remove_label(issue['id'], label_to_remove)
          @logger&.log_fix_result(
            issue_id: issue['id'],
            success: success,
            message: success ? "Removed label '#{label_to_remove}'" : "Failed to remove label"
          )
        end

        @fixed << issue['id']
      end
    end

    puts "\n✓ No conflicts found" if @fixed.empty?
  end

  def remove_invalid_labels
    puts "\nChecking for invalid/obsolete labels..."

    @issues.each do |issue|
      labels = issue['labels'] || []

      # Find invalid labels (not in whitelist)
      invalid = labels.reject { |label| ALLOWED_LABELS.include?(label) }

      # Add obsolete labels even if somehow in whitelist
      obsolete = labels & OBSOLETE_LABELS

      to_remove = (invalid + obsolete).uniq

      next if to_remove.empty?

      puts "\n⚠️  Found invalid labels in #{issue['id']}:"
      puts "   Title: #{issue['title']}"
      puts "   All labels: #{labels.join(', ')}"
      puts "   Invalid/obsolete: #{to_remove.join(', ')}"
      puts "   Action: Remove #{to_remove.size} label(s)"

      @logger&.log_fix(
        issue_id: issue['id'],
        issue_title: issue['title'],
        problem: "Invalid/obsolete labels found",
        action: "Remove #{to_remove.size} invalid label(s): #{to_remove.join(', ')}",
        details: {
          invalid_labels: to_remove,
          all_labels: labels,
          allowed_labels: ALLOWED_LABELS
        }
      )

      if @dry_run
        puts "   [DRY RUN - no changes made]"
      else
        successes = to_remove.map { |label| remove_label(issue['id'], label) }
        all_success = successes.all?
        @logger&.log_fix_result(
          issue_id: issue['id'],
          success: all_success,
          message: all_success ? "Removed #{to_remove.size} label(s)" : "Failed to remove some labels"
        )
      end

      @fixed << issue['id'] unless @fixed.include?(issue['id'])
    end

    puts "\n✓ No invalid labels found" if @fixed.empty?
  end

  def remove_label(issue_id, label)
    cmd = "bd label remove #{issue_id} #{label}"
    output, status = run_command(cmd)

    if status.success?
      puts "   ✓ Removed label '#{label}'"
      true
    else
      puts "   ❌ Failed to remove label: #{output}"
      false
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
