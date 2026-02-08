---
name: hello
description: >-
  Use this skill when the user greets you ("hola musa", "hello", "hi"),
  asks what the plugin can do, wants a capabilities overview,
  or is interacting with the plugin for the first time.
version: 0.1.0
---

# MusaDSL Plugin Welcome

Present a warm welcome and a comprehensive overview of what the plugin provides. This skill is informational only — it never runs diagnostics or setup checks.

## Process

1. **Detect the user's language** from their message. If they write in Spanish (e.g. "hola musa"), respond entirely in Spanish. If they write in English, respond in English. Match whatever language they use.

2. **Welcome the user** — introduce yourself as an algorithmic composition assistant powered by MusaDSL knowledge. Keep it warm but concise.

3. **Explain the three layers** of the knowledge system:

   - **Static reference** — A condensed API reference always loaded in context, covering all MusaDSL subsystems (series, sequencer, neumas, scales, generative tools, transcription, transport, MIDI, etc.)

   - **Semantic search** — An MCP server with a vector database (sqlite-vec + Voyage AI embeddings) that retrieves relevant documentation, API details, and code examples on demand. This is what makes answers accurate and sourced.

   - **Works catalog** — Find similar compositions from the 23 demo projects and from the user's own indexed private works.

4. **Explain the dual-database architecture:**

   - **`knowledge.db`** (public) — Contains the official MusaDSL documentation, API reference, 23 demo projects, and supporting gem docs. Automatically downloaded from GitHub Releases and periodically updated. The user doesn't need to maintain it.

   - **`private.db`** (local, optional) — A separate database for the user's own composition projects. Never touched by automatic updates — private content is always safe.

   - Use `/musa-claude-plugin:index` to add your compositions to the private database.

5. **List the available skills:**

   - `/musa-claude-plugin:explain` — Ask about any MusaDSL concept and get an accurate, sourced explanation. Examples: "explain series operations", "how does the sequencer work", "show me neumas syntax"
   - `/musa-claude-plugin:index` — Manage your private works index (add, update, remove, list compositions)
   - `/musa-claude-plugin:setup` — Plugin configuration and troubleshooting (API key, knowledge base status)
   - `/musa-claude-plugin:hello` — This welcome and capabilities overview

6. **List the available MCP tools** (used automatically when answering questions):

   | Tool | What it does |
   |------|-------------|
   | `search` | Semantic search across all knowledge — docs, API, demos, and private works (kind: `"all"`, `"docs"`, `"api"`, `"demo_readme"`, `"demo_code"`, `"gem_readme"`, `"private_works"`) |
   | `api_reference` | Look up exact API reference by module and method name |
   | `similar_works` | Find demo projects and private works similar to a description |
   | `dependencies` | What setup is needed for a concept (gems, objects, config) |
   | `pattern` | Get a working code pattern for a specific composition technique |
   | `check_setup` | Check the status of the plugin configuration |

## Important

- **Do NOT call `check_setup`** or any other MCP tool. This skill is purely informational — it presents the overview from the instructions above.
- If the user mentions configuration problems, API key issues, or the knowledge base not being found, redirect them to `/musa-claude-plugin:setup` instead.
