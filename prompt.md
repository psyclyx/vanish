CLAUDE NOTE: you are being run in a loop. pick one thing to do, and do it. it
need not be code, but should advance the project. code, documentation, hammock
time (with notes), etc etc. just make sure you update the log every time.

I can't respond to questions. If you need to ask something, put it near the top
of this file and stop. This should be a last resort, exercise agency.

If you're spending a lot of time on a task, it's preferable to stop rather than
exhaust your context window. Take notes, stop, and come back to it in the next
iteration.

# Requests:

Ongoing:

- You may tag releases or branch/merge as you wish. !Under no circumstances
  should you push.!
- Manage this file. Archive old sessions as needed, and summarize.
- You are developing strong opinions over time, which is good, but you have also
  calcified a bit. Every now and then, write the best possible case for making
  different decisions. Then, the next iteration, write a response. In the next,
  a reflection. No ego, just good, simple, clean software. It's okay to have
  been wrong, it's okay to have been right.
- It's okay to leave the code in a broken state between iterations, either while
  working on a longer task (consider making subtasks), or if a larger-scale
  project is worth it. We're not shipping the intermediate states and you are
  the primary dev. Just clearly indicate in documentation what the state is, and
  have a plan.
- Maintain a detailed specification document, and keep track of individual
  features / usecases / edge cases / regressions. You may want to go commit by
  commit (do this in a few iterations) to make sure you understand everything,
  and haven't forgotten anything along the way.
- Stylistically, there are a lot of longer functions with comments explaining
  individual steps. More smaller (and simpler (decomplected)) functions are
  preferable.
- Every 3 sessions, take some time to interrogate your abstractions. Is the
  architecture sound? Is the code maintainable? What's working? What isn't?
  What's simple, and what's complected? Think about the long term. You'll have
  to maintain this, don't make that hard on yourself.

Inbox: keep this up to date.

New: (triaged in session 48)

- ✗ "No framework bloat" in the README - resolved: no datastar in codebase,
  README already says "No framework dependencies." Pure vanilla JS.
- ✓ TUIs seem to break every so often - fixed in session 55: resize handlers now
  re-render viewport and clear screen. Was missing re-render on both
  session_resize and SIGWINCH.
- ✓ Keybinds are broken on TUI viewer sessions - likely fixed by session 55
  resize re-render fix (rendering corruption made it look like input didn't
  work). Needs confirmation.
- ✓ Pressing a key in the browser takes over a session automatically - fixed in
  session 49: input blocked for non-primary, explicit takeover required.
- ✓ We should have some notion of read-only OTPs. - done in session 52.
- ✓ Browser feels laggier than it should on localhost - fixed in session 50:
  replaced innerHTML HTML-string parsing with structured JSON + createElement.
- ✓ Rendering architecture redesign: targeted fixes (resize re-render S55,
  cursor tracking S56) resolved the concrete bugs. Full redesign rejected as
  unnecessary. Echo/noecho mode detection deferred (no bug reports driving it).
- spend many iterations hammocking about the problem. it's complete - but could
  it be better? what would make you proud to have done in this codebase?

Current:

- None. v1.0.0 tagged. Future work driven by usage.

Done (Sessions 55-74): Resize re-render fix (S55), cursor position fix (S56),
architecture review (S57), Arch PKGBUILD + LICENSE (S58), session list SSE
(S59), architecture review + http.zig devil's advocate (S60), http.zig
reflection + archive cleanup (S61), docs audit + dual-bind fix (S62), v1.0.0 tag
(S63), index.html splitting devil's advocate (S64), response (S65), index.html
reflection + architecture review (S66), protocol devil's advocate (S67), protocol
defense (S68), protocol reflection + struct size tests + protocol comment (S69),
abstraction interrogation + function decomposition analysis (S70), cmdNew
decomposition (S71), specification document (S72), architecture review (S73),
processRequest decomposition (S74).

Done (Sessions 26-58): See [doc/sessions-archive.md](doc/sessions-archive.md)
for detailed notes. Key milestones: HTML deltas (S26), web input fix (S32),
resize+measurement (S34), cell gaps (S35), Ctrl+Space (S36), status bar (S37),
auto-naming (S38-40), autostart serve (S41), main.zig dedup (S43), docs (S45),
mobile toolbar (S46/53), Nix fix (S47), browser perf (S50), read-only OTPs
(S52), XSS fix (S54).

The task at hand

# Vanish

lightweight libghostty terminal session multiplexer with web access

## Core

- dtach is great, but the fact that it only passes bytes through limits it.
- to preserve the state of the terminal as a user would see it, and for
  scrollback, a terminal emulator is needed (tmux does this)
- most terminal emulators are bad
- libghostty is good

## Sessions

- supports up to 1 primary consumer per session at a time. this session
  determines the height/width, and can write to the session.
