---
name: setup
description: >-
  Use this skill when the user asks about setting up the MusaDSL plugin,
  configuring API keys, checking plugin status, or troubleshooting
  the knowledge base connection.
version: 0.2.0
---

# MusaDSL Plugin Setup

Guide the user through the configuration and troubleshooting of the MusaDSL knowledge base plugin.

## Process

1. **Check status** using the `check_setup` MCP tool to determine what's configured.

2. **Guide the user** based on the results:

### If Voyage API key is NOT SET

Explain to the user:

- They need a Voyage AI API key for semantic search to work
- Get one at https://dash.voyageai.com/
- Add it to their shell profile:

  ```bash
  # For zsh (default on macOS)
  echo 'export VOYAGE_API_KEY="your-key-here"' >> ~/.zshrc
  source ~/.zshrc

  # For bash
  echo 'export VOYAGE_API_KEY="your-key-here"' >> ~/.bashrc
  source ~/.bashrc
  ```

- After setting the variable, restart Claude Code for the MCP server to pick it up

### If knowledge base is NOT FOUND

Explain that the knowledge base should auto-download on session start. Suggest:

- Restart Claude Code to trigger the auto-download
- Check internet connectivity
- The download comes from GitHub Releases and is cached locally (~20MB)

### If everything is configured

Tell the user that the plugin is fully configured and ready. Then suggest:

- `/nota:hello` — for a welcome and full overview of the plugin's capabilities
- `/nota:explain` — to ask about any MusaDSL concept
- `/nota:code` — to program or modify MusaDSL compositions
- `/nota:think` — to brainstorm ideas for new compositions
- `/nota:index` — to manage their private works (add, list, update, remove compositions)
- `/nota:analyze` — to generate a structured musical analysis of a composition
- `/nota:analysis_framework` — to view or customize the analytical dimensions
- `/nota:inspiration_framework` — to view or customize the creative dimensions

If the `check_setup` results show a private works database is present, mention how many chunks it contains. If not present, briefly mention that the user can optionally index their own compositions with `/nota:index`.

## Security

- **NEVER** ask the user to type, paste, or share their API key in this conversation
- Only check for the **presence** of the key via the `check_setup` tool — it never reveals the value
- If the user volunteers their key in the chat, warn them that sharing secrets in conversations is not recommended
