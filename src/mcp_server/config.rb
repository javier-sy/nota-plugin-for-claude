# frozen_string_literal: true

# Harness-agnostic configuration for the Nota knowledge base.
#
# These three values are the ONLY harness-specific surface in the MCP server.
# They are driven by environment variables, set by each harness's generated config:
#
#   NOTA_USER_DIR    — where user data lives (frameworks, best-practices/, private.db).
#                      OVERRIDE ONLY: unset means ~/.config/nota, resolved by Ruby.
#   NOTA_CMD_PREFIX  — how to reference skills in user-facing strings.
#                      Non-empty (e.g. "/nota:") → "#{prefix}#{skill}" (Claude Code slash).
#                      Empty → "the #{skill} skill" (opencode, model-invoked, no slash).
#   NOTA_GITHUB_REPO — the GitHub repo (owner/name) hosting knowledge.db releases.
#
# Defaults assume the Claude Code target (the incumbent), so the server keeps
# working unchanged for existing installs when env vars are not set.

module NotaKnowledgeBase
  module Config
    module_function

    # Read a variable the harness was supposed to set, and refuse a placeholder.
    #
    # A harness writes these values into a config file before it knows the
    # machine it will run on. Claude Code, when the config says "${HOME}" and
    # HOME is not defined — the normal case on Windows, where the home directory
    # is USERPROFILE — loads the server anyway and passes the literal text
    # "${HOME}" through. That is not a value, it is the absence of one, and a
    # path built from it names a directory called "${HOME}".
    #
    # So: an unexpanded placeholder reads as unset, and the caller falls back to
    # what it would have used had the harness said nothing at all.
    def env(name)
      value = ENV[name]
      return nil if value.nil? || value.include?("${")

      value
    end

    # Where the user's own material lives. Ruby resolves the home directory on
    # every platform it runs on (HOME, then HOMEDRIVE+HOMEPATH, then USERPROFILE
    # on Windows), which is why no harness needs to compute this path for us.
    # Where the downloaded knowledge index lives.
    #
    # Defined here, and only here, because two different processes have to agree
    # on it and cannot share much else: the MCP server reads it through DB, and
    # the SessionStart hook writes it through EnsureDB, which runs before Bundler
    # exists and therefore cannot load anything that needs a gem.
    #
    # It was duplicated once, one copy was moved into the user directory and the
    # other was not, and for a day the hook downloaded every update into a
    # directory nobody read. The download reported success, because it had
    # succeeded -- somewhere else.
    #
    # Under the user directory rather than the plugin's: a plugin install is
    # versioned, so anything cached inside it is discarded on the next update.
    def knowledge_db_path
      env_path = env("KNOWLEDGE_DB_PATH")
      return env_path if env_path

      File.join(user_dir, "knowledge.db")
    end

    def user_dir
      dir = env("NOTA_USER_DIR")
      return dir if dir && !dir.empty?

      File.join(Dir.home, ".config", "nota")
    end

    # An empty prefix is a value, not an absence: it is how opencode says that
    # skills are model-invoked and have no slash.
    def cmd_prefix
      env("NOTA_CMD_PREFIX") || "/nota:"
    end

    # Reference a skill in a user-facing string, adapting to the harness convention.
    #   Claude Code ("/nota:") → "/nota:setup"
    #   opencode      ("")      → "the setup skill"
    def cmd_ref(skill)
      prefix = cmd_prefix
      prefix.empty? ? "the #{skill} skill" : "#{prefix}#{skill}"
    end

    def github_repo
      repo = env("NOTA_GITHUB_REPO")
      return repo if repo && !repo.empty?

      "javier-sy/nota-plugin"
    end
  end
end
