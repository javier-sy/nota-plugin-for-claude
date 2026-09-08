## Before anything else: is the knowledge base there?

This skill answers **from the MusaDSL knowledge base and only from it**. Its
tools live on the `knowledge-base` MCP server, which needs dependencies that are
installed after the plugin itself.

**If those tools are not among the tools available to you, stop.** Not "try
anyway", not "answer from what you know about MusaDSL". An answer built without
the index reads exactly like one built with it — fluent, plausible, sourced from
nothing — and telling the two apart afterwards is not possible. Producing that
answer is the failure this plugin exists to prevent.

What to do instead: call `check_setup` — it is on the `setup` server and answers
even when the knowledge base cannot start — then tell the user what is missing
and the one step that fixes it, and stop. Do not begin the work this skill was
invoked for.

**Say it in a few lines.** Everything above is the reason *you* must stop, and
none of it is the user's business. They asked about music and got an
installation notice instead; that is already an interruption, and explaining it
at length makes it a worse one. So: do not name which server owns which tool, do
not argue why an unsourced answer would be bad, do not describe how the plugin
is built. Report what is missing, name the step, offer to run
`install_dependencies` for them, and be done.
