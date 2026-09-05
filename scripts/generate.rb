#!/usr/bin/env ruby
# frozen_string_literal: true

# Generator: reads src/manifest.yml + targets/<harness>.yml and emits
# dist/<harness>/ for each target.
#
# Usage:
#   ruby scripts/generate.rb                    # all targets
#   ruby scripts/generate.rb --target claude-code
#   ruby scripts/generate.rb --target opencode

require "yaml"
require "json"
require "fileutils"
require "optparse"

ROOT = File.expand_path("..", __dir__)
SRC = File.join(ROOT, "src")
DIST = File.join(ROOT, "dist")
TARGETS_DIR = File.join(ROOT, "targets")
TEMPLATES = File.join(ROOT, "scripts", "templates")

UNIVERSAL_EXCLUDE = [".DS_Store"].freeze

# --- Helpers ---

def load_yaml(path)
  YAML.safe_load(File.read(path), aliases: true)
rescue => e
  abort "Error loading #{path}: #{e.message}"
end

def copy_dir_excluding(src_dir, dst_dir, exclude_patterns)
  all_exclude = UNIVERSAL_EXCLUDE + exclude_patterns
  FileUtils.mkdir_p(dst_dir)
  Dir.glob(File.join(src_dir, "**", "*")).sort.each do |entry|
    rel = entry.sub("#{src_dir}/", "")
    name = File.basename(entry)
    next if all_exclude.any? { |p| name == p }

    dst = File.join(dst_dir, rel)
    if File.directory?(entry)
      FileUtils.mkdir_p(dst)
    else
      FileUtils.mkdir_p(File.dirname(dst))
      FileUtils.cp(entry, dst)
    end
  end
end

def resolve_cmd(text, target_config)
  cmd_format = target_config["cmd_format"] || "{skill}"
  text.gsub(/{{cmd:([a-z-]+)}}/) do
    skill = Regexp.last_match(1)
    cmd_format.sub("{skill}", skill)
  end
end

def transform_skill(skill_name, target_config)
  src_path = File.join(SRC, "skills", skill_name, "SKILL.md")
  unless File.exist?(src_path)
    warn "  Warning: skill '#{skill_name}' not found at #{src_path}"
    return nil
  end

  content = File.read(src_path, encoding: "utf-8")

  if content =~ /\A(---\n)(.*?)(\n---\n)(.*)\z/m
    _header, fm_body, _footer, body = $1, $2, $3, $4

    keep = target_config["frontmatter_keep"] || []
    fm_lines = fm_body.split("\n")
    filtered = fm_lines.reject do |line|
      line =~ /^([a-z_]+):/ && !keep.include?($1)
    end
    new_fm = filtered.join("\n")
    new_body = resolve_cmd(body, target_config)
    "---\n#{new_fm}\n---\n#{new_body}"
  else
    resolve_cmd(content, target_config)
  end
end

def parse_skill_frontmatter(skill_name)
  path = File.join(SRC, "skills", skill_name, "SKILL.md")
  content = File.read(path, encoding: "utf-8")
  return {} unless content =~ /\A---\n(.*?)\n---\n/m
  YAML.safe_load(Regexp.last_match(1), aliases: true) || {}
rescue => e
  warn "  Warning: could not parse frontmatter for #{skill_name}: #{e.message}"
  {}
end

# --- Target-specific file generators ---

def generate_claude_code(manifest, target_config, target_dir)
  emit = target_config["emit"] || {}
  prefix = target_config["mcp_path_prefix"] || ""

  if emit["plugin_json"]
    dir = File.join(target_dir, ".claude-plugin")
    FileUtils.mkdir_p(dir)
    plugin_json = {
      "name" => manifest["name"],
      "version" => manifest["version"],
      "description" => manifest["description"],
      "author" => manifest["author"],
      "homepage" => manifest["homepage"],
      "repository" => manifest["repository"],
      "license" => manifest["license"],
      "keywords" => manifest["keywords"],
      "mcpServers" => "./.mcp.json"
    }
    File.write(File.join(dir, "plugin.json"), JSON.pretty_generate(plugin_json) + "\n")
    puts "    ✓ .claude-plugin/plugin.json"
  end

  if emit["mcp_json"]
    mcp_env = target_config["mcp_env"] || {}
    mcp_json = {
      "mcpServers" => {
        "knowledge-base" => {
          "command" => "ruby",
          # boot.rb, not `-r bundler/setup server.rb`: Bundler must not be the
          # first thing to run, or a machine without the gems loses the server
          # before the code that installs them is reached. See mcp_server/boot.rb.
          "args" => ["#{prefix}mcp_server/boot.rb"],
          "env" => mcp_env,
          "cwd" => prefix.sub(%r{/$}, "")
        }
      }
    }
    File.write(File.join(target_dir, ".mcp.json"), JSON.pretty_generate(mcp_json) + "\n")
    puts "    ✓ .mcp.json"
  end

  if emit["hooks_json"]
    dir = File.join(target_dir, "hooks")
    FileUtils.mkdir_p(dir)
    hook_script = manifest.dig("hooks", "session_start")
    if hook_script
      hooks_json = {
        "description" => "MusaDSL knowledge base lifecycle hooks",
        "hooks" => {
          "SessionStart" => [
            {
              "hooks" => [
                # The path is quoted because a hook command is a shell line, and
                # the plugin root can hold spaces (a Windows user name) and
                # backslashes (every Windows path). Unquoted, C:\Users\Ana Ruiz\...
                # is neither one argument nor the path it spells.
                # 120s, not 30: on a first run this hook installs the server's
                # gems (five seconds on a good connection, and it is the slow
                # connections that need the room). Every later session pays
                # `bundle check`, which is local.
                { "type" => "command", "command" => %(ruby "#{prefix}#{hook_script}"), "timeout" => 120 }
              ]
            }
          ]
        }
      }
      File.write(File.join(dir, "hooks.json"), JSON.pretty_generate(hooks_json) + "\n")
      puts "    ✓ hooks/hooks.json"
    end
  end

  if emit["version_file"]
    File.write(File.join(target_dir, "VERSION"), manifest["version"] + "\n")
    puts "    ✓ VERSION"
  end
