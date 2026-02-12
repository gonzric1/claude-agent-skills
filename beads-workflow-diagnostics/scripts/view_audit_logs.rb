#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'time'

# View audit logs from beads-workflow-diagnostics fixes
#
# Usage:
#   ruby view_audit_logs.rb                    # Show latest log
#   ruby view_audit_logs.rb --all              # Show all logs
#   ruby view_audit_logs.rb --issue PrintMines-123  # Show logs for specific issue

LOG_DIR = '.agent/logs/beads-diagnostics'

class AuditLogViewer
  def initialize(args)
    @show_all = args.include?('--all')
    @issue_id = extract_issue_id(args)
    @verbose = args.include?('--verbose') || args.include?('-v')
  end

  def run
    unless Dir.exist?(LOG_DIR)
      puts "No audit logs found. Run a fix script first."
      exit 0
    end

    log_files = Dir.glob(File.join(LOG_DIR, '*.jsonl')).sort_by { |f| File.mtime(f) }.reverse

    if log_files.empty?
      puts "No audit logs found."
      exit 0
    end

    if @show_all
      display_all_logs(log_files)
    elsif @issue_id
      display_logs_for_issue(log_files, @issue_id)
    else
      display_latest_log(log_files.first)
    end
  end

  private

  def extract_issue_id(args)
    issue_index = args.index('--issue')
    return nil unless issue_index

    args[issue_index + 1]
  end

  def display_latest_log(log_file)
    puts "📋 Latest Audit Log: #{File.basename(log_file)}"
    puts "   Last modified: #{File.mtime(log_file).strftime('%Y-%m-%d %H:%M:%S')}"
    puts "=" * 80
    puts

    display_log_contents(log_file)
  end

  def display_all_logs(log_files)
    puts "📚 All Audit Logs (#{log_files.size} files)"
    puts "=" * 80
    puts

    log_files.each_with_index do |log_file, index|
      puts "\n#{index + 1}. #{File.basename(log_file)}"
      puts "   Last modified: #{File.mtime(log_file).strftime('%Y-%m-%d %H:%M:%S')}"
      puts "   " + "-" * 76

      display_log_contents(log_file, summary_only: !@verbose)

      puts unless index == log_files.size - 1
    end
  end

  def display_logs_for_issue(log_files, issue_id)
    puts "🔍 Audit Logs for Issue: #{issue_id}"
    puts "=" * 80
    puts

    found_any = false

    log_files.each do |log_file|
      entries = read_log_file(log_file)
      relevant_entries = entries.select { |e| e['issue_id'] == issue_id }

      next if relevant_entries.empty?

      found_any = true

      puts "\n📄 #{File.basename(log_file)}"
      puts "   #{File.mtime(log_file).strftime('%Y-%m-%d %H:%M:%S')}"
      puts "   " + "-" * 76

      relevant_entries.each do |entry|
        display_entry(entry)
      end
    end

    unless found_any
      puts "No logs found for issue #{issue_id}"
    end
  end

  def display_log_contents(log_file, summary_only: false)
    entries = read_log_file(log_file)

    session_start = entries.find { |e| e['type'] == 'session_start' }
    summary = entries.find { |e| e['type'] == 'summary' }
    fixes = entries.reject { |e| ['session_start', 'summary', 'result'].include?(e['type']) }

    if session_start
      puts "Fix Type: #{session_start['fix_type']}"
      puts "Started: #{format_time(session_start['timestamp'])}"
      puts
    end

    if summary
      puts "Summary:"
      puts "  Total fixes: #{summary['total_fixes']}"
      puts "  Successful: #{summary['successful']}"
      puts "  Failed: #{summary['failed']}" if summary['failed'] > 0
      puts "  Issues affected: #{summary['issues_affected']&.join(', ')}"
      puts
    end

    return if summary_only

    if fixes.any?
      puts "Detailed Fixes:"
      puts "-" * 80

      fixes.each do |entry|
        display_entry(entry)
      end
    end
  end

  def display_entry(entry)
    return if entry['type'] == 'result' # Results are shown inline

    puts "\n🔧 #{entry['issue_id']}: #{entry['issue_title']}"
    puts "   Time: #{format_time(entry['timestamp'])}"
    puts
    puts "   Problem: #{entry['problem']}"
    puts "   Action: #{entry['action']}"

    if entry['details']
      puts
      puts "   Details:"
      entry['details'].each do |key, value|
        puts "     #{key}: #{format_value(value)}"
      end
    end

    if entry['before_state']
      puts
      puts "   Before State:"
      puts "     Status: #{entry['before_state']['status']}"
      puts "     Labels: #{entry['before_state']['labels']&.join(', ') || 'none'}"
      puts "     Dependencies: #{entry['before_state']['dependencies']&.size || 0}"
      puts "     Assignee: #{entry['before_state']['assignee'] || 'none'}"
    end

    if entry['after_state']
      puts
      puts "   After State:"
      puts "     Status: #{entry['after_state']['status']}"
      puts "     Labels: #{entry['after_state']['labels']&.join(', ') || 'none'}"
      puts "     Dependencies: #{entry['after_state']['dependencies']&.size || 0}"
    end

    if entry['history']
      display_history(entry['history'])
    end

    if entry['success'] != nil
      result_icon = entry['success'] ? '✅' : '❌'
      puts
      puts "   Result: #{result_icon} #{entry['result_message']}"
    end

    puts "   " + "-" * 76
  end

  def display_history(history)
    puts
    puts "   History:"

    if history['comments']&.any?
      puts "     Comments (#{history['comments'].size}):"
      history['comments'].first(3).each do |comment|
        puts "       - #{comment['created_at']}: #{comment['body']&.lines&.first&.strip}"
      end
      puts "       ... and #{history['comments'].size - 3} more" if history['comments'].size > 3
    end

    if history['git_log']&.any?
      puts "     Git History (#{history['git_log'].size} commits):"
      history['git_log'].first(5).each do |commit|
        puts "       - #{commit['date']}: #{commit['message']}"
      end
      puts "       ... and #{history['git_log'].size - 5} more" if history['git_log'].size > 5
    end
  end

  def read_log_file(log_file)
    File.readlines(log_file).map do |line|
      JSON.parse(line.strip)
    rescue JSON::ParserError
      nil
    end.compact
  end

  def format_time(timestamp)
    Time.parse(timestamp).strftime('%Y-%m-%d %H:%M:%S')
  rescue
    timestamp
  end

  def format_value(value)
    case value
    when Array
      value.join(', ')
    when Hash
      JSON.pretty_generate(value).gsub("\n", "\n       ")
    else
      value.to_s
    end
  end
end

# Run viewer
AuditLogViewer.new(ARGV).run
