---
name: inspiration_framework
description: >-
  Use this skill when the user wants to view, modify, or reset the inspiration
  framework that guides creative ideation dimensions.
version: 0.1.0
---

# Manage Inspiration Framework

View, customize, or reset the inspiration framework that defines the creative dimensions used by `/think`.

## Process

1. **Detect the user's language** from their message. If they write in Spanish, respond entirely in Spanish. If in English, respond in English. Match whatever language they use.

2. **Determine the operation** the user wants. Match their intent to one of the operations below.

3. **Execute the operation** by calling the appropriate MCP tool and present results clearly.

## Operations

### View current framework

When the user asks to see the current framework, what dimensions are explored, or how ideation is structured.

Call the `get_inspiration_framework` MCP tool (no parameters).

Display the framework content and indicate whether it is the **default** or a **user-customized** version.

### Modify the framework

When the user wants to add, remove, or change creative dimensions.

1. Call `get_inspiration_framework` to get the current content
2. Apply the user's requested changes:
   - **Add a dimension**: add a new `##` section with the dimension title and provocations/questions
   - **Remove a dimension**: remove the corresponding `##` section
   - **Modify a dimension**: edit the content of the corresponding `##` section
   - **Reorder dimensions**: rearrange the `##` sections
3. **Show the modified framework** to the user for review before saving
4. After the user approves, call `save_inspiration_framework` with the full modified content

**Always show the changes and ask for confirmation before saving.**

### Reset to default

When the user wants to go back to the default framework.

1. **Ask for confirmation** — explain that this will remove their customizations
2. After confirmation, call `reset_inspiration_framework`

## Important

- The framework is a markdown file with `##` sections. Each section title names a creative dimension; the section body provides provocations and questions to guide ideation.
- The default framework has 9 dimensions: Structure, Time, Pitch, Algorithm, Texture, Instrumentation, Reference, Dialogue, Constraint.
- The tone is provocative — questions ("What if...?"), possibilities, explorations — not instructions or checklists.
- User customizations are stored at `~/.config/nota/inspiration-framework.md`.
- Changes to the framework affect future `/think` sessions but do not retroactively change anything (ideation is ephemeral).
- The inspiration framework is independent from the analysis framework (`/analysis_framework`). They serve different purposes and evolve separately.
- **Do NOT call `get_inspiration_framework` for informational purposes** — only call it when the user is actively working with the framework (viewing, modifying, or resetting).
