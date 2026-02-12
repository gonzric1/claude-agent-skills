#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'time'
require 'open3'
require 'fileutils'

# Audit logger for beads-workflow-diagnostics
#
# Captures comprehensive logs of all fixes:
# - What was changed
# - Why it was changed
# - History of affected beads
# - Before/after state

class AuditLogger
  LOG_DIR = '.agent/logs/beads-diagnostics'

  def initialize(fix_type)
    @fix_type = fix_type
    @log_file = create_log_file
    @entries = []
    @timestamp = Time.now.utc.iso8601

    log_header
  end

  def log_fix(issue_id:, issue_title:, problem:, action:, details: {})
    entry = {
      timestamp: Time.now.utc.iso8601,
      issue_id: issue_id,
      issue_title: issue_title,
      problem: problem,
      action: action,
      details: details
    }

    # Gather comprehensive history
    entry[:history] = gather_history(issue_id)
    entry[:before_state] = get_issue_state(issue_id)

    @entries << entry

    # Write to log file immediately (in case of crash)
    append_to_log(entry)

    entry
  end

  def log_fix_result(issue_id:, success:, message:)
    entry = @entries.find { |e| e[:issue_id] == issue_id }
    return unless entry

    entry[:after_state] = get_issue_state(issue_id)
    entry[:success] = success
    entry[:result_message] = message

    append_to_log({
      timestamp: Time.now.utc.iso8601,
      issue_id: issue_id,
      type: 'result',
      success: success,
      message: message,
      after_state: entry[:after_state]
    })
  end

  def finalize
    summary = {
      timestamp: Time.now.utc.iso8601,
      type: 'summary',
      fix_type: @fix_type,
      total_fixes: @entries.size,
      successful: @entries.count { |e| e[:success] },
      failed: @entries.count { |e| e[:success] == false },
      issues_affected: @entries.map { |e| e[:issue_id] }.uniq
    }

    append_to_log(summary)

    puts "\n📝 Audit log written to: #{@log_file}"

    @log_file
  end

  private

  def create_log_file
    FileUtils.mkdir_p(LOG_DIR)
    timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    file = File.join(LOG_DIR, "#{@fix_type}_#{timestamp}.jsonl")

    # Create empty file
    File.write(file, '')

    file
  end

  def log_header
    header = {
      timestamp: @timestamp,
      type: 'session_start',
      fix_type: @fix_type,
      log_file: @log_file
    }

    append_to_log(header)
  end

  def append_to_log(entry)
    File.open(@log_file, 'a') do |f|
      f.puts(JSON.generate(entry))
    end
  end

  def gather_history(issue_id)
    history = {}

    # Get bd comments
    history[:comments] = get_bd_comments(issue_id)

    # Get git history for this issue in issues.jsonl
    history[:git_log] = get_git_history(issue_id)

    # Try to get issue events/history if available
    history[:bd_show] = get_bd_show(issue_id)

    history
  end

  def get_bd_comments(issue_id)
    output, status = run_command("bd comments #{issue_id} --json")
    return [] unless status.success?

    begin
      JSON.parse(output)
    rescue JSON::ParserError
      []
    end
  end

  def get_git_history(issue_id)
    # Get git log for changes to this issue in issues.jsonl
    # Use grep to find commits that touched this issue
    cmd = "git log --all --grep='#{issue_id}' --pretty=format:'%H|%ai|%an|%s' --max-count=20"
    output, status = run_command(cmd)
    return [] unless status.success?

    output.lines.map do |line|
      parts = line.strip.split('|', 4)
      next if parts.size < 4

      {
        commit: parts[0],
        date: parts[1],
        author: parts[2],
        message: parts[3]
      }
    end.compact
  end

  def get_bd_show(issue_id)
    output, status = run_command("bd show #{issue_id} --json")
    return nil unless status.success?

    begin
      JSON.parse(output)
    rescue JSON::ParserError
      nil
    end
  end

  def get_issue_state(issue_id)
    # Get full issue state from bd export
    output, status = run_command("bd export")
    return nil unless status.success?

    all_issues = output.lines.map { |line| JSON.parse(line.strip) }
    issue = all_issues.find { |i| i['id'] == issue_id }

    return nil unless issue

    {
      status: issue['status'],
      labels: issue['labels'] || [],
      dependencies: issue['dependencies'] || [],
      assignee: issue['assignee'],
      metadata: issue['metadata'] || {},
      updated_at: issue['updated_at']
    }
  rescue JSON::ParserError
    nil
  end

  def run_command(cmd)
    output, status = Open3.capture2e(cmd)
    [output, status]
  end
end
