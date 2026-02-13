#!/usr/bin/env ruby
# frozen_string_literal: true

# Workflow Retrospective - Metrics Tracker
#
# Tracks metrics over time for trend analysis
#
# Usage:
#   ruby track_metrics.rb [options]
#
# Options:
#   --record          Record current metrics to history
#   --show            Show historical trends
#   --period PERIOD   Grouping period (day, week, month)
#   --help            Show this help

require 'json'
require 'optparse'
require 'fileutils'
require 'date'
require 'time'

# Parse command line arguments
options = {
  record: false,
  show: false,
  period: 'week'
}

parser = OptionParser.new do |opts|
  opts.banner = "Usage: #{$PROGRAM_NAME} [options]"

  opts.on("-r", "--record", "Record current metrics to history") do
    options[:record] = true
  end

  opts.on("-s", "--show", "Show historical trends") do
    options[:show] = true
  end

  opts.on("-p", "--period PERIOD", "Grouping period (day, week, month)") do |v|
    options[:period] = v
  end

  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end

parser.parse!

# Ensure .agent/metrics directory exists
metrics_dir = '.agent/metrics'
FileUtils.mkdir_p(metrics_dir) unless Dir.exist?(metrics_dir)

history_file = "#{metrics_dir}/history.jsonl"

if options[:record]
  # Run analyze_pipeline.rb and capture output as JSON
  puts "Analyzing current pipeline state..."

  require 'open3'
  require 'tempfile'

  tmpfile = Tempfile.new(['metrics', '.json'])

  stdout, stderr, status = Open3.capture3("ruby #{__dir__}/analyze_pipeline.rb --export #{tmpfile.path}")

  unless status.success?
    puts "Error running analyze_pipeline.rb:"
    puts stderr
    exit 1
  end

  # Read the exported metrics
  metrics = JSON.parse(File.read(tmpfile.path))
  tmpfile.close
  tmpfile.unlink

  # Append to history
  File.open(history_file, 'a') do |f|
    f.puts(metrics.to_json)
  end

  puts "✓ Metrics recorded to #{history_file}"
  puts ""
  puts "Snapshot:"
  puts "  Timestamp: #{metrics['timestamp']}"
  puts "  Completion Rate: #{metrics['implementation']['completion_rate']}%"
  puts "  Approval Rate: #{metrics['review']['approval_rate']}%"
  puts "  Doc Finding Rate: #{metrics['review']['doc_finding_rate']}%"

elsif options[:show]
  unless File.exist?(history_file)
    puts "No historical data found. Run with --record to start tracking."
    exit 0
  end

  # Load all historical metrics
  history = File.readlines(history_file).map { |line| JSON.parse(line) }

  puts "=" * 80
  puts "METRICS TREND ANALYSIS"
  puts "=" * 80
  puts ""
  puts "Total snapshots: #{history.count}"
  puts ""

  # Group by period
  grouped = history.group_by do |snapshot|
    timestamp = Time.parse(snapshot['timestamp'])
    case options[:period]
    when 'day'
      timestamp.strftime("%Y-%m-%d")
    when 'week'
      timestamp.strftime("%Y-W%U")
    when 'month'
      timestamp.strftime("%Y-%m")
    else
      timestamp.strftime("%Y-W%U")
    end
  end

  # Calculate averages per period
  puts "Completion Rate Trend:"
  grouped.sort.each do |period, snapshots|
    avg_completion = snapshots.map { |s| s['implementation']['completion_rate'] }.compact.sum / snapshots.count.to_f
    puts "  #{period}: #{avg_completion.round(1)}%"
  end
  puts ""

  puts "Approval Rate Trend:"
  grouped.sort.each do |period, snapshots|
    avg_approval = snapshots.map { |s| s['review']['approval_rate'] }.compact.sum / snapshots.count.to_f
    puts "  #{period}: #{avg_approval.round(1)}%"
  end
  puts ""

  puts "Documentation Finding Rate Trend:"
  grouped.sort.each do |period, snapshots|
    avg_doc = snapshots.map { |s| s['review']['doc_finding_rate'] }.compact.sum / snapshots.count.to_f
    puts "  #{period}: #{avg_doc.round(1)}%"
  end
  puts ""

  # Detect anomalies (sudden changes > 20%)
  puts "Anomaly Detection:"

  completion_rates = history.map { |s| s['implementation']['completion_rate'] }.compact
  approval_rates = history.map { |s| s['review']['approval_rate'] }.compact

  completion_rates.each_cons(2).with_index do |(prev, curr), index|
    change_pct = ((curr - prev) / prev * 100).abs
    if change_pct > 20
      direction = curr > prev ? "↑" : "↓"
      puts "  #{direction} Completion rate changed by #{change_pct.round(1)}% (snapshot #{index + 1} → #{index + 2})"
    end
  end

  approval_rates.each_cons(2).with_index do |(prev, curr), index|
    change_pct = ((curr - prev) / prev * 100).abs
    if change_pct > 20
      direction = curr > prev ? "↑" : "↓"
      puts "  #{direction} Approval rate changed by #{change_pct.round(1)}% (snapshot #{index + 1} → #{index + 2})"
    end
  end

  if completion_rates.each_cons(2).none? { |(prev, curr)| ((curr - prev) / prev * 100).abs > 20 } &&
     approval_rates.each_cons(2).none? { |(prev, curr)| ((curr - prev) / prev * 100).abs > 20 }
    puts "  No anomalies detected (all changes < 20%)"
  end
  puts ""

  # Overall trend
  if completion_rates.count >= 2
    first_completion = completion_rates.first
    last_completion = completion_rates.last
    completion_trend = last_completion > first_completion ? "improving" : "declining"
    completion_change = ((last_completion - first_completion) / first_completion * 100).round(1)

    puts "Overall Trends:"
    puts "  Completion Rate: #{completion_trend} (#{completion_change > 0 ? '+' : ''}#{completion_change}%)"

    first_approval = approval_rates.first
    last_approval = approval_rates.last
    approval_trend = last_approval > first_approval ? "improving" : "declining"
    approval_change = ((last_approval - first_approval) / first_approval * 100).round(1)

    puts "  Approval Rate: #{approval_trend} (#{approval_change > 0 ? '+' : ''}#{approval_change}%)"
  end

else
  puts "Usage: #{$PROGRAM_NAME} [--record | --show]"
  puts ""
  puts "Examples:"
  puts "  #{$PROGRAM_NAME} --record              # Record current metrics"
  puts "  #{$PROGRAM_NAME} --show                # Show trends"
  puts "  #{$PROGRAM_NAME} --show --period month # Group by month"
end