end

def generate_opencode(manifest, target_config, target_dir)
  emit = target_config["emit"] || {}

  if emit["package_json"]
    package_json = {
      "name" => target_config["npm_name"],
      "version" => manifest["version"],
      "description" => manifest["description"],
      "main" => "index.ts",
      "author" => manifest["author"]["name"],
      "license" => manifest["license"],
      "repository" => { "type" => "git", "url" => manifest["repository"] },
      "keywords" => manifest["keywords"],
      "dependencies" => { "@opencode-ai/plugin" => "^1.2.20" }
    }
    File.write(File.join(target_dir, "package.json"), JSON.pretty_generate(package_json) + "\n")
    puts "    ✓ package.json"
  end

  if emit["index_ts"]
    template = File.read(File.join(TEMPLATES, "opencode-index.ts"), encoding: "utf-8")
    content = template.gsub("{{GITHUB_REPO}}", manifest["github_repo"])
    # Slash commands: /nota:<name> (canonical) + /<name> (short synonym) per skill.
    # Thin wrappers that tell the model to invoke the corresponding skill.
    commands_block = manifest["skills"].flat_map do |skill_name|
      fm = parse_skill_frontmatter(skill_name)
      name = fm["name"] || skill_name
      desc = (fm["description"] || manifest["description"]).to_s.strip
      desc = desc.length > 120 ? desc[0, 119] + "…" : desc
      tmpl_ts = JSON.generate("Use the \"#{name}\" skill to respond to:\n\n$ARGUMENTS")
      [
        %(      cfg.command["nota:#{name}"] = { template: #{tmpl_ts}, description: #{JSON.generate(desc)} }),
        %(      cfg.command["#{name}"] = { template: #{tmpl_ts}, description: #{JSON.generate("#{desc} (nota)")} }),
      ]
    end.join("\n")
    content = content.gsub("{{COMMANDS}}", commands_block)
    File.write(File.join(target_dir, "index.ts"), content)
    puts "    ✓ index.ts (with #{manifest['skills'].size * 2} slash commands)"
  end
end

# --- Main generation ---

def run_target(name, manifest)
  target_config = load_yaml(File.join(TARGETS_DIR, "#{name}.yml"))
  target_dir = File.join(DIST, name)
  exclude = manifest["copy_exclude"] || []

  puts "  Generating dist/#{name}/..."
  FileUtils.rm_rf(target_dir)
  FileUtils.mkdir_p(target_dir)

  # Copy shared assets from src/
  manifest["shared_assets"]&.each do |asset|
    src_path = File.join(SRC, asset)
    if File.directory?(src_path)
      copy_dir_excluding(src_path, File.join(target_dir, asset), exclude)
    elsif File.exist?(src_path)
      FileUtils.mkdir_p(File.dirname(File.join(target_dir, asset)))
      FileUtils.cp(src_path, File.join(target_dir, asset))
    end
  end

  # Copy root assets (Gemfile, Gemfile.lock) from repo root
  manifest["root_assets"]&.each do |asset|
    src_path = File.join(ROOT, asset)
    FileUtils.cp(src_path, File.join(target_dir, asset)) if File.exist?(src_path)
  end

  # If knowledge.db was built locally, include it in dist (CI builds don't have it)
  kb = File.join(SRC, "mcp_server", "knowledge.db")
  if File.exist?(kb)
    FileUtils.cp(kb, File.join(target_dir, "mcp_server", "knowledge.db"))
    puts "    ✓ mcp_server/knowledge.db (local build)"
  end

  # Transform and write skills
  manifest["skills"]&.each do |skill_name|
    new_content = transform_skill(skill_name, target_config)
    next unless new_content

    dst = File.join(target_dir, "skills", skill_name, "SKILL.md")
    FileUtils.mkdir_p(File.dirname(dst))
    File.write(dst, new_content)
    puts "    ✓ skill: #{skill_name}"
  end

  # Generate target-specific files
  case name
  when "claude-code"
    generate_claude_code(manifest, target_config, target_dir)
  when "opencode"
    generate_opencode(manifest, target_config, target_dir)
  end

  puts "  dist/#{name}/ ready"
end

# --- CLI ---

target_name = nil
OptionParser.new do |opts|
  opts.on("--target TARGET", "Generate only the specified target") { |t| target_name = t }
end.parse!

manifest = load_yaml(File.join(SRC, "manifest.yml"))

targets = if target_name
  [target_name]
else
  Dir.glob(File.join(TARGETS_DIR, "*.yml")).map { |f| File.basename(f, ".yml") }.sort
end

puts "Nota plugin generator — v#{manifest['version']}"
targets.each { |t| run_target(t, manifest) }
puts "Done."
