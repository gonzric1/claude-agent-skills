#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'open3'

# Auto-fix workflow inconsistencies
#
# Runs diagnostic and applies fixes if issues found.
# Designed to be called automatically when agents can't find work.
#
# Exit codes:
#   0 - Fixes were applied (workflow was broken, now fixed)
#   1 - No issues found (workflow is healthy)
#   2 - Error running commands

class WorkflowAutoFix
  def initialize(verbose: false)
    @verbose = verbose
    @fixes_applied = false
  end

  def run
    log "🔍 Checking workflow health..."

    # Check if there's an inconsistency worth investigating
    unless inconsistency_detected?
      log "✓ No inconsistency detected"
      exit 1
    end

    log "⚠️  Inconsistency detected: bd ready has issues but workflow appears stuck"
    log ""

    # Run diagnostic to identify specific problems
    problems = run_diagnostic

    if problems.empty?
      log "✓ No fixable issues found"
      exit 1
    end

    log "Found #{problems.size} problem(s), applying fixes..."
    log ""

    # Apply fixes
    apply_fixes(problems)

    if @fixes_applied
      log ""
      log "✅ Fixes applied successfully"
      log "💡 Run 'bd sync' to push changes to remote"
      exit 0
    else
      log "⚠️  No fixes could be applied"
      exit 1
    end
  end

  private

  def inconsistency_detected?
    # Check if bd ready has issues
    ready_output, status = run_command('bd ready')
    return false unless status.success?

    ready_count = ready_output.lines.count { |line| line.match?(/^\d+\./) }

    if ready_count > 0
      log "bd ready shows #{ready_count} issue(s)"
      true
    else
      false
    end
  end

  def run_diagnostic
    log "Running diagnostic..."

    output, status = run_command("ruby #{script_dir}/diagnose.rb")

    unless status.success?
      # Diagnostic found problems (exit code 1)
      problems = parse_diagnostic_output(output)
      log "Diagnostic found #{problems.size} problem(s)"
      return problems
    end

    [] # No problems
  end

  def parse_diagnostic_output(output)
    problems = []

    # Look for specific problem markers in output
    if output.include?('Invalid dependency references')
      problems << :invalid_dependencies
    end

    if output.include?('Label conflicts found')
      problems << :label_conflicts
    end

    if output.include?('Orphaned parent relationships')
      problems << :orphaned_parents
    end

    problems
  end

  def apply_fixes(problems)
    if problems.include?(:invalid_dependencies)
      log "Fixing invalid dependencies..."
      output, status = run_command("ruby #{script_dir}/fix_dependencies.rb")

      if status.success?
        log "✓ Fixed invalid dependencies"
        @fixes_applied = true
      else
        log "✗ Failed to fix dependencies: #{output}"
      end
    end

    if problems.include?(:label_conflicts)
      log "Fixing label conflicts..."
      output, status = run_command("ruby #{script_dir}/fix_labels.rb")

      if status.success?
        log "✓ Fixed label conflicts"
        @fixes_applied = true
      else
        log "✗ Failed to fix labels: #{output}"
      end
    end

    if problems.include?(:orphaned_parents)
      log "Fixing orphaned parents..."
      output, status = run_command("ruby #{script_dir}/fix_parents.rb")

      if status.success?
        log "✓ Fixed orphaned parents"
        @fixes_applied = true
      else
        log "✗ Failed to fix parents: #{output}"
      end
    end
  end

  def script_dir
    File.dirname(__FILE__)
  end

  def run_command(cmd)
    output, status = Open3.capture2e(cmd)
    [output, status]
  end

  def log(message)
    puts message if @verbose
  end
end

# Parse arguments
verbose = ARGV.include?('--verbose') || ARGV.include?('-v')

WorkflowAutoFix.new(verbose: verbose).run
