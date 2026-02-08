---
name: index
description: >-
  Use this skill when the user wants to index compositions, manage their private
  knowledge base, list indexed works, add or remove works from the index,
  update the index for a composition, or check indexing status.
version: 0.1.0
---

# Manage Private Works Index

Guide the user through managing their private composition index — adding, listing, updating, and removing works from `private.db`.

## Process

1. **Detect the user's language** from their message. If they write in Spanish, respond entirely in Spanish. If in English, respond in English. Match whatever language they use.

2. **Determine the operation** the user wants. Match their intent to one of the operations below.

3. **Resolve the plugin directory.** This SKILL.md file is located at `skills/index/SKILL.md` inside the plugin. The indexer script is at `mcp_server/indexer.rb` relative to the plugin root. Compute the absolute path:
   ```
   PLUGIN_DIR = <absolute path two levels up from this SKILL.md>
   INDEXER = "ruby #{PLUGIN_DIR}/mcp_server/indexer.rb"
   ```

4. **Validate prerequisites** before any operation that requires Voyage AI embeddings (add, scan, update). Check that the `VOYAGE_API_KEY` environment variable is set:
   ```bash
   echo $VOYAGE_API_KEY
   ```
   If empty or unset, tell the user that a Voyage AI API key is required for indexing and redirect them to `/musa-claude-plugin:setup`.

5. **Execute the operation** and present results clearly.

## Operations

### List indexed works

When the user asks what's indexed, what works they have, or wants to see the list.

```bash
ruby PLUGIN_DIR/mcp_server/indexer.rb --list-works
```

Show the output to the user. If no works are indexed yet, suggest adding some.

### Add a single work

When the user provides a path to a composition project.

```bash
ruby PLUGIN_DIR/mcp_server/indexer.rb --add-work /path/to/composition
```

After success, mention that the work now appears in `search` (kind: `"all"` or `"private_works"`) and `similar_works` results.

### Scan a directory

When the user wants to index all compositions in a directory.

```bash
ruby PLUGIN_DIR/mcp_server/indexer.rb --scan /path/to/works
```

After success, suggest running `--list-works` to verify what was indexed.

### Update a work

When the user has modified a composition and wants to re-index it. The indexer's upsert handles files that haven't changed, but if files were renamed or deleted, orphan chunks remain. The safest approach is remove + add:

```bash
ruby PLUGIN_DIR/mcp_server/indexer.rb --remove-work WORK_NAME
ruby PLUGIN_DIR/mcp_server/indexer.rb --add-work /path/to/composition
```

The WORK_NAME is the basename of the composition directory (as shown by `--list-works`).

### Remove a work

When the user wants to remove a composition from the index. **Ask for confirmation before executing.**

```bash
ruby PLUGIN_DIR/mcp_server/indexer.rb --remove-work WORK_NAME
```

### Move or rename a work

When the user moved a project to a different location or renamed the directory:

- If only the parent path changed (same directory name): just re-add from the new path — source labels use the basename, so they'll match.
- If the directory name changed: remove the old name, then add from the new path.

```bash
ruby PLUGIN_DIR/mcp_server/indexer.rb --remove-work OLD_NAME
ruby PLUGIN_DIR/mcp_server/indexer.rb --add-work /new/path/to/composition
```

### Check status

When the user wants to know the overall state of their databases.

```bash
ruby PLUGIN_DIR/mcp_server/indexer.rb --status
```

## What gets indexed

The indexer looks for these inside each composition project directory:

- **`musa/`** subdirectory — all `.rb` files (Ruby code using MusaDSL)
- **`README.md`** — project description and notes

Projects that have neither are skipped.

## Important

- **Do NOT search the knowledge base** — this skill manages the index, it doesn't query it. For searching, the user should ask questions normally and the MCP tools will handle it.
- **Ask for confirmation** before removing works.
- If the user asks about plugin configuration or API key issues, redirect to `/musa-claude-plugin:setup`.
