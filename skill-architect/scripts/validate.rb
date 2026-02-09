#!/usr/bin/env ruby
require 'yaml'

target_skill_path = ARGV[0] || Dir.pwd

unless File.exist?(File.join(target_skill_path, "SKILL.md"))
  puts "❌ Error: No SKILL.md found in #{target_skill_path}"
  exit 1
end

skill_file = File.join(target_skill_path, "SKILL.md")
dir_name = File.basename(target_skill_path)

begin
  # Extract YAML frontmatter
  raw_content = File.read(skill_file)
  if raw_content =~ /\A---(.*?)---/m
    frontmatter = YAML.safe_load($1)
    
    errors = []
    
    # Check 1: Name match
    if frontmatter['name'] != dir_name
      errors << "Name mismatch: YAML name '#{frontmatter['name']}' does not match directory '#{dir_name}'"
    end
    
    # Check 2: Description length
    if frontmatter['description'].nil? || frontmatter['description'].length > 1024
      errors << "Description error: Must be present and < 1024 characters."
    end

    # Check 3: Script permissions
    scripts_dir = File.join(target_skill_path, "scripts")
    if Dir.exist?(scripts_dir)
      Dir.glob("#{scripts_dir}/*").each do |f|
        unless File.executable?(f)
          errors << "Permission error: Script '#{File.basename(f)}' is not executable."
        end
      end
    end

    if errors.empty?
      puts "✅ Skill '#{dir_name}' is valid according to spec!"
    else
      puts "❌ Validation failed for '#{dir_name}':"
      errors.each { |e| puts "  - #{e}" }
      exit 1
    end
    
  else
    puts "❌ Error: No YAML frontmatter found in SKILL.md"
    exit 1
  end
rescue => e
  puts "❌ Script error during validation: #{e.message}"
  exit 1
end