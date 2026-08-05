#!/usr/bin/env ruby
# frozen_string_literal: true

# Updates (or inserts) one plugin's entry in a Claude Code marketplace catalog.
#
# The catalog lives in the distribution repo (javier-sy/claude-plugins) and is
# shared by every yeste.studio plugin, so this touches only the entry whose
# name matches the generated plugin.json and leaves everything else — other
# plugins, catalog metadata, fields this script does not know about — intact.
# That is what lets two plugins' CI runs publish to the same catalog without
# one overwriting the other's entry.
#
# Usage:
#   update-marketplace-entry.rb <marketplace.json> <plugin.json> <source-path>
#
# Example (from the CI, after copying dist/claude-code/ into dist-repo/nota/):
#   ruby scripts/update-marketplace-entry.rb \
#     dist-repo/.claude-plugin/marketplace.json \
#     dist-repo/nota/.claude-plugin/plugin.json \
#     ./nota
#
# Exits 0 whether or not anything changed; the caller decides what to do with
# an unchanged file (the CI skips the commit).

require "json"

PROGRAM = File.basename($PROGRAM_NAME)

def die(message)
  warn "#{PROGRAM}: #{message}"
  exit 1
end

catalog_path, manifest_path, source_path = ARGV

unless catalog_path && manifest_path && source_path
  die "usage: #{PROGRAM} <marketplace.json> <plugin.json> <source-path>"
end

die "catalog not found: #{catalog_path}" unless File.exist?(catalog_path)
die "plugin manifest not found: #{manifest_path}" unless File.exist?(manifest_path)

catalog = JSON.parse(File.read(catalog_path))
manifest = JSON.parse(File.read(manifest_path))

name = manifest["name"]
die "plugin manifest has no name: #{manifest_path}" if name.nil? || name.empty?

plugins = catalog["plugins"]
die "catalog has no plugins array: #{catalog_path}" unless plugins.is_a?(Array)

# Only these three fields are derived from the plugin; anything else already
# present in the entry is the catalog's own business and survives untouched.
derived = {
  "name" => name,
  "source" => source_path,
  "description" => manifest["description"],
  "version" => manifest["version"]
}.compact

existing = plugins.find { |entry| entry.is_a?(Hash) && entry["name"] == name }

if existing
  existing.merge!(derived)
else
  plugins << derived
  warn "#{PROGRAM}: inserted new entry '#{name}'"
end

catalog["plugins"] = plugins.sort_by { |entry| entry["name"].to_s }

updated = JSON.pretty_generate(catalog) + "\n"

if File.read(catalog_path) == updated
  puts "#{PROGRAM}: '#{name}' already up to date at #{derived["version"]}"
else
  File.write(catalog_path, updated)
  puts "#{PROGRAM}: '#{name}' → #{derived["version"]} (source: #{source_path})"
end
