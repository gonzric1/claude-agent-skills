#!/usr/bin/env ruby
require 'fileutils'

skill_name = ARGV[0]
# Default to common agent skills path; adjust if yours is different
base_path = File.expand_path("../..", __dir__)
target_dir = File.join(base_path, skill_name)

if skill_name.nil? || skill_name.empty?
  puts "Usage: ./scaffold.rb <skill-name>"
  exit 1
end

puts "🔨 Scaffolding skill: #{skill_name}..."

# 1. Create directory structure
%w[scripts references assets].each do |subdir|
  FileUtils.mkdir_p(File.join(target_dir, subdir))
end

# 2. Copy Template
template_src = File.expand_path("../assets/SKILL_TEMPLATE.md", __dir__)
dest_file = File.join(target_dir, "SKILL.md")

if File.exist?(template_src)
  content = File.read(template_src).gsub("{{NAME}}", skill_name)
  File.write(dest_file, content)
  FileUtils.chmod(0644, dest_file)
else
  puts "⚠️ Warning: SKILL_TEMPLATE.md not found in assets/"
end

puts "✅ Created #{target_dir}"