---
name: analyze
description: >-
  Use this skill when the user wants to analyze a composition in depth,
  generate a musical analysis of a work, or create analytical notes for a piece.
version: 0.1.0
---

# Analyze a Composition

Generate a structured musical analysis of a composition project, guided by the analysis framework. The analysis interprets the code musically and stores the result as searchable knowledge.

## Process

1. **Detect the user's language** from their message. If they write in Spanish, respond entirely in Spanish. If in English, respond in English. Match whatever language they use.

2. **Identify the work** to analyze. The user may provide:
   - A path to the composition project directory
   - A work name (as shown by `list_works`)
   - A reference to the current project or working directory

   If unclear, ask the user to clarify which work they want to analyze.

3. **Read the analysis framework** by calling the `get_analysis_framework` MCP tool. This returns the framework content with `##` sections — each section is one analytical dimension to cover.

4. **Read the source code** directly from the filesystem. Read all `.rb` and `.md` files in the project directory recursively, **excluding** files under `vendor/`, `.bundle/`, `bw/`, `Live/`, and `render/` directories. Use the Read tool to read each file. This is essential — never generate an analysis without reading the actual code.

5. **Verify MusaDSL API usage** against the knowledge base. `api_reference`
   looks a name up and can say no; a name it does not have is not a name you may
   describe from memory. Do not assume — verify.

6. **Judge the idiom, do not just describe it.** For the *Idiomatic Usage*
   dimension, read `docs/idioms.md` whole with `get_doc("idioms")`. Asking for it
   by name is legitimate here and nowhere else in this plugin: it is not a
   candidate solution you might be confirming, it is **the rubric** — the task is
   literally to hold the code against the catalogue.

   Then ask `docs` about the shapes the code exhibits, phrased as shapes and not
   as the verbs you found. The difference is the whole dimension: an analysis that
   says *"uses `every`"* has described the code, while one that says *"uses
   `every` where the conceptual layer says a serie, and here is what that costs"*
   has judged it. Cite `document > section` for each judgement.

7. **Generate the analysis** following each `##` dimension from the framework:
   - Write a `##` section for each dimension
   - Ground every observation in the actual code — cite specific files, line numbers, or code fragments
   - Be specific: name the scales, series operations, generative tools, and patterns actually used
   - For the **"Relation to Other Artists"** dimension: **you MUST use WebSearch** to find relevant composers, techniques, and movements. Cite your sources. Do not rely solely on training data.
   - Adapt the depth of each dimension to what is actually present in the code — if a dimension is not relevant (e.g., no generative tools used), say so briefly rather than forcing content
   - For the "Coding Best Practices" dimension (or equivalent): before marking
     anything **[consolidation candidate]**, check it twice — `best_practice`, in
     case it already exists, and `docs`, in case it is simply the framework being
     used correctly. **If the framework documents it, it is not the composer's
     practice**, and recording it as one fills a private library with the manual
     rewritten in the first person. What survives both checks is a pattern that is
     genuinely theirs, and `{{cmd:best-practices}}` can formalise it

8. **Present the analysis** to the user for review. Show the full analysis text.

9. **Iterate if requested**. If the user wants changes, corrections, or additions, modify the analysis accordingly and present again.

10. **Store the analysis** when the user approves:

   a. **Save to filesystem** — write the analysis as a markdown file in the root of the composition project directory, named `analysis YYYY-MM-DD-HHMM.md` (using the current date and time). This creates a permanent, readable record alongside the code.

   b. **Index in knowledge base** — call the `add_analysis` MCP tool with:
      - `work_name`: the basename of the composition directory (same format as `list_works`)
      - `analysis_text`: the full analysis in markdown format

   **Always ask for explicit approval before storing.** Do not save or index automatically.

## Guards

- **Never generate an analysis without reading the actual source code.** The analysis must be grounded in real code, not assumptions.
- **Always verify MusaDSL API usage** against the knowledge base when encountering unfamiliar patterns.
- **WebSearch is mandatory** for the "Relation to Other Artists" dimension (or equivalent if the framework has been customized).
- **Always ask for approval** before calling `add_analysis` to store the result.
- If the work has not been indexed yet (not in `list_works`), suggest running `{{cmd:index}}` first to add the work's code to the searchable index, then proceed with the analysis.

## Important

- The analysis is stored as kind `"analysis"` in `private.db`, separate from the work's code chunks (kind `"private_works"`).
- If an analysis already exists for the work, `add_analysis` will replace it automatically.
- Removing a work with `remove_work` also removes its associated analysis.
- The stored analysis becomes searchable via `search` with `kind: "analysis"`, and appears in `similar_works` under its own heading — never merged with the public demos.
