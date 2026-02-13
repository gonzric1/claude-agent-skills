#!/usr/bin/env ruby
# frozen_string_literal: true

# Workflow Retrospective - Pipeline Analyzer
#
# Analyzes the entire development pipeline to identify bottlenecks,
# inefficiencies, and optimization opportunities.
#
# Usage:
#   ruby analyze_pipeline.rb [options]
#
# Options:
#   --phase PHASE     Analyze specific phase (planning, implementation, review)
#   --since DATE      Only analyze issues since DATE (YYYY-MM-DD)
#   --last N          Only analyze last N days
#   --export FILE     Export metrics to JSON file
#   --compare FILE    Compare current metrics with previous export
#   --verbose         Show detailed output
#   --help            Show this help

require 'json'
require 'open3'
require 'optparse'
require 'date'
require 'time'

# Helper to run bd commands
def run_bd(args, allow_failure: false)
  cmd = "bd #{args}"
  stdout, stderr, status = Open3.capture3(cmd)

  unless status.success? || allow_failure
    if stderr.include?("No beads repository found")
      puts "Error: beads not initialized in this project."
      puts "Run 'bd init' to initialize beads tracking."
      exit 1
    end
    $stderr.puts "Error running '#{cmd}': #{stderr}" unless allow_failure
    return nil if allow_failure
    exit 1
  end

  stdout
end

