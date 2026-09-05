# Changelog

## 1.0.2 — 2026-09-05

**The plugin stopped asking the harness where the user's home directory is.**

Reported from a Windows 11 install, and read from its debug log:

```
[WARN]  Missing environment variables in plugin MCP config: HOME
[ERROR] Plugin MCP server error - mcp-config-invalid:
        MCP server knowledge-base invalid: Missing environment variables: HOME
```

The server never started, so the plugin arrived with its ten skills and none of
its twenty-two tools. `HOME` is not defined on Windows — the home directory is
`USERPROFILE` — and `targets/claude-code.yml` built two of its variables from
it. Claude Code rejects the whole server config when a `${VAR}` it references
has no value and no `:-default`. (Its documentation describes a softer
behaviour — a warning, with the literal `${VAR}` text passed through — which
would have created a folder named `${HOME}` instead. Both are failures, and the
config had no business referring to `HOME` in either case.)

### What changed

- `targets/claude-code.yml` and the opencode template no longer compute a home
  directory. They set only what the server cannot know: where the plugin was
  installed, and the key. `Config.user_dir` resolves `~/.config/nota` with
  Ruby's `Dir.home`, which knows `HOME`, `HOMEDRIVE`+`HOMEPATH` and
  `USERPROFILE`, on whichever platform it is running.
- `Config.env` reads a variable and returns nothing when the value still holds
  an unexpanded `${...}` — the harness's documented behaviour, in case a build
  ever takes it. The knowledge saying so used to live twice, in the two places
  already bitten by it (the API key check in `search.rb` and in
  `CheckSetupTool`); now it lives once and covers every variable.
- `VOYAGE_API_KEY` now carries an empty default (`${VOYAGE_API_KEY:-}`). Same
  rule, second victim: a fresh install has no key, so the server was being
  rejected before `check_setup` could say the key was missing — and `/nota:setup`,
  the skill written to fix exactly that, inspects a server that was never there.
- The SessionStart hook command quotes its path. A hook is a shell line, and a
  Windows plugin root holds both spaces and backslashes.
- `check_setup` reports the resolved user directory. When this fails again, the
  path actually used is on screen instead of inferred.
- `spec/invariants_spec.rb` fails if any target's `mcp_env` asks the harness for
  anything but `CLAUDE_PLUGIN_ROOT` and `VOYAGE_API_KEY`.

### And the knowledge base now opens on Windows

The first fix only got the server *launched*. What it then needed was the
`sqlite-vec` extension, and that could not be installed on Windows either — for
a reason that turned out to be a label rather than a limit.

Upstream builds a perfectly good Windows binary: `vec0.dll`, 289 KB,
`PE32+ executable (DLL) x86-64`, shipped in the release as
`sqlite-vec-0.1.9-loadable-windows-x86_64.tar.gz` and inside the gem. It is
published under the platform name **`x86_64-mingw32`**, which no Ruby on Windows
has ever reported — RubyInstaller says `x64-mingw32` before 3.1 and
`x64-mingw-ucrt` after. The same defect exists for Linux ARM64 (`arm64-linux`
published, `aarch64-linux` reported): asg017/sqlite-vec#248, open and unanswered
since 2025-11-04, with no upstream commits since 2026-05-18.

The consequence is worse than one missing gem: **while `sqlite-vec` was a
dependency, `bundle lock` could not add `x64-mingw-ucrt` at all**, and
`bundler/setup` refuses to run on a platform the lockfile does not name. One
mislabelled gem made the whole bundle unresolvable on Windows.

So the dependency moved from the packaging to the artifact. `sqlite-vec` is out
of the Gemfile; `mcp_server/vec_extension.rb` fetches the loadable from the same
GitHub Releases that already serve `knowledge.db`, with the same stdlib-only,
atomic, gracefully-degrading shape, and loads it by path — which is all the gem
ever did. It is pinned, because an index is written by one vec0 and read by
another, and cached at
`~/.config/nota/sqlite-vec/<release>/<os>-<cpu>/vec0.<ext>`. The SessionStart
hook fetches it once so the first question is not the one that pays; `search`
reports its absence as an answer instead of a stack trace; `check_setup` names
the resolved path.

