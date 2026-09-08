# frozen_string_literal: true

source "https://rubygems.org"

# What the server needs to speak MCP at all. Pure Ruby, six gems, about 6 MB:
# this is what has to be installed before anything can answer, so it is what the
# setup server runs on.
gem "mcp", "~> 0.6"

# And what it needs to open an index. sqlite3 alone weighs more than the six
# above together and is the only one that can need compiling, so it is the half
# that makes a first install slow -- slower, on a cold machine, than the thirty
# seconds Claude Code allows a server to connect in.
#
# In its own group so that the setup server can start without it and say so.
# The exclusion travels in BUNDLE_WITHOUT, per server, and deliberately not in
# .bundle/config: that file is per directory and would apply to both.
group :index do
  gem "sqlite3", "~> 2.0"
end

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
