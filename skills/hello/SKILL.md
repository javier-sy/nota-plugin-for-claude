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

3. **Explain what the plugin does** — briefly:

   The plugin provides 9 interactive skills covering the entire creative process — from understanding the framework, through brainstorming ideas, to writing verified code and analyzing the results.

   Everything is backed by a knowledge base with MusaDSL documentation, API reference, and 23 demo projects. Optionally, the user can index their own compositions and their musical analyses, which enriches all skills.

4. **Present the 5 core skills** — explain each one briefly, in this order:

   **`/explain`** — Semantic search. Ask about any MusaDSL concept and get an accurate, sourced answer. Retrieves relevant documentation, API details, and code examples from the knowledge base.

   **`/think`** — Creative thinking. Generates ideas for new compositions or explores new directions for existing ones, drawing from:
   - The **inspiration framework** — 8 configurable creative dimensions: Structure, Time, Pitch, Algorithm, Texture, Reference, Dialogue, and Constraint
   - The user's **previous analyses** — to detect patterns in their practice and suggest unexplored directions
   - **MusaDSL knowledge** — to ensure every idea maps to concrete, implementable tools and patterns
   - **WebSearch** — to connect ideas to composers, techniques, and traditions

   Customize the dimensions with `/inspiration_framework`.

   **`/code`** — Composition coding. Translates musical intentions into working MusaDSL Ruby code. Can create new compositions from scratch or modify existing ones, drawing from:
   - **MusaDSL knowledge** — API reference, documentation, patterns, and demo examples to verify every method call
   - **Similar works** — from both the public demos and the user's own indexed compositions
   - The user's **existing code** — reading from the filesystem to understand and extend it

   The user describes their musical intention ("more intense", "like a canon", "more chaotic") and `/code` translates it into concrete technical approaches.

   **`/index`** — Works indexing. Indexes the user's composition projects so Claude can reference them. Once indexed, works appear in search results and inform all other skills. Use `/index` to add, update, remove, and list compositions.

   **`/analyze`** — Musical analysis. Reads the code, interprets it musically, and produces a detailed structured analysis across 9 configurable dimensions: Formal Structure, Harmonic and Modal Language, Rhythmic and Temporal Strategy, Generative Strategy, Texture and Instrumentation, Idiomatic Usage and Special Features, Relation to Other Artists, Notable Technical Patterns, and Conclusion. The analysis is stored as searchable knowledge that enriches future `/think` ideation and `/code` references.

   Customize the dimensions with `/analysis_framework`.

5. **Explain the complete creative cycle:**

   The plugin supports a continuous creative cycle where each step feeds into the next:

   ```
   /think ──→ /code ──→ /index ──→ /analyze ──╮
     ↑                                          │
     ╰──────────────────────────────────────────╯
   ```

   - **`/think`** (ideation) — generates ideas drawing from the inspiration framework, MusaDSL knowledge, and the user's previous analyses and works. The more the user has composed and analyzed, the richer the ideation becomes.
   - **`/code`** (composition) — implements ideas as working MusaDSL code, verified against the knowledge base and informed by similar works.
   - **`/index`** (knowledge building) — stores the composition's code, making it searchable and available for future reference by all other skills.
   - **`/analyze`** (reflection) — reads the code, interprets it musically, and stores the analysis as searchable knowledge.
   - Back to **`/think`** — the new analysis enriches future ideation: patterns detected across works, unexplored directions, dialogue with composers.

   The two databases are the memory of this cycle:
   - **`knowledge.db`** holds MusaDSL knowledge (what is possible)
   - **`private.db`** holds the user's creative practice (what has been done, and what it means)

   The cycle is not mandatory — the user can enter at any point and use any skill independently. But each step enriches the others.

6. **Mention the other skills:**

   | Skill | Purpose |
   |-------|---------|
   | `/hello` | This welcome and capabilities overview |
   | `/setup` | Plugin configuration and troubleshooting |
   | `/analysis_framework` | View, customize, or reset the analysis dimensions |
   | `/inspiration_framework` | View, customize, or reset the creative dimensions |

## Important

- **Do NOT call `check_setup`** or any other MCP tool. This skill is purely informational — it presents the overview from the instructions above.
- If the user mentions configuration problems, API key issues, or the knowledge base not being found, redirect them to `/setup` instead.
