# frozen_string_literal: true

source "https://rubygems.org"

# What the knowledge base server needs: to speak MCP, and to open an index.
#
# One group, because one process needs them. The setup server is not in this
# picture at all -- it speaks the protocol on the standard library, so that it
# can answer while these are still being installed. See mcp_server/boot.rb.
gem "mcp", "~> 0.6"
gem "sqlite3", "~> 2.0"

# sqlite-vec is NOT here, and its absence is the reason the server runs on
# Windows at all. The gem exists, and its Windows binary is fine, but it is
# published under the platform name `x86_64-mingw32` — which no Ruby on Windows
# reports. While it is a dependency, the lockfile cannot name `x64-mingw-ucrt`,
# and `bundler/setup` refuses on a platform the lock does not carry. The
# loadable extension is fetched as a release asset instead; see
# mcp_server/vec_extension.rb.

# The plugin's own checks. Not needed to run the server, so they stay out of the
# gems shipped to users.
group :development do
  gem "rspec", "~> 3.13"
end
