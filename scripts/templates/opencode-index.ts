import type { Plugin } from "@opencode-ai/plugin"
import { execFileSync } from "node:child_process"
import { dirname } from "node:path"
import { fileURLToPath } from "node:url"

// Nota — opencode plugin wrapper.
// Self-locates its package directory and injects the MusaDSL knowledge-base
// MCP server (Ruby, bundled in this package), always-in-context instructions,
// and generated skills via the `config` hook.
//
// The user provides Ruby 3.1+ and VOYAGE_API_KEY. Run `bundle install` in the
// package directory once (the MCP server needs the `mcp`, `sqlite3`, and
// `sqlite-vec` gems).

const HERE = dirname(fileURLToPath(import.meta.url))
const GITHUB_REPO = "{{GITHUB_REPO}}"

export default (async () => {
  return {
    config: (cfg) => {
      // 1. Inject the MusaDSL knowledge-base MCP server (Ruby stdio, bundled here)
      cfg.mcp = cfg.mcp ?? {}
      cfg.mcp["knowledge-base"] = {
        type: "local" as const,
        command: ["ruby", "-r", "bundler/setup", `${HERE}/mcp_server/server.rb`],
        cwd: HERE,
        environment: {
          VOYAGE_API_KEY: process.env.VOYAGE_API_KEY ?? "",
          KNOWLEDGE_DB_PATH: `${HERE}/mcp_server/knowledge.db`,
          PRIVATE_DB_PATH: `${process.env.HOME}/.config/nota/private.db`,
          BUNDLE_GEMFILE: `${HERE}/Gemfile`,
          // opencode: skills are model-invoked (no slash) → "the X skill" in server strings
          NOTA_CMD_PREFIX: "",
          NOTA_USER_DIR: `${process.env.HOME}/.config/nota`,
          NOTA_GITHUB_REPO: GITHUB_REPO,
        },
        enabled: true,
        timeout: 30000,
      }

      // 2. Always-in-context files.
      //
      //    How the assistant behaves is ours and ships with the package. What
      //    musa-dsl IS belongs to musa-dsl: its symptom index and its vocabulary
      //    are read from the INSTALLED GEM, resolved now rather than at build
      //    time, because the version the user has is the version they should be
      //    reading. A copy of them here would drift, and every copy that ever
      //    existed did.
      cfg.instructions = cfg.instructions ?? []
      cfg.instructions.push(`${HERE}/rules/think-journal.md`)

      try {
        const resolved = execFileSync(
          "ruby",
          [`${HERE}/mcp_server/musa_docs.rb`, "--paths"],
          { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] },
        ).trim()

        // One path per line, or nothing at all when the gem is missing or below
        // the floor — in which case the MCP server says so on first use. There
        // is no degraded fallback by design: serving documentation from the
        // wrong version is what reading from the gem exists to prevent.
        if (resolved) cfg.instructions.push(...resolved.split("\n"))
      } catch {
        // No Ruby, or no gem. The knowledge-base tools report it in context.
      }

      // 3. Generated skills (model-invoked, descriptions rich with trigger keywords)
      cfg.skills = cfg.skills ?? { paths: [] }
      cfg.skills.paths = cfg.skills.paths ?? []
      cfg.skills.paths.push(`${HERE}/skills`)

      // 4. Slash commands — thin wrappers that delegate to the skills above.
      //    Both /nota:<name> (canonical, matches Claude Code) and /<name>
      //    (short synonym) are registered, so Claude Code users feel at home.
      cfg.command = cfg.command ?? {}
{{COMMANDS}}
    },
  }
}) satisfies Plugin