The lockfile now carries eleven platforms instead of five — `x64-mingw-ucrt`
among them, and `aarch64-linux` and the musl variants as a side effect of the
same removal.

Two traps, both now held by `spec/`:

- **The cached file must be named `vec0`.** SQLite derives an extension's entry
  point from its basename, so a first attempt at `vec0-macos-aarch64.dylib` sent
  it looking for `sqlite3_vec0macosaarch64_init`. Release and platform belong to
  the directories.
- **`sqlite-vec` must not return to the Gemfile.** Nothing in such a diff would
  show that it takes Windows down with it.

### And the plugin installs its own gems

The third thing standing between a fresh machine and a working server, and the
one that had no excuse. `/plugin install` copies files; `ruby -r bundler/setup`
narrows the load path and installs nothing. So the server met
`Bundler::GemNotFound` and did not start — and since the server is what carries
`check_setup`, nothing left inside the session could say what was missing. The
plugin was already fetching a 27 MB index and a loadable extension without
asking, and leaving seven gems to a line in the README.

**The server installs them itself, before it loads them, so nothing has to be
restarted.** The MCP command is no longer `ruby -r bundler/setup server.rb` but
`ruby mcp_server/boot.rb`: Bundler as the first instruction is what killed the
process before any of our code could run. `boot.rb` uses stdlib alone, installs
what is missing, and only then requires Bundler and the server. `bundle check`
first — local, no network, so every session after the first pays almost nothing.
About five seconds and 16 MB, once, and everything it prints goes to stderr,
because stdout is the MCP transport from the first byte.

The SessionStart hook only reports, so there is one owner and no race. It is also
why opencode gets this: it has no session hook at all.

They install to `~/.config/nota/bundle`, not to the reader's GEM_HOME. A plugin
has no business mutating someone's Ruby for its own sake, a system Ruby would
need root and fail, and the user directory survives a plugin update while the
versioned cache does not. That path cannot travel through `.mcp.json` — the
harness cannot expand `${HOME}`, which is this release's other subject — but it
does not have to: the hook runs in a real Ruby, writes `.bundle/config` beside
the Gemfile with an absolute `BUNDLE_PATH`, and the server finds them with the
`BUNDLE_GEMFILE` it already had. No new variable.

`BUNDLE_WITHOUT: development` joins the server's environment. `bundler/setup`
demands every group named in the lockfile whether or not anything requires it,
so without it the reader was being asked for six gems that exist only for this
plugin's own examples and are never shipped.

When the install cannot happen — no network, a proxy — the server says why on
stderr and prints the command to run by hand; the README carries the same one.
One risk is not measured: the harness's own patience for a server that has not
answered `initialize` yet. Five seconds fits; a very slow connection might not,
and then that session has no server — which is what happened before any of this
existed, so it is a strict improvement and not a new way to fail.

**What keeps this out of a checkout is a coincidence of layout**, so it is
written down and asserted: an installed plugin has `Gemfile` and `mcp_server/`
as siblings, while the source tree has the Gemfile a level higher — `src/Gemfile`
does not exist. Moving it would let a hook repoint a developer's own bundle.

## 1.0.0 — 2026-08-05

**Nota stops carrying MusaDSL's knowledge and starts asking the framework for it.**

That is the whole of this release, and it is why the version has a 1 in front:
the architecture stopped moving. Everything else here follows from it.

### The principle

**musa-dsl owns the knowledge; Nota decides its distribution.** Knowledge in
prose lives where it can be falsified — musa-dsl has a suite, a doctest that
executes every claim its documentation makes, and a CI. A copy of that knowledge
here was outside all three, and every copy that ever lived here drifted from the
original. One of them turned a false claim into a rule with emphatic typography.

