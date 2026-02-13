#!/usr/bin/env ruby
# frozen_string_literal: true

# Workflow Retrospective - Report Generator
#
# Generates formatted markdown reports from analysis metrics
#
# Usage:
#   ruby generate_report.rb [options]
#
# Options:
#   --input FILE      Input metrics JSON (from analyze_pipeline.rb)
#   --output FILE     Output markdown file
#   --format FORMAT   Report format (summary, detailed, executive)
#   --help            Show this help

require 'json'
require 'optparse'
require 'date'
require 'time'

# Parse command line arguments
options = {
  input_file: nil,
  output_file: nil,
  format: 'executive'
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

  opts.on("-i", "--input FILE", "Input metrics JSON") do |v|
    options[:input_file] = v
  end

  opts.on("-o", "--output FILE", "Output markdown file") do |v|
    options[:output_file] = v
  end

  opts.on("-f", "--format FORMAT", "Report format (summary, detailed, executive)") do |v|
    options[:format] = v
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end

parser.parse!

# Helper: Format recommendations
def format_recommendations(recommendations)
  return "No recommendations at this time." if recommendations.empty?

  recommendations.map.with_index do |rec, index|
    priority_label = case rec['priority']
    when 0 then "[P0 - CRITICAL]"
    when 1 then "[P1 - MAJOR]"
    when 2 then "[P2 - MODERATE]"
    else "[P#{rec['priority']}]"
    end

    <<~REC
      ### #{index + 1}. #{priority_label} #{rec['title']}

      **Problem**: #{rec['description']}

      **Action**: #{rec['action']}

      **Expected Impact**: #{rec['impact']}
    REC
  end.join("\n")
end

# Helper: Status emoji for ranges
def status_emoji(value, min, max)
  value >= min && value <= max ? '✅' : '⚠️'
end

# Helper: Status emoji for less than
def status_emoji_less_than(value, threshold)
  value < threshold ? '✅' : '⚠️'
end

# Helper: Status emoji for greater than
def status_emoji_greater_than(value, threshold)
  value > threshold ? '✅' : '⚠️'
end

# Executive Summary Format
def generate_executive_summary(metrics)
  timestamp = metrics['timestamp'] ? Time.parse(metrics['timestamp']) : Time.now
  week_of = timestamp.strftime("%Y-%m-%d")

  planning = metrics['planning'] || {}
  implementation = metrics['implementation'] || {}
  review = metrics['review'] || {}
  recommendations = metrics['recommendations'] || []

  <<~MARKDOWN
    # Workflow Retrospective - Week of #{week_of}

    ## Key Findings

    ### Planning Phase
    - **Ticket Creation Rate**: #{planning['tickets_per_week']} tickets/week
    - **High-Priority Ratio**: #{planning['high_priority_pct']}% (target: 30-50%) #{status_emoji(planning['high_priority_pct'], 30, 50)}
    - **Dependency Depth**: #{planning['dependency_depth']} levels (target: < 3) #{status_emoji_less_than(planning['dependency_depth'], 3)}
    - **Planning Lag**: #{planning['planning_lag_days']} days (target: < 2 days) #{status_emoji_less_than(planning['planning_lag_days'], 2)}

    ### Implementation Phase
    - **Completion Rate**: #{implementation['completion_rate']}% (target: > 90%) #{status_emoji_greater_than(implementation['completion_rate'], 90)}
    - **P0 Cycle Time**: #{implementation['cycle_time_days']['p0']} days (target: < 1 day) #{status_emoji_less_than(implementation['cycle_time_days']['p0'], 1)}
    - **P1 Cycle Time**: #{implementation['cycle_time_days']['p1']} days (target: < 2 days) #{status_emoji_less_than(implementation['cycle_time_days']['p1'], 2)}
    - **Blocked Tasks**: #{implementation['blocked_count']} (#{implementation['blocked_pct']}%)

    ### Review Phase
    - **Reviews Performed**: #{review['reviews_performed']}
    - **Avg Findings/Review**: #{review['avg_findings_per_review']} (target: 2-5) #{status_emoji(review['avg_findings_per_review'], 2, 5)}
    - **Approval Rate**: #{review['approval_rate']}% (target: > 60%) #{status_emoji_greater_than(review['approval_rate'], 60)}
    - **Doc Finding Rate**: #{review['doc_finding_rate']}% (target: < 30%) #{status_emoji_less_than(review['doc_finding_rate'], 30)}

    ## Top Recommendations

    #{format_recommendations(recommendations.first(3))}

    ## Metrics Snapshot

    | Metric | Current | Target | Status |
    |--------|---------|--------|--------|
    | Completion Rate | #{implementation['completion_rate']}% | > 90% | #{status_emoji_greater_than(implementation['completion_rate'], 90)} |
    | P0 Cycle Time | #{implementation['cycle_time_days']['p0']} days | < 1 day | #{status_emoji_less_than(implementation['cycle_time_days']['p0'], 1)} |
    | Approval Rate | #{review['approval_rate']}% | > 60% | #{status_emoji_greater_than(review['approval_rate'], 60)} |
    | Doc Finding Rate | #{review['doc_finding_rate']}% | < 30% | #{status_emoji_less_than(review['doc_finding_rate'], 30)} |
    | High Priority % | #{planning['high_priority_pct']}% | 30-50% | #{status_emoji(planning['high_priority_pct'], 30, 50)} |

    ---
    *Generated: #{Time.now.strftime("%Y-%m-%d %H:%M:%S")}*
  MARKDOWN
end

# Summary Report Format
def generate_summary_report(metrics)
  planning = metrics['planning'] || {}
  implementation = metrics['implementation'] || {}
  review = metrics['review'] || {}

  <<~MARKDOWN
    # Workflow Retrospective Summary

    ## Planning Phase
    - Tickets/Week: #{planning['tickets_per_week']}
    - Priority Distribution: P0(#{planning['priority_distribution']['p0']}%) P1(#{planning['priority_distribution']['p1']}%) P2(#{planning['priority_distribution']['p2']}%) P3(#{planning['priority_distribution']['p3']}%) P4(#{planning['priority_distribution']['p4']}%)
    - Dependency Depth: #{planning['dependency_depth']} levels
    - Orphan Rate: #{planning['orphan_rate']}%

    ## Implementation Phase
    - Completion Rate: #{implementation['completion_rate']}%
    - Cycle Times: P0(#{implementation['cycle_time_days']['p0']}d) P1(#{implementation['cycle_time_days']['p1']}d) P2(#{implementation['cycle_time_days']['p2']}d)
    - Re-work Rate: #{implementation['rework_rate']}%

    ## Review Phase
    - Reviews: #{review['reviews_performed']}
    - Findings: #{review['total_findings']} (#{review['avg_findings_per_review']} avg)
    - Approval Rate: #{review['approval_rate']}%
    - Blocking Findings: #{review['blocking_findings_pct']}%
    - Polish Findings: #{review['polish_findings_pct']}%
  MARKDOWN
end

# Detailed Report Format
def generate_detailed_report(metrics)
  summary = generate_summary_report(metrics)
  recommendations = metrics['recommendations'] || []

  <<~MARKDOWN
    #{summary}

    ## Detailed Recommendations

    #{format_recommendations(recommendations)}

    ## Analysis Details

    ### Priority Distribution
    - P0 (Critical): #{metrics['planning']['priority_distribution']['p0']}%
    - P1 (Major): #{metrics['planning']['priority_distribution']['p1']}%
    - P2 (Moderate): #{metrics['planning']['priority_distribution']['p2']}%
    - P3 (Standard): #{metrics['planning']['priority_distribution']['p3']}%
    - P4 (Nit): #{metrics['planning']['priority_distribution']['p4']}%

    ### Cycle Time Breakdown
    - P0: #{metrics['implementation']['cycle_time_days']['p0']} days
    - P1: #{metrics['implementation']['cycle_time_days']['p1']} days
    - P2: #{metrics['implementation']['cycle_time_days']['p2']} days
    - P3: #{metrics['implementation']['cycle_time_days']['p3']} days
    - P4: #{metrics['implementation']['cycle_time_days']['p4']} days

    ### Review Finding Distribution
    - Blocking (P0-P2): #{metrics['review']['blocking_findings_pct']}%
    - Polish (P3-P4): #{metrics['review']['polish_findings_pct']}%
    - Documentation: #{metrics['review']['doc_finding_rate']}%
  MARKDOWN
end

# Main execution
unless options[:input_file]
  puts "Error: --input is required"
  puts ""
  puts "Usage: #{$PROGRAM_NAME} --input metrics.json [--output report.md] [--format executive]"
  exit 1
end

# Load metrics
metrics = JSON.parse(File.read(options[:input_file]))

# Generate report based on format
report = case options[:format]
when 'executive'
  generate_executive_summary(metrics)
when 'summary'
  generate_summary_report(metrics)
when 'detailed'
  generate_detailed_report(metrics)
else
  puts "Unknown format: #{options[:format]}"
  exit 1
end

# Output report
if options[:output_file]
  File.write(options[:output_file], report)
  puts "Report generated: #{options[:output_file]}"
else
  puts report
end