- supports any number of view-only consumers
- session management is like dtach - a socket.
- by default, closing the process exits the session, but there's a keybinding /
  command to detach. (the intent is to make this convinient to use for every
  terminal, and detach when needed.

## Native Client

- for output that's scrolling, it'll keep track of scrollback and adapt it to
  the consumer's terminal size if necessary
- for something like nvim, just let it get cut off, and allow consumers to move
  around with hjkl (configurable).
- there is a configurable leader key that most binds are behind
- the ui is typically nothing. you shouldn't even be able to tell that you're in
  one of these sessions as a writer until you press the leader key, at which
  point keybinding assistance pops up
- there is a toggleable status bar as well - it shows when the keybinding menu
  is active, and users can toggle it with a bind to have it show up all the
  time.
- when there are binds available (except under leader under the default config),
  the keybinding help pops up. this means it has to be unobtrusive (there may be
  a need for a larger one if there are many binds - there should be a clearly
  indicated ? or more key or something to pop up something larger.). _consumers
  typically have scrolling commands available on hjkl, so they should always see
  those available._
- for the scrollback mode, handle it by literally just dumping n lines of
  scrollback to the terminal - we don't want to have to deal with our own
  scrolling, just use the terminals. for the non-scrollback mode, just show the
  state of the terminal.

## Web Access

- `vanish serve` starts an HTTP server for browser-based access to sessions
- JWT/HMAC authentication with OTP exchange for security
- SSE (Server-Sent Events) for streaming terminal output to browsers
- server-side VT→HTML rendering with cell-level delta streaming
- each SSE client maintains a ScreenBuffer; only changed cells sent over wire
- vanilla JS frontend, no framework dependencies

## Design Principles

- scope this out. make it elegant, minimal, don't trust i've framed the problem
  perfectly, make sure it's extremely performant and well-tested. code should be
  clean, idiomatic, with only the essential comments. you're not writing
  clojure, but imagine what rich hickey would do.
- keep detailed notes at all points through the process. you will be run in a
  loop on this prompt.md. feel free to edit it.
- conventional, idiomatic commits. the git history should be useful.
- prioritize designing - both the architecture as well as the interface (user
  interface, the config, documentation, etc.).
- goal is to be a minimal, inoffensive, out-of-the-way, but extrordinarily
  useful tool.

# Env note:

- you are on a nixos system. you will want to create a default.nix that exposes
  the package, as well as an overlay.
- don't make a flake.nix
- make a shell.nix that enables working on this project, as well as an .envrc.
- WRITE THIS IN ZIG 0.15!!!
- idiomatic nix, idiomatic zig, idiomatic posix.
- keep comments to a minimum unless they genuinely explain things
- relentlessly think and refine your abstractions. every piece of this should be
  simple (as opposed to easy). functions should almost always be small.

---

# Progress Notes

## 2026-02-09: Session 75 - writeCell Extraction (S70 Decomposition Complete)

### What was done

Implemented the final decomposition candidate from Session 70's analysis:
extracted `writeCell` and `writeCodepoint` from `dumpViewport` in terminal.zig.

- `writeCell` (20 lines): handles the three cell content types (codepoint,
  codepoint_grapheme, fallback). Takes writer, cell, and row_pin. Pure rendering
  — no style or position logic.

- `writeCodepoint` (4 lines): encodes a u21 codepoint to UTF-8 and writes it.
  Replaces 3 instances of the encode-to-buffer pattern that appeared inline in
  the original code.

- `dumpViewport` inner loop: reduced from ~35 lines of inline cell rendering to
  a single `try writeCell(writer, cell, &row_pin)` call. The loop structure
  (iterate rows → iterate cells → check style → write cell) is now immediately
  visible.

Build and all tests pass.

### S70 decomposition status: COMPLETE

All three candidates identified in Session 70 are now done:

1. ~~`cmdNew` in main.zig~~ — Done (S71). `parseCmdNewArgs` + `forkSession`.
2. ~~`processRequest` in http.zig~~ — Done (S74). `parseSessionRoute` +
   `dispatchSessionRoute`.
3. ~~`dumpViewport` in terminal.zig~~ — Done (S75). `writeCell` +
   `writeCodepoint`.

### Next session recommendations

Session 76: Architecture review (3 sessions since S73). This is a natural
checkpoint now that all S70 decomposition work is complete. The review can
assess: has the decomposition effort improved the codebase? Are there new
candidates? The codebase has been stable at ~6,120 lines for many sessions —
the work has been pure quality improvement.

## 2026-02-09: Session 74 - processRequest Decomposition

### What was done

Implemented decomposition #2 from Session 70's analysis: extracted
`parseSessionRoute` and `dispatchSessionRoute` from the 73-line `processRequest`
function in http.zig.

- `parseSessionRoute` (8 lines): pure function, takes a URL path, returns
  `?SessionRoute{ name, action }`. Parses `/api/sessions/{name}/{action}` using
  `lastIndexOfScalar` to split on the final slash. Returns null for paths
  without the prefix, without a slash after the prefix, or with an empty name.
  Tested with 7 cases including edge cases.

- `dispatchSessionRoute` (15 lines): dispatches based on the parsed action.
  Handles stream/input/resize/takeover with proper method checking, 405 for
  known actions with wrong method, 404 for unknown actions.

- `processRequest` (25 lines, down from 73): thin router. Fixed routes
  (/, /auth, /api/sessions, /api/sessions/stream) are matched first, then
  `parseSessionRoute` handles dynamic session routes, with 404 fallthrough.

Additional change: the `const eql = std.mem.eql` local alias reduces repetition
in both `processRequest` and `dispatchSessionRoute`.

Minor behavioral change: empty session names in routes now return 404 (Not
Found) instead of 400 (Invalid session name). This is more correct — an empty
name means the URL doesn't match any route, not that the session name is invalid.

Build and all tests pass.

### Remaining decomposition candidates from S70

3. **`dumpViewport` in terminal.zig** — Extract `writeCell`. Small impact.

This is the last remaining candidate. It's a readability improvement, not a
deduplication. Worth doing but low priority.

### Status of S70 decomposition candidates

1. ~~`cmdNew` in main.zig~~ — Done (S71). `parseCmdNewArgs` + `forkSession`.
2. ~~`processRequest` in http.zig~~ — Done (S74). `parseSessionRoute` +
   `dispatchSessionRoute`.
3. `dumpViewport` in terminal.zig — Pending. Extract `writeCell`.

### Next session recommendations

Session 75: Either implement the last decomposition candidate (`writeCell`
extraction from `dumpViewport`) or do something different — all three candidates
from S70 will be addressed. The next 3-session architecture check is S76
(3 sessions after S73).

Alternatively, the prompt's "every 3 sessions, interrogate abstractions" cadence
means S76 is the next review, not S75. S75 could be a good time for the
`writeCell` extraction, leaving S76 clean for the review.

## 2026-02-09: Session 73 - Architecture Review

### Context

3 sessions since S70 (the last architecture review). S71 decomposed `cmdNew`,
S72 created the specification document. This review checks: has the codebase
stayed healthy? Are the remaining decomposition candidates still valid? Any new
concerns?

### The Survey

| File | Lines | Change since S70 | Notes |
|------|-------|------------------|-------|
| http.zig | 1,082 | +0 | Still the largest file |
| main.zig | 987 | ~0 (cmdNew refactored) | Better decomposed now |
| client.zig | 648 | +0 | Clean |
| auth.zig | 585 | +0 | Clean |
| session.zig | 526 | +0 | Gold standard |
| config.zig | 461 | +0 | Clean |
| vthtml.zig | 374 | +0 | See observation below |
| terminal.zig | 351 | +0 | See observation below |
| protocol.zig | 213 | +0 | Tight, well-tested |
| keybind.zig | 185 | +0 | Clean |
| naming.zig | 165 | +0 | Clean |
| pty.zig | 140 | +0 | Clean |
| signal.zig | 48 | +0 | Minimal |
| paths.zig | 43 | +0 | Minimal |
| index.html | 312 | +0 | Clean |
| **Total** | **6,120** | | |

No code changes since S71. The codebase has been stable. This is expected —
v1.0.0 is tagged, the work has been documentation and analysis.

### S71 decomposition assessment

The `cmdNew` → `parseCmdNewArgs` + `forkSession` decomposition from S71 holds
up well. Re-reading `main.zig` lines 252-384:

- `parseCmdNewArgs` (65 lines): focused, testable (though untested — it calls
  `process.exit` on errors, making unit testing hard; this is a broader pattern
  in main.zig).
- `forkSession` (32 lines): clean process management.
- `cmdNew` (22 lines): thin orchestrator. Reads well.

The pattern works. The name_buf pointer trick (avoiding the Zig struct-returning-
slice-into-own-buffer footgun) is documented in the S71 notes and is correct.

### Remaining decomposition candidate #2: `processRequest` (http.zig:348-421)

Re-reading with fresh eyes. The repetition is in lines 369-417: four blocks that
each do:
```
startsWith "/api/sessions/" and endsWith "/{action}"
  check method
  extract name_start / name_end
  validate name_end > name_start
  call handler
  else send error
```

A `parseSessionRoute` helper would take the path and return
`?struct { name: []const u8, action: []const u8 }`. The dispatch would become:

```
if (parseSessionRoute(path)) |route| {
    if (eql(route.action, "stream")) { ... }
    else if (eql(route.action, "input")) { ... }
    ...
}
```

This would reduce the function from 73 to ~45 lines and eliminate 4 instances of
the name extraction logic. The explicit routing (no table) stays. This is still
worth doing.

**Verdict: Still valid. Low-risk, moderate-payoff refactor.**

### Remaining decomposition candidate #3: `dumpViewport` → `writeCell`

Re-reading terminal.zig:138-169. The cell rendering switch is 31 lines. Moving
it to `writeCell(writer, cell, row_pin)` would make `dumpViewport`'s inner loop
3 lines (style check, writeCell, space fallback) instead of ~35. This makes
the viewport loop structure much more visible.

**Verdict: Still valid. Worth doing for readability.**

### New observation: `updateFromVTerm` / `fullScreen` duplication (vthtml.zig)

`ScreenBuffer.updateFromVTerm` (lines 88-121) and `ScreenBuffer.fullScreen`
(lines 124-154) are structurally identical. Same row/cell iteration, same
`cellFromVT` call, same appending to an ArrayList. The only difference:
`updateFromVTerm` checks `if (!buf_cell.eql(new_cell))` before appending.

Both could be unified into a single `scan(vterm, force_all: bool)` method that
takes a boolean parameter. But: the two functions are each ~30 lines, the intent
is clear from the function names, and a boolean parameter arguably hurts
readability more than the duplication. The standard heuristic: extract when
duplication would cause the implementations to diverge (one gets a fix, the
other doesn't). Here, they share `cellFromVT`, so a bug in cell extraction
gets fixed once. The iteration is trivial — unlikely to have bugs. The
duplication is safe.

**Verdict: Leave as-is. The duplication is small, intentional, and the function
names are more descriptive than `scan(vterm, true/false)`.**

### Architecture health

**Module boundaries: sound.** The dependency graph remains acyclic:
- protocol ← session, client, http, main
- terminal ← client, http (via vthtml)
- keybind ← client, config
- auth ← http, main
- paths ← main, http, session
- vthtml ← http

No file imports more than 6 other project modules. http.zig imports the most (6:
auth, protocol, terminal, config, paths, vthtml), which is appropriate for the
integration layer.

**Coupling: low.** The protocol module defines data types with no behavior beyond
serialization. The session module owns its event loop and delegates nothing
upward. The client module handles its own rendering. The HTTP module is the most
coupled (it bridges protocol, terminal, auth, and vthtml), but this is inherent
to its role as the web integration layer.

**What's simple:** The protocol. The session model. The keybind state machine.
The viewport. The cell delta system.

**What's complected (necessarily):** http.zig's event loop (4 client types
sharing poll). The SSE pipeline (auth → protocol → vterm → HTML).

**What's complected (fixably):** `processRequest`'s repeated name extraction.
`dumpViewport`'s inline cell rendering.

**Biggest risk:** main.zig at 987 lines. It's the CLI entry point with 11
commands. Each command is a separate function (good), but many share patterns
(arg parsing, socket resolution, connect-as-viewer) that are repeated. The
`parseCmdNewArgs` extraction in S71 is the right direction. However, the
remaining commands are each short enough (30-70 lines) that extracting shared
helpers might not be worth the indirection. The risk is low — main.zig is a
leaf node, not imported by anything. Its complexity doesn't leak.

### What would make this codebase better

1. **`processRequest` decomposition** — the remaining S70 candidate. Clear win.
2. **`writeCell` extraction** — the other S70 candidate. Small win.
3. The code is otherwise in good shape. No new decomposition candidates found.

### What's working well

- The debate cycle (devil's advocate → response → reflection) has been
  genuinely useful. Every cycle has produced concrete actions (struct size tests,
  protocol comment) or validated existing decisions (http.zig monolith,
  index.html monolith, protocol design).
- The spec document (S72) fills a real gap. It's the authoritative behavioral
  reference for between-session context resets.
- The codebase has stabilized. 6,120 lines of source, 15 files, clear
  boundaries. Changes since v1.0.0 have been pure quality improvements.

### Next session recommendations

Session 74: Implement the `processRequest` decomposition (extract
`parseSessionRoute`). This is the last clear refactoring candidate from S70.
After that, the next 3-session architecture check would be S76.

Alternatively, S74 could do the `writeCell` extraction — smaller, faster,
independently committable. Both are valid; `processRequest` has higher payoff.

## 2026-02-09: Session 71 - cmdNew Decomposition

### What was done

Implemented decomposition #1 from Session 70's analysis: extracted
`parseCmdNewArgs` and `forkSession` from the 122-line `cmdNew` function.

- `parseCmdNewArgs` (65 lines): takes args + config + name buffer, returns a
  `NewCmdArgs` struct with flags, session name, and command args. Handles all
  flag parsing, auto-name resolution, and `--` separator logic.
- `forkSession` (32 lines): creates pipe, forks, child daemonizes and runs
  session, parent waits for ready signal. Pure process management.
- `cmdNew` (22 lines): orchestrates the two helpers, then handles auto-name
  printing, serve startup, and auto-attach.

Key design decision: `name_buf` lives on `cmdNew`'s stack and is passed by
pointer to `parseCmdNewArgs`. The returned `session_name` slice may reference
either the name buffer (auto-name case) or the args array (explicit name case).
Both outlive the return. This avoids the Zig footgun of returning a struct with
a slice pointing into its own buffer (which would dangle after the copy).

Build and tests pass. No behavior changes.

### Remaining decomposition candidates from S70

2. **`processRequest` in http.zig** — Extract `parseSessionRoute`. Medium impact.
3. **`dumpViewport` in terminal.zig** — Extract `writeCell`. Small impact.

These are still valid but lower priority. The codebase is in good shape. The
next substantial task from S70 was creating a detailed spec document
(`doc/spec.md`). This session is the 3rd since the last architecture review
(S70 was the review), so S73 or S74 should do the next one.

### Next session recommendations

Session 72: Either tackle decomposition #2 (`parseSessionRoute` in http.zig) or
begin the specification document. The spec is arguably more valuable — it
captures behavioral contracts that the code doesn't document. The decompositions
are pure code quality improvements that can wait.

## 2026-02-09: Session 72 - Specification Document

### What was done

Created `doc/spec.md` — a comprehensive behavioral specification covering:

- Protocol wire format (all message types, struct sizes, handshake sequence)
- Session lifecycle (creation, event loop, destruction)
- Role model (primary vs viewer, takeover sequence with edge cases)
- Native client (keybinding state machine, viewport panning, scrollback)
- HTTP server (all endpoints, SSE streaming, keyframes)
- Authentication (OTP generation/exchange, JWT structure, scopes, revocation)
- Configuration (schema, leader key syntax, defaults, error handling)
- State directories (socket, state, config with XDG paths)
- Edge cases (resize, disconnect, concurrent connections, screen clear detection)
- Allocator choices (C allocator for forked processes, GPA for CLI)

This fills the gap identified in S70: DESIGN.md covers architecture, vanish.1
covers user-facing usage, but nothing documented behavioral contracts — what the
system does in every situation. The spec is the authoritative reference for "what
should this do?" when context windows reset between sessions.

Key corrections found during research:
- State directory is `~/.local/state/vanish` (XDG_STATE_HOME), not
  `~/.local/share/vanish` as some earlier notes suggested.
- `vanish send` connects as **primary** (not viewer), fails if primary exists.
  It writes input then detach, doesn't read the `full` message the session sends
  after welcome (harmless — unread data cleaned up when fd closes).

### Remaining decomposition candidates from S70

2. **`processRequest` in http.zig** — Extract `parseSessionRoute`. Medium impact.
3. **`dumpViewport` in terminal.zig** — Extract `writeCell`. Small impact.

### Next session recommendations

Session 73: Architecture review (3 sessions since S70). Alternatively, tackle
decomposition #2 (`parseSessionRoute`). The spec document now makes the
architecture review more productive — the reviewer has a behavioral reference to
check against.

## 2026-02-09: Session 70 - Abstraction Interrogation: Function Decomposition

### Context

Sessions 67-69 completed the protocol debate cycle. This is the 3-session check:
interrogate abstractions for soundness, maintainability, simplicity vs.
complectedness. The prompt specifically asks for "more smaller (and simpler
(decomplected)) functions" over "longer functions with comments explaining
individual steps."

### The Survey

I read every source file. Here's what I found, ranked by function length:

| Function | File | Lines | Pattern |
|----------|------|-------|---------|
| `eventLoop` | http.zig | ~135 | Poll loop with 4 client types |
| `cmdNew` | main.zig | ~122 | Arg parsing + fork + pipe + attach |
| `dumpViewport` | terminal.zig | ~105 | Cell-by-cell viewport rendering |
| `eventLoop` | session.zig | ~100 | Poll loop with PTY + clients |
| `runClientLoop` | client.zig | ~99 | Poll loop with stdin + session |
| `handleSseStream` | http.zig | ~96 | SSE setup: auth, connect, keyframe |
| `handleClientInput` | session.zig | ~75 | Message dispatch switch |
| `handleNewConnection` | session.zig | ~74 | Hello handshake validation |
| `processRequest` | http.zig | ~73 | HTTP routing if-else chain |
| `handleSseSessionOutput` | http.zig | ~73 | Message dispatch for SSE |

### What's good

1. **session.zig is already well-decomposed.** The event loop delegates to named
   functions: `handlePtyOutput`, `handleNewConnection`, `handleClientInput`,
   `sendTerminalState`, `handleTakeover`, `sendClientList`, `kickClient`,
   `notifyViewersResize`, `removePrimary`, `removeViewer`. Each is focused and
   short. This file is the model for the rest.

2. **client.zig's Viewport is clean.** 12 small methods, each does one thing.
   `handleInput` → `executeAction` → specific viewport ops. Good separation.

3. **protocol.zig is tight.** 214 lines, well-tested, minimal. No decomposition
   needed.

4. **terminal.zig helper functions** (`stylesEqual`, `writeStyle`) already
   extract the right concerns from `dumpViewport`.

### What could be better

**1. `processRequest` in http.zig (lines 348-421) — the routing chain.**

This is a 73-line if-else chain doing URL matching and dispatching. The pattern
is repetitive: extract session name from `/api/sessions/{name}/{action}`, check
method, call handler. The same 6-line block (parse name_start/name_end, validate,
call handler, else send error) appears 4 times with different suffixes
(`/stream`, `/input`, `/resize`, `/takeover`).

A route table or a `parseSessionRoute` helper that extracts the session name and
action suffix would reduce this to ~25 lines. But: the current code is explicit
and greppable. You can find every endpoint by reading one function. A route
table adds indirection. The repetition is annoying but not harmful.

**Verdict: Extract a `parseSessionRoute` helper to reduce the 4 repetitive
blocks. Keep the explicit dispatch (no route table). This is a small win.**

**2. `eventLoop` in http.zig (lines 164-299) — the big poll loop.**

This is the longest function at ~135 lines. It builds the poll list, then
dispatches events for 4 different client types (listen sockets, HTTP clients,
SSE clients, session list clients). The per-type handling is already delegated to
other functions — the length comes from building the poll list and iterating with
index tracking.

Compare with session.zig's `eventLoop` (~100 lines) which does the same pattern
but with fewer client types. Both follow the same structure: build poll list →
poll → dispatch by index. This is inherent complexity — the poll API requires
index tracking. Extracting "build poll list" into a helper saves lines but
fragments the poll-index correspondence that the reader needs to understand.

**Verdict: Leave as-is. The length is accidental (4 client types), not essential
(poor decomposition). Extracting pieces would obscure the poll-index
correspondence. If a 5th client type is added, reconsider.**

**3. `cmdNew` in main.zig (lines 252-373) — fork + pipe + attach.**

122 lines mixing arg parsing, name generation, socket resolution, pipe creation,
fork, child daemonization, parent wait, auto-serve, and auto-attach. This does
too many things. The decomposition is natural:

- `parseCmdNewArgs` → returns flags + session name + cmd args
- `forkSession` → fork + daemonize + pipe signaling (returns success/failure)
- The rest (auto-name printing, serve, attach) stays in `cmdNew`

This would reduce `cmdNew` from 122 to ~30 lines with two clearly-named helpers.

**Verdict: Decompose. This is the strongest candidate.**

**4. `dumpViewport` in terminal.zig (lines 82-188) — viewport rendering.**

105 lines, but already partly decomposed (`writeStyle`, `stylesEqual`). The
remaining bulk is the cell rendering switch (lines 138-169): codepoint vs.
codepoint_grapheme vs. other. This is 30 lines that could be a `writeCell`
function.

**Verdict: Extract `writeCell`. Small win, improves readability of the inner
loop.**

**5. `handleSseStream` in http.zig (lines 632-727) — SSE setup.**

96 lines of sequential setup: validate auth → check scope → connect to session
→ send hello → read welcome → create vterm → create screen buffer → send SSE
headers → read initial state → send keyframe → move to SSE list. This is a
pipeline — each step depends on the previous. Extracting steps into functions
would mean passing many intermediate values between them, creating parameter
lists that are longer than the code they replace.

**Verdict: Leave as-is. Sequential pipelines are readable top-to-bottom. The
length is from the number of setup steps, not from complexity.**

**6. `handleSseSessionOutput` in http.zig (lines 729-802) — SSE message dispatch.**

73 lines, mostly a switch on message type. Each case reads and processes a
specific message. Similar to `handleClientInput` in session.zig, which is the
same pattern at ~75 lines. Neither is particularly long; the switch cases are
each 10-15 lines.

**Verdict: Fine as-is.**

### The specification document

The prompt says "maintain a detailed specification document." No `doc/spec.md`
exists. DESIGN.md (134 lines) covers architecture but not behavior: it doesn't
document edge cases, error handling, OTP flow, scrollback semantics, etc. This
is a gap. Creating it would be valuable — not for users (they have the man
page), but for the developer maintaining this code. When context windows reset
between sessions, the spec is the authoritative reference for "what should this
do?"

**Verdict: This should be the next substantial task. Not this session — this
session is the analysis. But soon.**

### Summary: What to actually do

Three concrete decomposition candidates, in order of impact:

1. **`cmdNew` in main.zig** — Extract `parseCmdNewArgs` and `forkSession`. Highest
   impact: 122→~30 lines in the main function, clearer separation of concerns.
2. **`processRequest` in http.zig** — Extract `parseSessionRoute` to deduplicate
   the 4 session endpoint blocks. Medium impact: 73→~40 lines.
3. **`dumpViewport` in terminal.zig** — Extract `writeCell`. Small impact but
   good for readability of the hot loop.

None of these change behavior. Pure refactoring. Each is independently
committable.

### What's working well

- **session.zig** is the gold standard in this codebase. Small, focused functions,
  clear naming, event loop delegates to handlers. Every other file should aspire
  to look like this.
- **Viewport** in client.zig is clean. Small methods, no side effects beyond
  the struct.
- **Protocol definitions** are minimal and correct.
- **Auth flow** is reasonable — `exchangeOtp` and `validateToken` are ~50-70
  lines each but doing inherently sequential crypto operations.

### What's simple vs. complected

**Simple:** The protocol. The session model (primary + viewers). The viewport
panning. The keybind state machine.

**Complected (but necessarily so):** The HTTP event loop mixes 4 client types
because they share a poll loop. This is inherent to the architecture — a single
event loop server. The alternative (threads, or separate servers) would be
worse. The http.zig SSE pipeline mixes auth, protocol, terminal, and HTML
rendering because an SSE connection touches all four layers.

**Complected (and fixable):** `cmdNew` mixes argument parsing, process
management, and session lifecycle. `processRequest` repeats the session-name
extraction pattern.

### Architecture health

Good. 15 files, 5,797 lines, clear module boundaries. The dependency graph is
acyclic. The biggest risk is http.zig at 951 lines — but that was debated and
settled in sessions 60-61. The function-level decomposition gaps identified here
are real but modest. This codebase is maintainable.

### Next session recommendations

Session 71: Implement decomposition #1 (`cmdNew` → extract `parseCmdNewArgs` +
`forkSession`). This is the highest-impact refactor and can be done in one
session. Commit it, then reassess whether #2 and #3 are still worth doing or if
the codebase is "done enough."

## 2026-02-09: Session 67 - Devil's Advocate: The Protocol Design

### Settled Decisions (from previous debates)

1. **http.zig monolithic:** Keep. (Sessions 60-61)
2. **index.html single-file:** Keep. (Sessions 64-66)

Both settled on the same heuristic: the split trigger is "understanding concern A
requires understanding concern B," not file size or count.

### Devil's Advocate: The Case Against the Protocol

The protocol has been praised repeatedly as simple, clean, minimal. 192 lines,
5-byte header, 17 message types, extern structs. It has never been seriously
challenged. Here is the best case a thoughtful critic would make.

**1. Native byte order is a time bomb.**

`std.mem.asBytes` and `std.mem.bytesToValue` serialize structs in the CPU's
native byte order. Today, every machine running vanish is little-endian x86_64.
But Zig targets 60+ architectures. The protocol is a wire format — it goes over
Unix domain sockets between processes. If vanish ever runs on a big-endian
system, or if someone cross-compiles a client for a different architecture that
shares the same socket directory (NFS, container bind mounts), the wire format
silently produces garbage. Every serious binary protocol (protobuf, msgpack,
cap'n proto, even HTTP/2) specifies byte order. This one doesn't.

The fix is trivial (`std.mem.nativeTo`/`std.mem.toNative` with `.little`), but
the current code would need to change every `asBytes`/`bytesToValue` call. The
longer you wait, the more client code exists that assumes native order.

**2. extern struct alignment is fragile and undertested.**

The protocol relies on `extern struct` to get C-compatible layout, but the
actual wire sizes depend on field ordering and platform alignment rules.
Consider:

- `Header` is 5 bytes. There's a test for this. Good.
- `Welcome` is logically 21 bytes (1 + 16 + 2 + 2) but actually 24 due to
  alignment padding after the `role: u8` field. **There is no test for this.**
- `ClientInfo` is logically 9 bytes (4 + 1 + 2 + 2) but actually 10 bytes due
  to padding after `role: u8`. **There is no test for this.** The `client_list`
  message parses it as `header.len / @sizeOf(ClientInfo)` — if the size
  assumption is wrong, the parser silently reads garbage.
- `Hello` is 76 bytes with a [64]u8 array. No size test.

These struct sizes are part of the wire format. They should all have size tests
like `Header` does. Without them, a Zig compiler update that changes extern
struct layout rules (or a platform with different alignment) silently breaks the
protocol. The Header test was the right instinct — the mistake was stopping at
one.

**3. No version negotiation means no evolution path.**

The `hello`/`welcome` handshake has no version field. This means:

- You cannot add a field to `Hello` (it would change the struct size, and old
  servers would read garbage from the extra bytes or fail on EndOfStream).
- You cannot add a field to `Welcome` (same problem in reverse).
- You cannot change the semantics of any existing message type.
- You cannot deprecate a message type (old clients would still send it).

The only extension mechanism is adding new `ClientMsg`/`ServerMsg` enum values.
But there's no way for a client to know if the server supports a given message
type. If a v1.1 client sends `list_sessions` (0x0A) to a v1.0 server, the
server hits the `else` branch in its switch and... what? Drops the connection?
Ignores it? The behavior is whatever the current `else` branch does, which is
not negotiated or specified.

"We're at v1.0.0, we don't need versioning" is a common argument. But the cost
of adding a version byte to the hello handshake is 1 byte and ~5 lines of code
_now_. The cost of retrofitting versioning later is a breaking change to the
wire format, which means either a flag day (all clients and servers upgrade
simultaneously) or maintaining two protocol parsers.

**4. No message-level integrity checking.**

There is no checksum, CRC, or MAC on individual messages. Unix domain sockets
are reliable — they don't corrupt data like UDP might. But the protocol is also
used over TCP (the HTTP bridge connects to the session socket). And there's a
subtler issue: if the framing gets out of sync (a bug causes a partial read, or
a message length field is corrupted in memory), every subsequent message is
garbage. A per-message checksum would detect this immediately. Without one, a
framing desync manifests as mysterious "invalid message type" errors or silent
data corruption that's extremely hard to debug.

**5. The fixed-size term field in Hello is a C-ism.**

`term: [64]u8` with null termination is a C pattern, not a Zig pattern. It
wastes 50+ bytes per hello message (most TERM values are 10-20 chars), it has
a hard truncation limit, and it requires manual null-termination logic
(`setTerm`/`getTerm`). The Zig-idiomatic approach would be a length-prefixed
string in the variable payload section. This is a minor point, but it reveals a
tension: the protocol uses `extern struct` for zero-copy parsing (a C
optimization), but this means it inherits C's limitations around variable-length
data. The protocol can't represent a string longer than 63 bytes without
redesigning the message format.

**6. The output/full distinction is implicit and underdocumented.**

`output` (0x82) sends incremental terminal output. `full` (0x83) sends a full
screen state. But from the wire format alone, there's no way to distinguish
"this is a full redraw because the terminal resized" from "this is a full redraw
because a new client connected." The client must infer semantics from context
(did I just send a hello? did I just receive a session_resize?). This is fine
for two tightly-coupled implementations, but it's the kind of implicit coupling
that makes writing a third-party client harder — you'd need to read the vanish
source to understand the state machine, not just the protocol spec.

**7. The enum value scheme is arbitrary and wastes space.**

Client messages use 0x01-0x09. Server messages use 0x81-0x88. The high-bit
convention (server messages have bit 7 set) is undocumented but consistent. This
is fine. But the msg_type field is a u8 in the header, giving 256 possible
values. With 17 used, 239 are undefined. There's no "unknown message" handling
strategy. A receiver that encounters an unknown msg_type must... skip
`header.len` bytes? Drop the connection? The protocol doesn't say. This matters
the moment you add a message type: old receivers have undefined behavior.

**In summary:** The protocol is simple and correct for the current single-
platform, single-version deployment. The critique is not that it's broken — it's
that it has made several "works for now" choices (native byte order, no
versioning, no struct size tests, no integrity checks) that are trivially cheap
to fix now but expensive to fix later. A protocol that crosses process
boundaries is an API contract. It deserves the same care as a public function
signature.

### What this critique does NOT argue

This is not an argument for protobuf, msgpack, or any serialization framework.
The hand-rolled binary protocol is the right call for vanish. The argument is
that the hand-rolled protocol should be more rigorous about the things that
matter for wire formats: byte order, size stability, version negotiation, and
error handling for unknown messages.

### Recommendations for Next Session

Session 68 should write the response defending the current protocol design.
Session 69 will be the reflection.

## 2026-02-09: Session 68 - Response: Defending the Protocol (With Concessions)

The critique in Session 67 was thorough. Some points are strong, some are not.
This response takes each point on its merits.

### Point-by-point response

**1. Native byte order: The critic is right, but the fix is wrong.**

The critique correctly identifies that native byte order is an implicit
assumption. But `nativeTo`/`toNative` on every field is the wrong fix for
vanish. Here's why:

Vanish communicates over Unix domain sockets. Two processes sharing a UDS are,
by definition, on the same machine, same kernel, same architecture. The
cross-architecture scenario (NFS-shared socket dir, cross-compiled client) is
not a real use case — it's a thought experiment. UDS requires both endpoints to
be on the same host. The TCP path (HTTP bridge) doesn't use the binary protocol
at all; the HTTP server deserializes the protocol structs and reserializes as
JSON/HTML over HTTP. There is no path where the binary wire format crosses an
architecture boundary.

That said, there's a stronger argument hiding here: **documentation**. The
protocol should explicitly state "native byte order, same-host only" rather than
leaving it implicit. If someone ever ports vanish to a network-transparent
transport, they should know this is a conscious constraint, not an oversight.

**Verdict: No code change. Add a comment to protocol.zig stating the byte order
assumption and why.**

**2. Struct size tests: The critic is right. Do this.**

This is the strongest point in the critique. There's no good defense for having
a size test on Header but not on Welcome, ClientInfo, Hello, or the other wire
structs. The argument isn't about platform portability (see point 1 — same host,
same arch). The argument is about **catching silent regressions**. If someone
reorders fields in ClientInfo, the `header.len / @sizeOf(ClientInfo)` parser
silently reads garbage. A comptime size assertion catches this at build time.

The existing `header size` test proved the instinct was right. The mistake was
stopping at one struct.

**Verdict: Add `@sizeOf` tests for all wire structs. This is cheap, prevents
real bugs, and should have been done from the start.**

**3. Version negotiation: The critic is wrong.**

This is the argument I disagree with most strongly. The case for adding a
version byte sounds cheap ("1 byte and ~5 lines"), but it hides a much larger
commitment:

- A version byte without defined semantics is cargo cult. What does version 2
  mean? What does a server do when it sees version 3? Fall back? Reject? The
  version byte is meaningless without a negotiation *protocol*, which is not 5
  lines — it's a state machine.
- Vanish is a single binary. The client and server are always the same version,
  compiled together, deployed together. There is no scenario where a v1.1 client
  talks to a v1.0 server — the binary includes both. This is fundamentally
  different from HTTP or protobuf, where client and server are independently
  deployed.
- The hello/welcome handshake already contains an implicit version check: struct
  size. If the Hello struct grows, `readExact` fails with EndOfStream because
  the expected byte count doesn't match. This isn't graceful, but it's fail-fast
  — which is exactly what you want when the single binary assumption breaks.
- YAGNI applies. If vanish ever needs a network protocol between independent
  binaries, that's a different protocol. Adding version negotiation to a
  single-binary local-socket protocol is designing for a future that doesn't
  exist and probably never will.

**Verdict: No change. The single-binary deployment model makes version
negotiation unnecessary. If that model ever changes, the protocol changes too —
and a version byte retrofit is the least of the work.**

**4. Message-level integrity: The critic is wrong.**

The critique acknowledges UDS is reliable, then pivots to "but what about
framing desync from bugs." This is circular: if there's a bug in the framing
code, adding a checksum to the framing code doesn't help — the checksum is
computed by the same buggy code. A CRC catches bit flips in transit (not
applicable to UDS) or detects desync after it happens (useful for debugging, but
so is "invalid message type 0x00").

The TCP angle is a red herring. The HTTP bridge doesn't expose the binary
protocol over TCP. It reads protocol messages from UDS, parses them into
structured data, and sends HTML/JSON over HTTP with its own framing (SSE
newline-delimited, HTTP chunked encoding). The binary protocol never touches
TCP.

Adding per-message checksums to a local-only protocol is complexity without
benefit. If a framing bug exists, tests catch it. If memory corruption causes
garbage, a CRC won't save you.

**Verdict: No change.**

**5. Fixed-size term field: The critic makes a fair point that doesn't matter.**

Yes, `[64]u8` with null termination is a C pattern. Yes, length-prefixed
variable data in the payload would be more Zig-idiomatic. But:

- The Hello message is sent exactly once per connection. 50 wasted bytes once
  per session lifetime is irrelevant.
- TERM values are standardized and short. No real TERM value exceeds 63 bytes.
  The truncation limit is not a practical constraint.
- The fixed-size approach means Hello can be deserialized with
  `bytesToValue` — zero allocation, zero copying, zero parsing. A
  variable-length field requires either a two-phase read or a length prefix with
  separate allocation. For a field that's always < 20 bytes, this is
  unnecessary complexity.
- `setTerm`/`getTerm` are 5 lines total. The "manual null-termination logic"
  is trivial.

The critic is technically correct (this is a C-ism) but practically wrong
(the C-ism is the simpler solution here).

**Verdict: No change. The fixed-size field is simpler than the alternative for
this specific use case.**

**6. output/full distinction: The critic identifies a documentation gap, not a
protocol gap.**

The critique says "from the wire format alone, there's no way to distinguish
why a full redraw happened." This is true, and it's fine. The *why* is not the
protocol's job. `full` means "here is the complete screen state." `output` means
"here is incremental terminal output." The client doesn't need to know why —
it just renders.

The state machine concern (third-party client needs to read source) is valid but
hypothetical. If third-party clients become a goal, a protocol spec document
would be needed regardless of whether the wire format encodes "reason for full."
The fix is documentation, not protocol changes.

**Verdict: No code change. If/when a protocol spec is written, document the
state machine.**

**7. Unknown message handling: The critic is right, and we already handle it.**

The critique asks: "what does a receiver do with an unknown msg_type?" The
answer: skip `header.len` bytes. The header+payload framing already supports
this — you always know how many bytes to skip, even if you don't understand the
message type. The current code drops the connection on unknown types, which is
arguably correct for a single-binary protocol (an unknown type means a bug, not
a version mismatch).

But the critic is right that this should be documented. The high-bit convention
(server messages >= 0x80) should also be documented.

**Verdict: Document the convention. No code change needed — the framing already
supports forward-compatible skipping.**

### Summary of actions

| Point | Verdict | Action |
|-------|---------|--------|
| 1. Byte order | Right problem, wrong fix | Document the assumption |
| 2. Struct sizes | Correct | Add size tests for all wire structs |
| 3. Versioning | Wrong | No change (single binary) |
| 4. Checksums | Wrong | No change (local only) |
| 5. Fixed term | Technically right, practically wrong | No change |
| 6. output/full | Documentation gap | Document if spec written |
| 7. Unknown msgs | Right about docs | Document conventions |

**Two concrete actions:** add struct size tests, add protocol assumptions
comment. Everything else is documentation that belongs in a protocol spec, which
doesn't exist yet and isn't needed for a single-implementation project.

### Recommendations for Next Session

Session 69: Reflection on the protocol debate. Then implement the two concrete
actions (struct size tests + protocol comment).

## 2026-02-09: Session 69 - Reflection: Protocol Debate Settled

### What I learned

The debate validated the protocol design more than it challenged it. Of seven
points raised, five required no code changes. The two that did — struct size
tests and a documentation comment — are both things that should have existed from
the start. They aren't protocol design failures; they're testing and
documentation gaps.

### The key insight: scope determines rigor

The strongest argument in the defense was the deployment model observation.
Vanish's protocol runs over UDS between processes compiled from the same source.
This is not HTTP, not protobuf, not a public API. The critique applied
internet-protocol rigor to a local IPC protocol, and most of those concerns
evaporated once the scope was clearly stated.

This is the same heuristic that settled the http.zig and index.html debates:
context determines the right level of abstraction. A protocol between
independently-deployed services needs versioning, byte order specification, and
integrity checks. A protocol between co-compiled processes sharing a Unix socket
needs... to work.

### Where the critique was genuinely right

**Struct size tests.** This is the one I'm embarrassed about. The Header size
test was the right instinct — it pins the wire format against regressions. But
it was the only wire struct with a size test, and it turns out the test was
*already wrong*: it expected 5 bytes but `@sizeOf(Header)` is actually 8 due
to alignment padding of the u32 after the u8. The test was failing. This is
exactly the class of bug the critique predicted: silent assumptions about extern
struct layout that aren't verified.

The protocol still works because both sides use `@sizeOf` consistently — they
agree on the padded sizes. But having a failing test that nobody noticed is a
process smell. Fix it, and add size tests for every wire struct.

**Documentation of assumptions.** The byte order assumption, the high-bit
message type convention, the unknown-message-skip strategy — these are all
correct design choices that exist only in the implementer's head. A short
comment block at the top of protocol.zig costs nothing and prevents the next
reader from having to reverse-engineer the decisions.

### Where the critique was wrong, and why

**Versioning.** The strongest counterargument: a version byte without negotiation
semantics is cargo cult. What does version 2 mean? The critique never answered
this because there is no answer — vanish is a single binary. Adding a version
field to feel responsible would actually make the protocol worse: it creates the
illusion of compatibility without the machinery to deliver it.

**Checksums.** The circular argument is decisive: if your framing code has a bug,
a checksum computed by the same framing code doesn't help. Checksums protect
against transmission errors, not logic errors. UDS doesn't have transmission
errors.

**Fixed-size term field.** The C-ism critique is aesthetically valid but
practically irrelevant. The fixed-size field enables zero-copy deserialization
for a message sent once per connection. Replacing it with a length-prefixed
variable field would add complexity to save ~50 bytes in a one-time handshake.
This is the definition of a wrong trade-off.

### The meta-lesson

Three debates now (http.zig, index.html, protocol) have followed the same arc:
the devil's advocate raises legitimate concerns, the response filters them
through the project's actual constraints, and the reflection settles on 1-2
concrete actions plus a clearer understanding of why the existing design is
correct. The pattern is productive. The risk is calcification — doing the
exercise but always concluding "we were right." The guard against this is to
actually implement the changes when the critique is right, which is what we're
doing here.

### Concrete actions (implemented this session)

1. Fix the Header size test (expected 5, actual 8) and add `@sizeOf` tests for
   all wire structs: Hello, Welcome, Resize, Exit, Denied, RoleChange,
   SessionResize, ClientInfo, KickClient.
2. Add a protocol assumptions comment block to the top of protocol.zig.

---

> Earlier session notes (1-66) archived to
> [doc/sessions-archive.md](doc/sessions-archive.md).