# Parse command line arguments
options = {
  phase: nil,
  since: nil,
  last_days: nil,
  export_file: nil,
  compare_file: nil,
  verbose: false
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

  opts.on("--phase PHASE", "Analyze specific phase (planning, implementation, review)") do |v|
    options[:phase] = v
  end

  opts.on("--since DATE", "Only analyze issues since DATE (YYYY-MM-DD)") do |v|
    options[:since] = Date.parse(v)
  end

  opts.on("--last N", Integer, "Only analyze last N days") do |v|
    options[:last_days] = v
    options[:since] = Date.today - v
  end

  opts.on("--export FILE", "Export metrics to JSON file") do |v|
    options[:export_file] = v
  end

  opts.on("--compare FILE", "Compare current metrics with previous export") do |v|
    options[:compare_file] = v
  end

  opts.on("-v", "--verbose", "Show detailed output") do
    options[:verbose] = true
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end

parser.parse!

# Load all issues
all_issues_json = run_bd("list --status all --json")
all_issues = JSON.parse(all_issues_json)

# Filter by date if specified
if options[:since]
  all_issues.select! do |issue|
    created_at = issue['created_at'] ? Date.parse(issue['created_at']) : nil
    created_at && created_at >= options[:since]
  end
end

# Separate by status
open_issues = all_issues.select { |i| i['status'] == 'open' || i['status'] == 'in_progress' }
closed_issues = all_issues.select { |i| i['status'] == 'closed' }

puts "=" * 80
puts "WORKFLOW RETROSPECTIVE ANALYSIS"
puts "=" * 80
puts ""
puts "Period: #{options[:since] ? "Since #{options[:since]}" : "All time"}"
puts "Total issues: #{all_issues.count} (#{open_issues.count} open, #{closed_issues.count} closed)"
puts ""

# PLANNING PHASE ANALYSIS
def analyze_planning(issues, options)
  puts "=" * 80
  puts "PLANNING PHASE ANALYSIS"
  puts "=" * 80
  puts ""

  # Ticket creation rate
  issues_by_week = issues.group_by do |issue|
    created = issue['created_at'] ? Date.parse(issue['created_at']) : nil
    created ? created.strftime("%Y-W%U") : "Unknown"
  end

  avg_per_week = issues_by_week.values.map(&:count).sum.to_f / [issues_by_week.count, 1].max

  # Priority distribution
  by_priority = issues.group_by { |i| i['priority'] }
  total = issues.count.to_f

  p0_count = by_priority[0]&.count || 0
  p1_count = by_priority[1]&.count || 0
  p2_count = by_priority[2]&.count || 0
  p3_count = by_priority[3]&.count || 0
  p4_count = by_priority[4]&.count || 0

  p0_pct = (p0_count / total * 100).round(1)
  p1_pct = (p1_count / total * 100).round(1)
  p2_pct = (p2_count / total * 100).round(1)
  p3_pct = (p3_count / total * 100).round(1)
  p4_pct = (p4_count / total * 100).round(1)

  high_priority_pct = ((p0_count + p1_count + p2_count) / total * 100).round(1)

  # Dependency depth (max chain length)
  max_depth = 0
  issues.each do |issue|
    depth = calculate_dependency_depth(issue, issues)
    max_depth = [max_depth, depth].max
  end

  # Planning lag (time from create to first status change)
  lags = issues.select { |i| i['status'] != 'open' && i['created_at'] && i['updated_at'] }.map do |issue|
    created = Time.parse(issue['created_at'])
    updated = Time.parse(issue['updated_at'])
    (updated - created) / 86400.0 # Convert to days
  end

  avg_lag = lags.empty? ? 0 : (lags.sum / lags.count).round(2)

  # Orphaned tickets (created but never started)
  orphaned = issues.select { |i| i['status'] == 'open' && never_started?(i) }
  orphan_rate = (orphaned.count.to_f / total * 100).round(1)

  puts "Ticket Creation Rate: #{avg_per_week.round(1)} tickets/week"
  puts ""
  puts "Priority Distribution:"
  puts "  P0 (Critical):  #{p0_count} (#{p0_pct}%)"
  puts "  P1 (Major):     #{p1_count} (#{p1_pct}%)"
  puts "  P2 (Moderate):  #{p2_count} (#{p2_pct}%)"
  puts "  P3 (Standard):  #{p3_count} (#{p3_pct}%)"
  puts "  P4 (Nit):       #{p4_count} (#{p4_pct}%)"
  puts ""
  puts "High-Priority Ratio (P0-P2): #{high_priority_pct}% #{high_priority_pct > 50 ? '⚠️ HIGH' : '✅ OK'}"
  puts "Target: 30-50%"
  puts ""
  puts "Dependency Depth: #{max_depth} levels #{max_depth > 3 ? '⚠️ HIGH' : '✅ OK'}"
  puts "Target: < 3 levels"
  puts ""
  puts "Planning Lag: #{avg_lag} days #{avg_lag > 2 ? '⚠️ HIGH' : '✅ OK'}"
  puts "Target: < 2 days"
  puts ""
  puts "Orphan Rate: #{orphan_rate}% #{orphan_rate > 10 ? '⚠️ HIGH' : '✅ OK'}"
  puts "Target: < 10%"
  puts ""

  {
    tickets_per_week: avg_per_week.round(1),
    priority_distribution: {
      p0: p0_pct,
      p1: p1_pct,
      p2: p2_pct,
      p3: p3_pct,
      p4: p4_pct
    },
    high_priority_pct: high_priority_pct,
    dependency_depth: max_depth,
    planning_lag_days: avg_lag,
    orphan_rate: orphan_rate
  }
end

# IMPLEMENTATION PHASE ANALYSIS
def analyze_implementation(issues, options)
  puts "=" * 80
  puts "IMPLEMENTATION PHASE ANALYSIS"
  puts "=" * 80
  puts ""

  closed = issues.select { |i| i['status'] == 'closed' }

  # Cycle time by priority
  cycle_times = {}
  [0, 1, 2, 3, 4].each do |priority|
    priority_issues = closed.select { |i| i['priority'] == priority && i['created_at'] && i['updated_at'] }
    times = priority_issues.map do |issue|
      created = Time.parse(issue['created_at'])
      updated = Time.parse(issue['updated_at'])
      (updated - created) / 86400.0 # Days
    end
    cycle_times["p#{priority}"] = times.empty? ? 0 : (times.sum / times.count).round(2)
  end

  # Completion rate
  created_count = issues.count
  closed_count = closed.count
  completion_rate = created_count > 0 ? (closed_count.to_f / created_count * 100).round(1) : 0

  # Blocked tasks
  blocked = issues.select { |i| i['blocked_by']&.any? }
  blocked_pct = (blocked.count.to_f / issues.count * 100).round(1)

  # Re-work rate (tasks with review-finding label that were closed and reopened)
  review_findings = issues.select { |i| i['labels']&.include?('review-finding') }
  rework_rate = (review_findings.count.to_f / closed_count * 100).round(1) if closed_count > 0

  puts "Cycle Time by Priority:"
  puts "  P0: #{cycle_times['p0']} days #{cycle_times['p0'] > 1 ? '⚠️ HIGH' : '✅ OK'} (target: < 1 day)"
  puts "  P1: #{cycle_times['p1']} days #{cycle_times['p1'] > 2 ? '⚠️ HIGH' : '✅ OK'} (target: < 2 days)"
  puts "  P2: #{cycle_times['p2']} days #{cycle_times['p2'] > 3 ? '⚠️ HIGH' : '✅ OK'} (target: < 3 days)"
  puts "  P3: #{cycle_times['p3']} days"
  puts "  P4: #{cycle_times['p4']} days"
  puts ""
  puts "Completion Rate: #{completion_rate}% #{completion_rate < 90 ? '⚠️ LOW' : '✅ OK'}"
  puts "Target: > 90%"
  puts ""
  puts "Blocked Tasks: #{blocked.count} (#{blocked_pct}%)"
  puts ""
  puts "Re-work Rate: #{rework_rate}% #{rework_rate > 20 ? '⚠️ HIGH' : '✅ OK'}"
  puts "Target: < 20%"
  puts ""

  {
    cycle_time_days: cycle_times,
    completion_rate: completion_rate,
    blocked_count: blocked.count,
    blocked_pct: blocked_pct,
    rework_rate: rework_rate || 0
  }
end

# REVIEW PHASE ANALYSIS
def analyze_review(issues, options)
  puts "=" * 80
  puts "REVIEW PHASE ANALYSIS"
  puts "=" * 80
  puts ""

  # Find parent tasks (tasks that have children = review findings)
  parent_tasks = issues.select { |i| has_children?(i, issues) }

  # Review findings (children of parent tasks)
  review_findings = issues.select { |i| i['parent'] && issues.any? { |p| p['id'] == i['parent'] } }

  # Average findings per review
  avg_findings = parent_tasks.empty? ? 0 : (review_findings.count.to_f / parent_tasks.count).round(1)

  # Approval rate (tasks with review-passed label)
  approved = issues.select { |i| i['labels']&.include?('review-passed') }
  approval_rate = parent_tasks.empty? ? 0 : (approved.count.to_f / parent_tasks.count * 100).round(1)

  # Findings by priority
  findings_by_priority = review_findings.group_by { |i| i['priority'] }
  total_findings = review_findings.count.to_f

  p0_findings = findings_by_priority[0]&.count || 0
  p1_findings = findings_by_priority[1]&.count || 0
  p2_findings = findings_by_priority[2]&.count || 0
  p3_findings = findings_by_priority[3]&.count || 0
  p4_findings = findings_by_priority[4]&.count || 0

  blocking_findings_pct = total_findings > 0 ? ((p0_findings + p1_findings + p2_findings) / total_findings * 100).round(1) : 0
  polish_findings_pct = total_findings > 0 ? ((p3_findings + p4_findings) / total_findings * 100).round(1) : 0

  # Documentation finding rate
  doc_findings = review_findings.select { |i| i['labels']&.include?('documentation') || i['title'] =~ /YARD|TSDoc|JSDoc|documentation/i }
  doc_finding_rate = total_findings > 0 ? (doc_findings.count / total_findings * 100).round(1) : 0

  puts "Reviews Performed: #{parent_tasks.count}"
  puts "Findings Generated: #{review_findings.count}"
  puts ""
  puts "Average Findings per Review: #{avg_findings} #{avg_findings > 5 ? '⚠️ HIGH' : '✅ OK'}"
  puts "Target: 2-5"
  puts ""
  puts "Approval Rate: #{approval_rate}% #{approval_rate < 60 ? '⚠️ LOW' : '✅ OK'}"
  puts "Target: > 60%"
  puts ""
  puts "Finding Distribution:"
  puts "  P0-P2 (Blocking): #{blocking_findings_pct}% #{blocking_findings_pct < 40 || blocking_findings_pct > 60 ? '⚠️' : '✅ OK'}"
  puts "  P3-P4 (Polish):   #{polish_findings_pct}% #{polish_findings_pct < 40 || polish_findings_pct > 60 ? '⚠️' : '✅ OK'}"
  puts "  Target: 40-60% each"
  puts ""
  puts "Documentation Finding Rate: #{doc_finding_rate}% #{doc_finding_rate > 30 ? '⚠️ HIGH' : '✅ OK'}"
  puts "Target: < 30%"
  puts ""

  {
    reviews_performed: parent_tasks.count,
    total_findings: review_findings.count,
    avg_findings_per_review: avg_findings,
    approval_rate: approval_rate,
    blocking_findings_pct: blocking_findings_pct,
    polish_findings_pct: polish_findings_pct,
    doc_finding_rate: doc_finding_rate
  }
end

# Helper: Calculate dependency depth
def calculate_dependency_depth(issue, all_issues, visited = Set.new)
  return 0 if visited.include?(issue['id'])
  visited.add(issue['id'])

  blocked_by = issue['blocked_by'] || []
  return 0 if blocked_by.empty?

  max_depth = 0
  blocked_by.each do |dep_id|
    dep_issue = all_issues.find { |i| i['id'] == dep_id }
    next unless dep_issue

    depth = calculate_dependency_depth(dep_issue, all_issues, visited)
    max_depth = [max_depth, depth].max
  end

  max_depth + 1
end

# Helper: Check if issue was never started
def never_started?(issue)
  issue['status'] == 'open' && (issue['created_at'] == issue['updated_at'] || issue['updated_at'].nil?)
end

# Helper: Check if issue has children
def has_children?(issue, all_issues)
  all_issues.any? { |i| i['parent'] == issue['id'] }
end

# GENERATE RECOMMENDATIONS
def generate_recommendations(metrics)
  puts "=" * 80
  puts "RECOMMENDATIONS"
  puts "=" * 80
  puts ""

  recommendations = []

  # Check for high-priority inflation
  if metrics[:planning][:high_priority_pct] > 60
    recommendations << {
      priority: 0,
      title: "Reduce Priority Inflation",
      description: "#{metrics[:planning][:high_priority_pct]}% of tasks are P0-P2 (target: 30-50%). This causes focus dilution and lower completion rates.",
      action: "Review and downgrade over-prioritized tasks. Enforce priority budgets: max 20% P0, max 30% P1.",
      impact: "30% improvement in P0-P1 completion rate"
    }
  end

  # Check for documentation overhead
  if metrics[:review][:doc_finding_rate] > 30
    recommendations << {
      priority: 0,
      title: "Reduce Documentation Task Bloat",
      description: "#{metrics[:review][:doc_finding_rate]}% of review findings are documentation-related (target: < 30%). This blocks feature delivery.",
      action: "Apply NEW vs EXISTING code distinction. Documentation for EXISTING code → P3-P4 (polish).",
      impact: "30-50% reduction in blocked features"
    }
  end

  # Check for dependency gridlock
  if metrics[:planning][:dependency_depth] > 3
    recommendations << {
      priority: 1,
      title: "Reduce Dependency Complexity",
      description: "Max dependency depth is #{metrics[:planning][:dependency_depth]} levels (target: < 3). This causes gridlock and delays.",
      action: "Break complex tasks into smaller, independent units. Enforce max 2-level dependencies.",
      impact: "40% reduction in blocked time"
    }
  end

  # Check for low completion rate
  if metrics[:implementation][:completion_rate] < 90
    recommendations << {
      priority: 1,
      title: "Improve Completion Rate",
      description: "Only #{metrics[:implementation][:completion_rate]}% of tasks are completed (target: > 90%). Work is being abandoned.",
      action: "Identify and close/delete orphaned tasks. Improve task scoping to prevent abandonment.",
      impact: "Clearer backlog, better focus"
    }
  end

  # Check for review bottleneck
  if metrics[:review][:avg_findings_per_review] > 5
    recommendations << {
      priority: 1,
      title: "Reduce Review Findings",
      description: "Average #{metrics[:review][:avg_findings_per_review]} findings per review (target: 2-5). Code quality issues.",
      action: "Add pre-review checklist for implementers. Run linters before submitting for review.",
      impact: "50% reduction in review lag time"
    }
  end

  # Check for high cycle time
  if metrics[:implementation][:cycle_time_days]['p0'] > 1
    recommendations << {
      priority: 2,
      title: "Reduce P0 Cycle Time",
      description: "P0 tasks taking #{metrics[:implementation][:cycle_time_days]['p0']} days on average (target: < 1 day).",
      action: "Investigate P0 task scope. Break down large P0 tasks. Ensure P0 work is unblocked.",
      impact: "Faster resolution of critical issues"
    }
  end

  # Check for low polish completion
  if metrics[:review][:polish_findings_pct] > 50
    recommendations << {
      priority: 2,
      title: "Schedule Polish Time",
      description: "#{metrics[:review][:polish_findings_pct]}% of findings are polish work (P3-P4). Backlog may be growing.",
      action: "Schedule 'Polish Friday' or dedicated polish sessions. Use polish_backlog.rb to prioritize.",
      impact: "Controlled tech debt, improved code quality"
    }
  end

  # Sort by priority and display
  recommendations.sort_by { |r| r[:priority] }.each_with_index do |rec, index|
    priority_label = case rec[:priority]
    when 0 then "[P0 - CRITICAL]"
    when 1 then "[P1 - MAJOR]"
    when 2 then "[P2 - MODERATE]"
    else "[P#{rec[:priority]}]"
    end

    puts "#{index + 1}. #{priority_label} #{rec[:title]}"
    puts ""
    puts "   Problem:  #{rec[:description]}"
    puts "   Action:   #{rec[:action]}"
    puts "   Impact:   #{rec[:impact]}"
    puts ""
  end

  if recommendations.empty?
    puts "✅ No major issues detected! Workflow is operating within target ranges."
    puts ""
  end

  recommendations
end

# Run analysis based on phase option
metrics = {}

if options[:phase].nil? || options[:phase] == 'planning'
  metrics[:planning] = analyze_planning(all_issues, options)
end

if options[:phase].nil? || options[:phase] == 'implementation'
  metrics[:implementation] = analyze_implementation(all_issues, options)
end

if options[:phase].nil? || options[:phase] == 'review'
  metrics[:review] = analyze_review(all_issues, options)
end

# Generate recommendations if running full analysis
if options[:phase].nil?
  recommendations = generate_recommendations(metrics)
  metrics[:recommendations] = recommendations
end

# Export metrics if requested
if options[:export_file]
  metrics[:timestamp] = Time.now.iso8601
  metrics[:period] = {
    since: options[:since]&.to_s,
    last_days: options[:last_days]
  }

  File.write(options[:export_file], JSON.pretty_generate(metrics))
  puts "=" * 80
  puts "Metrics exported to: #{options[:export_file]}"
  puts "=" * 80
end

# Compare with previous metrics if requested
if options[:compare_file]
  puts "=" * 80
  puts "COMPARISON WITH PREVIOUS METRICS"
  puts "=" * 80
  puts ""

  previous = JSON.parse(File.read(options[:compare_file]))

  puts "Planning Phase:"
  puts "  Tickets/Week:       #{metrics[:planning][:tickets_per_week]} (was #{previous['planning']['tickets_per_week']})"
  puts "  High Priority %:    #{metrics[:planning][:high_priority_pct]}% (was #{previous['planning']['high_priority_pct']}%)"
  puts ""
  puts "Implementation Phase:"
  puts "  Completion Rate:    #{metrics[:implementation][:completion_rate]}% (was #{previous['implementation']['completion_rate']}%)"
  puts "  P0 Cycle Time:      #{metrics[:implementation][:cycle_time_days]['p0']} days (was #{previous['implementation']['cycle_time_days']['p0']} days)"
  puts ""
  puts "Review Phase:"
  puts "  Approval Rate:      #{metrics[:review][:approval_rate]}% (was #{previous['review']['approval_rate']}%)"
  puts "  Doc Finding Rate:   #{metrics[:review][:doc_finding_rate]}% (was #{previous['review']['doc_finding_rate']}%)"
  puts ""
end

puts "=" * 80
puts "ANALYSIS COMPLETE"
puts "=" * 80
