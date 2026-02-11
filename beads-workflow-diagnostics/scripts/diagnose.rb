#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'time'
require 'open3'
require 'yaml'

# Beads Workflow Diagnostic Tool
#
# Checks for workflow inconsistencies:
# 1. Label conflicts
# 2. Orphaned parent relationships
# 3. Stuck in_progress issues
# 4. Circular dependencies
# 5. Issues that should be ready but aren't visible

class BeadsWorkflowDiagnostic
  LABEL_CONFLICT_PAIRS = [
    # No known conflict pairs currently
  ].freeze

  STUCK_THRESHOLD_HOURS = 24

  def initialize
    @issues = []
    @problems = []
    @warnings = []
  end

  def run
    puts "🔍 Beads Workflow Diagnostics"
    puts "=" * 50
    puts

    load_all_issues
    check_label_conflicts
    check_orphaned_parents
    check_stuck_issues
    check_dependencies
    check_ready_queue_consistency

    print_summary
    exit(@problems.empty? ? 0 : 1)
  end

  private

  def load_all_issues
    print "Loading all issues... "
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

  def check_label_conflicts
    puts "\n1️⃣  Checking for label conflicts..."
    conflicts = []

    @issues.each do |issue|
      labels = issue['labels'] || []

      LABEL_CONFLICT_PAIRS.each do |pair|
        if labels.include?(pair[0]) && labels.include?(pair[1])
          conflicts << {
            id: issue['id'],
            title: issue['title'],
            labels: labels,
            conflict: pair
          }
        end
      end
    end

    if conflicts.any?
      @problems << "Label conflicts found (#{conflicts.size})"
      conflicts.each do |conflict|
        puts "   ❌ #{conflict[:id]}: Has both #{conflict[:conflict].join(' AND ')}"
        puts "      Title: #{conflict[:title]}"
        puts "      Labels: #{conflict[:labels].join(', ')}"
      end
    else
      puts "   ✓ No label conflicts"
    end
  end

  def check_orphaned_parents
    puts "\n2️⃣  Checking for orphaned parent relationships..."
    orphaned = []

    # Get all issues (we already have them from bd export)
    all_output, = run_command('bd export')
    all_issues = all_output.lines.map { |line| JSON.parse(line.strip) }
    all_issue_ids = all_issues.map { |i| i['id'] }

    @issues.each do |issue|
      next unless issue['issue_type'] == 'review'

      metadata = issue['metadata'] || {}
      parent_id = metadata['parent_issue_id']

      next unless parent_id

      # Check if parent exists and is open
      parent = @issues.find { |i| i['id'] == parent_id }

      if parent.nil?
        # Parent doesn't exist in open issues - check if it's closed/deleted
        if all_issue_ids.include?(parent_id)
          orphaned << {
            id: issue['id'],
            title: issue['title'],
            parent_id: parent_id,
            reason: 'parent closed'
          }
        else
          orphaned << {
            id: issue['id'],
            title: issue['title'],
            parent_id: parent_id,
            reason: 'parent deleted'
          }
        end
      end
    end

    if orphaned.any?
      @problems << "Orphaned parent relationships (#{orphaned.size})"
      orphaned.each do |item|
        puts "   ❌ #{item[:id]}: Parent #{item[:parent_id]} is #{item[:reason]}"
        puts "      Title: #{item[:title]}"
      end
    else
      puts "   ✓ No orphaned parent relationships"
    end
  end

  def check_stuck_issues
    puts "\n3️⃣  Checking for stuck in_progress issues..."
    stuck = []
    now = Time.now

    @issues.each do |issue|
      next unless issue['status'] == 'in_progress'

      updated_at = parse_time(issue['updated_at'])
      next unless updated_at

      hours_stuck = ((now - updated_at) / 3600).round(1)

      if hours_stuck > STUCK_THRESHOLD_HOURS
        stuck << {
          id: issue['id'],
          title: issue['title'],
          hours: hours_stuck,
          assignee: issue['assignee'] || 'unassigned'
        }
      end
    end

    if stuck.any?
      @warnings << "Stuck issues found (#{stuck.size})"
      stuck.each do |item|
        puts "   ⚠️  #{item[:id]}: In progress for #{item[:hours]}h"
        puts "      Title: #{item[:title]}"
        puts "      Assignee: #{item[:assignee]}"
      end
    else
      puts "   ✓ No stuck issues"
    end
  end

  def check_dependencies
    puts "\n4️⃣  Checking dependency graph..."

    # Build dependency graph from dependencies array
    graph = {}
    @issues.each do |issue|
      deps = issue['dependencies'] || []
      blocked_by = deps.select { |d| d['issue_id'] == issue['id'] }.map { |d| d['depends_on_id'] }
      graph[issue['id']] = blocked_by
    end

    # Check for circular dependencies
    circular = find_circular_dependencies(graph)

    if circular.any?
      @problems << "Circular dependencies found (#{circular.size})"
      circular.each do |cycle|
        puts "   ❌ Circular dependency: #{cycle.join(' -> ')}"
      end
    else
      puts "   ✓ No circular dependencies"
    end

    # Check for invalid blockers (references to non-existent issues)
    invalid = []
    @issues.each do |issue|
      deps = issue['dependencies'] || []
      blocked_by = deps.select { |d| d['issue_id'] == issue['id'] }.map { |d| d['depends_on_id'] }

      blocked_by.each do |blocker_id|
        unless @issues.any? { |i| i['id'] == blocker_id }
          invalid << {
            id: issue['id'],
            title: issue['title'],
            invalid_blocker: blocker_id
          }
        end
      end
    end

    if invalid.any?
      @problems << "Invalid dependency references (#{invalid.size})"
      invalid.each do |item|
        puts "   ❌ #{item[:id]}: References non-existent blocker #{item[:invalid_blocker]}"
        puts "      Title: #{item[:title]}"
      end
    else
      puts "   ✓ No invalid dependency references"
    end
  end

  def check_ready_queue_consistency
    puts "\n5️⃣  Checking bd ready queue consistency..."

    # Parse bd ready output (it's plain text, not JSON)
    ready_output, = run_command('bd ready')
    ready_ids = ready_output.lines.map do |line|
      # Extract issue ID from lines like:
      # "○ PrintMines-57m [● P2] ..." (list format)
      # "1. [● P2] [task] PrintMines-ha4: ..." (numbered format)
      match = line.match(/^\s*(?:[○●]|\d+\.)\s+(?:\[[^\]]+\]\s+)*([\w-]+):/)
      match ? match[1] : nil
    end.compact

    # Calculate which issues SHOULD be ready
    # Extract blockers from dependencies array
    should_be_ready = @issues.select do |issue|
      status_ok = issue['status'] == 'open'

      # Extract blocked_by from dependencies
      deps = issue['dependencies'] || []
      blocked_by_deps = deps.select { |d| d['issue_id'] == issue['id'] }.map { |d| d['depends_on_id'] }
      no_blockers = blocked_by_deps.empty?

      no_assignee = issue['assignee'].nil? || issue['assignee'].empty?
      labels = issue['labels'] || []
      not_ready_for_review = !labels.include?('ready-for-review')

      status_ok && no_blockers && no_assignee && not_ready_for_review
    end

    # Find discrepancies
    should_be_ready_ids = should_be_ready.map { |i| i['id'] }.sort

    missing_from_ready = should_be_ready_ids - ready_ids
    extra_in_ready = ready_ids - should_be_ready_ids

    if missing_from_ready.any? || extra_in_ready.any?
      @problems << "Ready queue inconsistency"

      if missing_from_ready.any?
        puts "   ❌ Issues that SHOULD be in ready but aren't (#{missing_from_ready.size}):"
        missing_from_ready.each do |id|
          issue = @issues.find { |i| i['id'] == id }
          deps = issue['dependencies'] || []
          blocked_by = deps.select { |d| d['issue_id'] == id }.map { |d| d['depends_on_id'] }

          puts "      - #{id}: #{issue['title']}"
          puts "        Status: #{issue['status']}, Assignee: #{issue['assignee'] || 'none'}"
          puts "        Blockers: #{blocked_by.any? ? blocked_by.join(', ') : 'none'}"
          puts "        Labels: #{(issue['labels'] || []).join(', ')}"
        end
      end

      if extra_in_ready.any?
        puts "   ❌ Issues in ready that shouldn't be (#{extra_in_ready.size}):"
        extra_in_ready.each do |id|
          issue = @issues.find { |i| i['id'] == id }
          next unless issue

          deps = issue['dependencies'] || []
          blocked_by = deps.select { |d| d['issue_id'] == id }.map { |d| d['depends_on_id'] }

          puts "      - #{id}: #{issue['title']}"
          puts "        Status: #{issue['status']}, Assignee: #{issue['assignee'] || 'none'}"
          puts "        Blockers: #{blocked_by.any? ? blocked_by.join(', ') : 'none'}"
          puts "        Labels: #{(issue['labels'] || []).join(', ')}"
        end
      end
    else
      puts "   ✓ Ready queue is consistent (#{ready_ids.size} issues)"
    end
  end

  def find_circular_dependencies(graph)
    cycles = []
    visited = {}
    rec_stack = {}

    graph.keys.each do |node|
      next if visited[node]
      find_cycle(node, graph, visited, rec_stack, [], cycles)
    end

    cycles
  end

  def find_cycle(node, graph, visited, rec_stack, path, cycles)
    visited[node] = true
    rec_stack[node] = true
    path << node

    (graph[node] || []).each do |neighbor|
      if !visited[neighbor]
        find_cycle(neighbor, graph, visited, rec_stack, path.dup, cycles)
      elsif rec_stack[neighbor]
        cycle_start = path.index(neighbor)
        cycles << path[cycle_start..-1] + [neighbor] if cycle_start
      end
    end

    rec_stack[node] = false
  end

  def parse_time(time_str)
    Time.parse(time_str)
  rescue ArgumentError, TypeError
    nil
  end

  def run_command(cmd)
    output, status = Open3.capture2(cmd)
    [output, status]
  end

  def print_summary
    puts "\n" + "=" * 50
    puts "📊 Summary"
    puts "=" * 50

    if @problems.empty? && @warnings.empty?
      puts "✅ No issues detected - workflow is healthy"
    else
      if @problems.any?
        puts "\n❌ Problems (#{@problems.size}):"
        @problems.each { |p| puts "   - #{p}" }
      end

      if @warnings.any?
        puts "\n⚠️  Warnings (#{@warnings.size}):"
        @warnings.each { |w| puts "   - #{w}" }
      end

      puts "\n💡 Suggested actions:"
      puts "   1. Run fix scripts: ruby scripts/fix_labels.rb"
      puts "   2. Run fix scripts: ruby scripts/fix_parents.rb"
      puts "   3. Manually review stuck/blocked issues"
      puts "   4. Run 'bd sync' to ensure remote is up to date"
    end
  end
end

# Run diagnostic
BeadsWorkflowDiagnostic.new.run
