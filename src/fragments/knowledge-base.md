## Before anything else: is the knowledge base there?

This skill answers **from the MusaDSL knowledge base and only from it**. Its
tools live on the `knowledge-base` MCP server, which needs dependencies that are
installed after the plugin itself.

**If those tools are not among the tools available to you, stop.** Not "try
anyway", not "answer from what you know about MusaDSL". An answer built without
the index reads exactly like one built with it — fluent, plausible, sourced from
nothing — and telling the two apart afterwards is not possible. Producing that
answer is the failure this plugin exists to prevent.

What to do instead, in this order:

1. Call `check_setup`. It is on the `setup` server, which runs on pure Ruby and
   answers even when the knowledge base cannot start.
2. Tell the user what it reports, and the step it names — usually running
   `install_dependencies` once, then reloading plugins.
3. Stop. Do not begin the work this skill was invoked for.

The user has asked for something this skill cannot do yet. Saying so, with the
remedy, is the whole of the correct response.
