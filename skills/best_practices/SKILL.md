---
name: best_practices
description: >-
  Use this skill when the user wants to manage best practices for MusaDSL
  composition — generate from analyses, add manually, list, edit, remove,
  or regenerate the condensed index. Also "best practices", "buenas prácticas",
  "practices", "patterns".
version: 0.1.0
---

# MusaDSL Best Practices Management

Manage best practices for MusaDSL composition projects. Practices can be generated from composition analyses, added manually, listed, edited, removed, or condensed into a searchable index.

## Two layers

- **General practices** — ship with the plugin in `data/best-practices/`, indexed in `knowledge.db`. Searchable by all users via `search` with `kind: "best_practice"`.
- **User practices** — private, stored in `~/.config/nota/best-practices/`, indexed in `private.db`. Personal patterns extracted from analyses or added manually.

## Process

1. **Detect the user's language** from their message. If they write in Spanish, respond entirely in Spanish. If in English, respond in English. Match whatever language they use.

2. **Determine the operation** the user wants:
   - **Generate** — extract practices from analyses or the knowledge base
   - **Add** — manually create a new practice
   - **List** — show all practices and their status
   - **Edit** — modify an existing practice
   - **Remove** — delete a practice
   - **Regenerate index** — update the condensed summary of all practices

3. **Detect mode**:
   - If the user explicitly asks to work on **global/plugin practices** AND `data/best-practices/` exists in the plugin directory → **developer mode** (uses `scope: "global"`, writes to `data/best-practices/`)
   - Otherwise → **user mode** (uses `scope: "private"`, writes to `~/.config/nota/best-practices/`)

## Operations

### Generate from analyses (user mode)

1. Call `search` with `kind: "analysis"` and queries related to patterns, techniques, best practices, recurring structures
2. Read the user's analyses and identify recurring patterns, notable techniques, and reusable conventions
3. Propose consolidated practices to the user — for each: title, slug name, description, example code
4. Ask for approval before saving
5. For each approved practice: call `save_best_practice` with the full markdown content and `scope: "private"`
6. After saving all practices, regenerate the condensed index (see "Regenerate index" below)

### Generate from knowledge base (developer mode)

1. Call `search` with relevant queries across `docs`, `demo_code`, `api` kinds
2. Also read source docs and demo files directly from the filesystem for full context
3. Propose practices to the developer — title, slug name, description, example, optional anti-pattern
4. Ask for approval before saving
5. For each approved practice: call `save_best_practice` with `scope: "global"`
6. Remind to run `make build` to reindex the knowledge base

### Add manually

1. User describes the practice (what it does, why it matters)
2. Structure it into the standard format:
   - `# [Title]`
   - `## Description` — what to do and why, prescriptive and concise
   - `## Example` — working code example
   - `## Anti-pattern` — what NOT to do (optional)
3. Show the formatted practice for approval
4. Call `save_best_practice` with appropriate scope

### List

1. Call `list_best_practices` to show user practices with indexing status
2. Also call `get_best_practices_index` to show the condensed index if it exists
3. Present both in a clear format

### Edit

1. Read the existing practice file from the filesystem (`~/.config/nota/best-practices/{name}.md` for user, or `data/best-practices/{name}.md` for global)
2. User describes the changes they want
3. Apply changes, show the result for approval
4. Call `save_best_practice` (overwrites the existing practice)

### Remove

1. Ask for confirmation: "Are you sure you want to remove the practice '{name}'?"
2. Call `remove_best_practice` with the practice name
3. Regenerate the condensed index after removal

### Regenerate index (user mode)

1. Read all `.md` files from `~/.config/nota/best-practices/`
2. Distill into a condensed summary (~30-50 lines): one line per practice with title and essence
3. Call `save_best_practices_index` with the markdown content
4. Show the generated index to the user

### Regenerate condensed reference (developer mode)

1. Read all `.md` files from `data/best-practices/`
2. Distill into `rules/best-practices.md` (~30-50 lines): numbered list, imperative tone, one line per practice
3. Write the file to the filesystem
4. Show the generated reference

## Practice file format

Every practice file follows this structure:

```markdown
# [Practice Title]

## Description
[What to do and why — prescriptive, concise]

## Example
```ruby
[Working code example demonstrating the practice]
```

## Anti-pattern
```ruby
[What NOT to do — optional section]
```
```

## Guards

- **Always ask for confirmation** before saving or removing practices
- **In developer mode**, remind to run `make build` after changes to reindex
- **Never generate practices without reading actual source material** — always search or read files first
- **Verify examples against the knowledge base** — use `search` or `api_reference` to confirm API usage in examples is correct
- **Use slug-style names** for practice files: lowercase, hyphens, no spaces (e.g., "shutdown-pattern", "seed-reproducibility")

## Important

- User practices are stored as kind `"best_practice"` in `private.db`, searchable via `search` with `kind: "all"` or `"best_practice"`
- Global practices are in `knowledge.db`, also searchable as `"best_practice"`
- The condensed index (`~/.config/nota/private-best-practices.md`) is a quick-reference summary, not a replacement for the full practices
- `/nota:code` automatically searches best practices as part of its research step
- The `[consolidation candidate]` markers in `/nota:analyze` output signal patterns worth extracting as practices
