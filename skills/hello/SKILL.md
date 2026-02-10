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

2. **Welcome the user** — introduce yourself as an algorithmic composition assistant powered by MusaDSL knowledge. Keep it warm but concise. Include the plugin version in the welcome by reading it from `{plugin_root}/.claude-plugin/plugin.json` (the plugin root is two levels up from this SKILL.md file). Show it like: "musa-claude-plugin v0.x.x".

3. **Explain the three layers** of the knowledge system:

   - **Static reference** — A condensed API reference always loaded in context, covering all MusaDSL subsystems (series, sequencer, neumas, scales, generative tools, transcription, transport, MIDI, etc.)

   - **Semantic search** — An MCP server with a vector database (sqlite-vec + Voyage AI embeddings) that retrieves relevant documentation, API details, and code examples on demand. This is what makes answers accurate and sourced.

   - **Works catalog** — Find similar compositions from the 23 demo projects, the user's own indexed private works, and their musical analyses.

4. **Explain the dual-database architecture:**

   - **`knowledge.db`** (public) — Contains the official MusaDSL documentation, API reference, 23 demo projects, and supporting gem docs. Automatically downloaded from GitHub Releases and periodically updated. The user doesn't need to maintain it.

   - **`private.db`** (local, optional) — A separate database for the user's own composition projects and their analyses, stored at `~/.config/musa-claude-plugin/private.db`. This location persists across plugin updates — private content is always safe.

   - Use `/index` to add your compositions to the private database, and `/analyze` to generate musical analyses.

5. **Explain the composition analysis capability:**

   The plugin can generate structured musical analyses of compositions. `/analyze` reads the actual source code, interprets it musically, and produces a detailed analysis covering multiple analytical dimensions. The analysis is then stored as searchable knowledge in `private.db`, enriching future searches.

   The analysis is guided by a configurable **analysis framework** with 9 default dimensions:
   - Formal Structure — sections, chaining, form, proportions
   - Harmonic and Modal Language — scales, modes, modulations
   - Rhythmic and Temporal Strategy — durations, polyrhythms, clock/transport
   - Generative Strategy — Markov, Variatio, Rules, Darwin, series operations
   - Texture and Instrumentation — voices, MIDI channels, density, dynamics
   - Idiomatic Usage and Special Features — creative uses of MusaDSL
   - Relation to Other Artists — connections to composers and traditions (with WebSearch)
   - Notable Technical Patterns — reusable idioms and representative fragments
   - Conclusion — key aspects recapitulation, aesthetic reading, closing statement

   The user can customize these dimensions with `/analysis_framework` — adding, removing, or modifying dimensions to fit their analytical interests.

6. **Explain the creative thinking capability:**

   `/think` helps generate ideas for new compositions or explore new directions for existing ones. It uses a configurable **inspiration framework** with 8 default creative dimensions:
   - Structure — horizontal/vertical organization, proportion, emergence vs. design
   - Time — pulse, polyrhythm, tempo, duration vocabulary, silence
   - Pitch — scales, intervals, register, microtonality, pitch series, clusters
   - Algorithm — Markov, L-systems, genetic algorithms, feedback, control vs. chance
   - Texture — density, layering, roles, dynamics, timbral evolution
   - Reference — musical traditions, composers, extra-musical ideas, live coding culture
   - Dialogue — contrast with similar and opposite composers to generate new directions (with WebSearch)
   - Constraint — creative limitation as catalyst (pitch, duration, resource, tool restrictions)

   Ideas are always grounded in MusaDSL — each suggestion maps to concrete tools and patterns. The inspiration framework is customizable with `/inspiration_framework`.

   The complete creative cycle: `/think` (generate ideas) -> `/code` (implement) -> `/index` (index the work) -> `/analyze` (analyze it) -> `/think` (new ideas from the analysis).

7. **List the available skills:**

   - `/explain` — Ask about any MusaDSL concept and get an accurate, sourced explanation. Examples: "explain series operations", "how does the sequencer work", "show me neumas syntax"
   - `/code` — Program or modify MusaDSL compositions. Translates musical intentions into working code with API-verified accuracy
   - `/think` — Generate ideas for compositions. Explores creative dimensions, connects to MusaDSL capabilities, uses WebSearch for external inspiration
   - `/index` — Manage your private works index (add, update, remove, list compositions)
   - `/analyze` — Generate a structured musical analysis of a composition, guided by an analysis framework with multiple analytical dimensions
   - `/analysis_framework` — View, customize, or reset the analytical dimensions used by `/analyze`
   - `/inspiration_framework` — View, customize, or reset the creative dimensions used by `/think`
   - `/setup` — Plugin configuration and troubleshooting (API key, knowledge base status)
   - `/hello` — This welcome and capabilities overview

8. **List the available MCP tools** (used automatically when answering questions):

   | Tool | What it does |
   |------|-------------|
   | `search` | Semantic search across all knowledge — docs, API, demos, private works, and analyses (kind: `"all"`, `"docs"`, `"api"`, `"demo_readme"`, `"demo_code"`, `"gem_readme"`, `"private_works"`, `"analysis"`) |
   | `api_reference` | Look up exact API reference by module and method name |
   | `similar_works` | Find demo projects, private works, and related analyses similar to a description |
   | `dependencies` | What setup is needed for a concept (gems, objects, config) |
   | `pattern` | Get a working code pattern for a specific composition technique |
   | `check_setup` | Check the status of the plugin configuration |
   | `list_works` | List all indexed private works with chunk counts |
   | `add_work` | Index a private composition work from a given path |
   | `remove_work` | Remove a private work from the index by name (also removes associated analysis) |
   | `index_status` | Show status of both knowledge databases (public and private) |
   | `get_analysis_framework` | Get the current analysis framework (default or user-customized) |
   | `save_analysis_framework` | Save a customized analysis framework |
   | `reset_analysis_framework` | Reset the analysis framework to default |
   | `add_analysis` | Store a composition analysis in the knowledge base |
   | `get_inspiration_framework` | Get the current inspiration framework (default or user-customized) |
   | `save_inspiration_framework` | Save a customized inspiration framework |
   | `reset_inspiration_framework` | Reset the inspiration framework to default |

## Important

- **Do NOT call `check_setup`** or any other MCP tool. This skill is purely informational — it presents the overview from the instructions above.
- If the user mentions configuration problems, API key issues, or the knowledge base not being found, redirect them to `/setup` instead.