The guardrail in the other direction, so the framework does not end up carrying
prose whose only reader is a plugin: **a document moves into musa-dsl only if,
were Nota deleted tomorrow, it would still deserve to exist.**

### Gone from the plugin

- `rules/musadsl-reference.md` (35 KB of hand-maintained API reference)
- `rules/musadsl-philosophy.md`
- `rules/best-practices.md`
- `prompts/regenerate-*.md` — prompts that asked a model to re-read the sources
  and rewrite a summary. Their existence was the symptom: transcription made
  into a process.
- 19 of the 23 shipped "best practices". They described musa-dsl rather than a
  way of composing with it, and moved into musa-dsl's own documentation — the
  craft of laying out a project into `docs/guides/project-structure.md`, the
  plain facts into the subsystem guides. The four that remain are techniques,
  not framework facts.

**Always-in-context went from 47.7 KB copied to ~17 KB read from the gem.**

### New

- **Reads `docs/idioms.md` and `docs/vocabulary.md` from the installed
  musa-dsl** at session start, in both harnesses. No copy, no version floor: it
  asks whether the documents are where it expects them and says what it found,
  including which version. A gem that has one and not the other serves the one it
  has and names the other.
- **`get_doc` and `list_docs`** — read a whole document out of the installed gem.
  A `docs` snippet routes; the document decides. The boundary between two verbs
  lives in how a document relates its parts, not in the 2000 characters that most
  resembled a query.
- **`lint`** — reads composition code and reports what a reader can see. No API
  key, no database, no network, so it works when everything else is unreachable.
  Two lists kept apart: facts about the text, and shapes that are usually the
  generalist reflex and occasionally right. **The lint points; the agent judges.**
  It is the only step in the circuit that does not depend on remembering.
- **`spec/`** — the plugin has its own examples for the first time. Each one
  corresponds to something that went wrong and was found by hand.
- **`tools/retrieval-battery.rb`** — 32 questions asked by intention, each with
  the document that should answer it. Runs in CI and fails on regression.
- **`tools/contract-check.rb`** — asserts that every document the skills name
  exists in the installed musa-dsl. The plugin now depends on file names in
  another repository; that dependency is checked rather than assumed.

### Changed

- **`search` has no `all`.** It takes a list of `{kind, query}`, each embedded and
  ranked on its own, under its own heading, nothing merged. A caller that cannot
  say which layer it needs has not finished forming its question.
- **`api_reference` looks names up** — exact, then prefix, then, clearly labelled
  as something else, the nearest chunks. **It can say no.** The escalation the
  skills describe (knowledge base, then rubydoc, then source) can only happen if
  the first step is capable of returning nothing.
- **`similar_works` ranks each collection separately.** The user's own pieces used
  to be merged into the public demos' slots and printed under their heading.
- **Results carry their kind and distance**, and an empty result distinguishes
  "nothing near enough" from "this collection is empty" — the second is a broken
  index, not an answer.
- **The index is pruned.** Documents deleted upstream used to stay for ever and
  keep being quoted.
- **The chunker refuses to build** when a kind it expects produced nothing. It had
  been producing zero best practices for months because a path moved.
- The four reasoning skills were rewritten by substitution: route, read whole,
  cite. `code` gained a source column in its modelling table and a mandatory lint
  step, and is **smaller** than before.

### Removed

- `pattern` and `dependencies`. Their fixed quotas and embedded phrasings were
  the server doing the skill's work.

### Requires

**musa-dsl with `docs/idioms.md` and `docs/vocabulary.md`** — 0.49.1 or later.
Older gems get what they have, and are told what they lack.

### What this release does not know about itself

It was rebuilt on the idea that **reading a whole document decides better than
reading a fragment**. That is argued, not measured, and it costs roughly 10k
tokens each time a modelling gate fires. The retrieval battery measures that the
right document is *reachable*; nothing yet measures whether reading it *changes
the decision*. That instrument is the commissions protocol, and it needs
compositions with a known idiomatic solution written by a person — deferred to
2.0 rather than faked here, because a battery written by the assistant would
measure its own consistency with itself.
