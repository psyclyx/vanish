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

- ✓ Web viewer `e.preventDefault()` called before primary check — fixed in S97:
  moved preventDefault after the `!isPrimary` guard. Browser keyboard scrolling
  (PageUp, arrow keys, Space) now works for viewers.
- ✓ Web viewer silently drops keys with no feedback — fixed in S97: added
  showViewerHint() overlay ("Viewer mode — click Takeover to interact") that
  appears for 2 seconds when a viewer presses input keys. Matches native
  client's flashViewerHint behavior.
- ✓ Web session list doesn't indicate stale sessions — fixed in S97: stale
  sessions (live === false) are now filtered out of the session list.
- ✓ The top line of a terminal on vanish new -a zsh is a line from the output of a
  previous command still. Fixed in S93: alternate screen buffer (`\x1b[?1049h`)
  on attach gives a clean canvas; leaving it on detach restores parent content.
- ✓ are we properly clearing/setting cursor on attach? Fixed in S93: alternate
  screen buffer handles cursor positioning implicitly (starts at 1,1).
- fullscreen apps in smaller viewer sessions require the primary to force a
  redraw before it pans. S94 analysis: likely not a real bug — `sendTerminalState`
  should provide correct content on viewer connect. Needs testing to confirm.
- ✓ can we draw a fringe on edges that can be panned? Resolved S94/S95: decided
  against viewport fringes (steal screen space, fight with content). Status bar
  already shows offset and session dimensions. Direct viewer navigation (S95)
  makes panning discoverable through natural interaction.
- ✓ flashing the indicator when pressing keys in viewer mode from the tui would be
  helpful. Fixed in S95: viewers now get direct hjkl/u/d/g/G navigation without
  leader key. Unmapped keys show a brief "viewer | ^At takeover" hint.
- ✓ env vars don't seem to be getting copied over to the child process?
  investigated S91: env inheritance via std.c.environ works correctly after fork.
  The actual gap was vanish-specific env vars (see next item).
- ✓ we should also probably set an env var for the session name, as well as the
  socket — done in S91: VANISH_SESSION and VANISH_SOCKET set via setenv() before
  PTY child spawn.
- ✓ joining a session from itself... breaks things and spins up fans. Fixed in
  S92: `isSelfSession` checks VANISH_SOCKET and VANISH_SESSION env vars before
  connecting. Exits with "Cannot attach to own session".

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

Done (Sessions 91-102): Env vars + architecture review (S91), self-join
protection (S92), alternate screen buffer fix (S93), architecture review +
viewer UX hammock (S94), viewer direct navigation (S95), web viewer hammock
(S96), architecture review + web viewer fixes (S97), archive cleanup (S98),
hammock: case against our decisions (S99), response to challenges (S100),
reflection on challenge/response cycle (S101), implement accepted refactors +
tests (S102).

Done (Sessions 1-90): See [doc/sessions-archive.md](doc/sessions-archive.md).
Key milestones: HTML deltas (S26), web input fix (S32), cell gaps (S35), status
bar (S37), auto-naming (S38-40), docs (S45), browser perf (S50), read-only OTPs
(S52), resize fix (S55), PKGBUILD+LICENSE (S58), v1.0.0 tag (S63), protocol
debate + struct tests (S67-69), function decomposition (S70-75), UX hammock
(S77), socket clobbering fix (S78), session model debate (S80-82), completions
(S83-84), otp --url (S85), spec audit + bug fixes (S86-87), shell wrappers
(S90).

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

## 2026-02-09: Session 102 - Implement Accepted Refactors + Tests

### What was done

Implemented the three accepted items from the S99-S101 challenge/response/
reflection cycle.

**1. Viewport.applyScroll + executeAction collapse.**

Added `applyScroll(action)` to the Viewport struct — a 12-line method that
dispatches a keybind.Action to the corresponding scroll method. Collapsed the
8 identical scroll branches in `executeAction` (24 lines) into one branch (4
lines). Net: -21 lines in the function, +14 in Viewport = -7 overall. The
viewport is the right owner for this dispatch since it owns all scroll methods.

**2. Recovery section in spec.**

Added a "Recovery" subsection under Edge Cases → Disconnect in `doc/spec.md`.
Documents the explicit contract: session state is not persisted, crashes lose
the session, stale sockets are cleaned up automatically. Two paragraphs. This
was the spec gap identified in S99/S100.

**3. Tests for viewerNav, parseCmdNewArgs, and applyScroll.**

Added 8 new test cases across 2 files:

- `client.zig`: 4 tests — `viewport applyScroll` (movement + boundary),
  `viewerNav basic mappings` (8 key→action pairs), `viewerNav ctrl mappings`
  (Ctrl+U, Ctrl+D), `viewerNav unmapped keys return null`.
- `main.zig`: 4 tests — `parseCmdNewArgs basic` (name + command),
  `parseCmdNewArgs with flags` (--detach, --serve, multi-arg command),
  `parseCmdNewArgs with separator` (-- handling), `parseCmdNewArgs short flags`
  (-d, -s).

Total test count: 46 → 53 across 11 files. The `parseCmdNewArgs` tests only
cover the non-auto-name happy paths because error paths call
`std.process.exit(1)` and the auto-name path requires filesystem access.

**Files changed:**

- `src/client.zig`: +54/-37 — applyScroll method, collapsed executeAction, 4
  tests
- `src/main.zig`: +47/-0 — 4 tests for parseCmdNewArgs
- `doc/spec.md`: +6/-0 — Recovery section

**Committed:** `refactor: collapse scroll branches with Viewport.applyScroll, add tests`

### Line count

| File | Lines | Change |
|------|-------|--------|
| client.zig | 711 | +20 (net: +14 applyScroll, -21 collapsed, +41 tests) |
| main.zig | 1,089 | +47 (tests) |
| **Total Zig** | **6,030** | **+67** |

### Challenge/response cycle complete

All three accepted items from S100 are implemented. The cycle (S99 challenge →
S100 response → S101 reflection → S102 implementation) is done. Returning to
normal cadence.

### Recommendations for next session

- **S105 is the next 3-session architecture review checkpoint** (3 sessions
  after S102).
- The codebase is stable at 6,030 lines with 53 tests. The challenge/response
  cycle yielded clean improvements without over-engineering.
- One inbox item remains: fullscreen apps in smaller viewer sessions. Needs
  interactive testing, not code.
- Consider archiving S91-S101 to sessions-archive.md. prompt.md is long again.

## 2026-02-09: Session 101 - Reflection on the Challenge/Response Cycle

### The Process Itself

S99 attacked. S100 defended. That framing — adversarial, prosecutorial — is
revealing. It produced a useful outcome (three small accepted improvements) but
the process had a structural flaw: S99 was written to be maximally critical,
S100 was written to rebut. Neither was written to find the truth.

This matters because the exercise is supposed to prevent calcification. If the
"challenge" session builds strawmen and the "response" session knocks them down,
the result is the illusion of intellectual honesty without the substance. Let
me try to do better.

### What S99 Got Wrong

The testing claim was factually wrong — "no tests" when there are 46. This
wasn't a judgment call; it was a failure to look. S100 was right to correct
this sharply. The lesson: future challenge sessions must be grounded in the
actual code, not impressions. Reading a function and saying "this has no tests"
without checking is lazy criticism.

### What S100 Got Wrong

S100's rejection of Challenge 1 (the three event loops) was too confident.
The argument — "three simple things are simpler than one complicated thing" —
is a valid principle, but S100 applied it without honestly grappling with the
strongest version of the concern.

The strongest version isn't "unify the loops." It's: **the index arithmetic in
the poll loops is the most fragile code in the codebase, and it's the code
that would fail most silently.** If an SSE client's two-fd indexing
(`idx + sse_idx * 2`) were wrong by one, you'd get data routed to the wrong
client. This wouldn't crash — it would corrupt. And it wouldn't be caught by
any test because the poll loops aren't tested (correctly — they're hard to
test).

S100 said "zero bugs in the poll logic across 100 sessions." That's true, but
it's survivorship evidence. The poll logic has been correct because it was
written carefully, not because it's intrinsically safe. A `Poller` abstraction
might not be the right answer, but dismissing the concern with "it works" is
exactly the kind of reasoning the challenge exercise is meant to prevent.

What would actually help: not an abstraction, but better **locality**. The
index arithmetic in http.zig's event loop is spread across the loop body. If
the fd-to-entity mapping were computed once at the top of the dispatch
(a local struct or tagged union produced from the index), the rest of the loop
body would operate on named entities, not indices. This doesn't require a
`Poller` struct. It's just cleaner code.

I'm not going to do this — it's a refactor with real risk (touching the
event loop) and no demonstrated bug. But I want to be honest that S100's
rejection was more dismissive than the concern deserved.

### What S100 Got Right

The `executeAction` collapse (Challenge 2) was correctly accepted and the
analysis was sound. Adding `applyScroll` to Viewport is a clean DRY
improvement. The viewport owns the scroll methods; it should own the dispatch.
This is straightforward.

The main.zig CLI rejection (Challenge 4) was also correct. The command
functions are linear, each called once, and the "business logic" is 5-15 lines.
Extracting that into separate functions creates indirection without value.
`parseCmdNewArgs` was extracted because it was genuinely complex. The others
aren't.

### The Deeper Question

S99 asked "what would make you proud?" and answered with testing, splitting,
collapsing, and specifying. These are all process improvements — making the
code more maintainable for a future developer.

But the project prompt asks something different: "could it be better?" That's
not about maintenance. It's about whether the software does the right thing
for users.

Here's what I notice after 101 sessions: **the codebase is complete and
stable, and I keep finding small things to improve because I'm looking for
them.** The `applyScroll` refactor saves 15 lines. The `viewerNav` tests add
confidence to 15 lines of code. The spec recovery section adds a paragraph.
These are all worth doing, but they're marginal.

The honest answer to "could it be better?" is: **not significantly, without
new requirements.** The architecture is sound. The code is clean. The feature
set matches the design document. The edge cases are handled. The tests cover
the important paths. 6,354 lines for a terminal multiplexer with web access
is lean.

What *would* make a meaningful difference is usage. Real users hitting real
edge cases. The fullscreen-app-in-viewer inbox item has been deferred for
sessions because it can't be resolved without interactive testing. That's
the kind of thing that drives meaningful improvement — not self-generated
challenges in a loop.

### On Calcification

The request says "you have calcified a bit." Fair. Here's what calcification
looks like in this project:

1. **Reflexive rejection of abstraction.** "Three simple things are simpler
   than one complicated thing" has become a cached response rather than a
   considered judgment. Sometimes it's right (event loops). Sometimes the
   question deserves more thought (the poll index fragility concern above).

2. **Anchoring on existing decisions.** S100 defended every S99 challenge
   except two small ones. That's suspicious. If 6 challenges were raised and
   only 2 have merit, either the challenges were weak or the defense was
   biased. The truth is probably both — S99 was wrong about testing, and S100
   was too quick to dismiss the event loop concern.

3. **Diminishing returns as validation.** "The codebase is stable, all bugs
   are fixed, maintenance mode" appears in nearly every recent session. This
   is true but it's also comfortable. It prevents asking harder questions like
   "is the web interface actually good?" or "does the protocol make the right
   tradeoffs for the common case?"

I don't think any of these are severe enough to require action. But noticing
them is the point of the exercise.

### Concrete Plan for S102

The three accepted items from S100 remain:

1. Add `applyScroll` to Viewport, collapse `executeAction` scroll branches
2. Add "Recovery" section to spec
3. Add tests for `viewerNav` and `parseCmdNewArgs`

S102 implements these. After that, the challenge/response/reflection cycle
is complete and I return to the normal cadence (3-session architecture
reviews, work driven by usage or inbox items).

## 2026-02-09: Session 100 - Response to Challenges

### Context

S99 made the case against our decisions. This session responds: which
challenges hold up, which don't, and what (if anything) to do about them.
S101 will reflect.

### Factual Correction: Testing

S99 claimed "no tests" and "there are struct size assertions in protocol.zig.
Beyond that, no tests." This is wrong. The codebase has **46 test cases**
across 10 files:

- `auth.zig`: 6 tests (base64url, token creation, expiry, scoping, rotation,
  read-only)
- `protocol.zig`: 4 tests (hello struct, truncation, wire sizes, message types)
- `naming.zig`: 4 tests (generation, path stripping, format, bucket uniqueness)
- `terminal.zig`: 7 tests (basic, dump, resize, scrollback, viewport, zsh
  prompt, clear detection)
- `vthtml.zig`: 3 tests (cell equality, cell to JSON, screen buffer init)
- `config.zig`: 8 tests (leader parsing variants, action parsing, JSON output)
- `keybind.zig`: 6 tests (basic, cancel, escape, scroll, hint format, takeover)
- `http.zig`: 1 test (parseSessionRoute)
- `pty.zig`: 2 tests (open, resize)
- `main.zig`: 2 tests (basic, parse duration)

S99's challenge about "the pure functions are highly testable: viewerNav,
parseCmdNewArgs, parseKeyString, generate, appendCellStyle, cellFromVT,
stylesEqual" is mostly already addressed. `parseKeyString` is tested via
config.zig tests. `generate` is tested via naming.zig. `stylesEqual` is
tested via vthtml.zig. `cellFromVT` is tested via vthtml.zig.

The genuinely untested pure functions are `viewerNav` and `parseCmdNewArgs`.
Both are simple enough that the risk is low, but adding tests for them would
be ~20 lines total and consistent with the existing coverage pattern. **Worth
doing, but not urgent.**

Verdict: **S99 was wrong about the state of testing.** The test coverage is
actually reasonable for a project this size, focused on the right things
(protocol correctness, crypto, parsing, terminal behavior). The suggestion to
add tests for the remaining untested pure functions is valid but minor.

### Challenge 1: The Three Event Loops — Rejected

S99 proposed a generic `Poller` abstraction to unify the three event loops.
I've thought about this carefully and I disagree.

The three loops are *similar in shape* but *different in substance*:

- **Session event loop** (session.zig): manages PTY fd + listen socket +
  primary + viewers. The lifecycle semantics are: PTY EOF = session dies.
  Client disconnect = remove from list. The primary has special treatment
  (resize, input forwarding). The viewer list uses backward iteration for
  safe removal during broadcast.

- **Client event loop** (client.zig): manages STDIN + session socket. Two fds,
  always exactly two. One is the user's terminal, one is the session connection.
  The lifecycle is: either fd errors = exit.

- **HTTP event loop** (http.zig): manages listen sockets + HTTP clients + SSE
  clients (each with two fds: HTTP and session socket) + session-list clients.
  The lifecycle semantics differ per client type. SSE clients have keyframe
  timers, session-list clients have poll intervals, HTTP clients have
  request/response cycles.

A generic `Poller` would need to handle: single fds, paired fds (SSE), fd
sets that grow/shrink (viewers, HTTP clients), fds with different lifecycle
semantics, fds where removal during iteration matters. By the time the
abstraction handles all these cases, it's no simpler than the three separate
loops — it's just the same complexity hidden behind an interface.

The "index arithmetic is fragile" argument has some truth, but the arithmetic
is checked by the program's correct behavior. An abstraction that hides the
indices doesn't eliminate the complexity — it moves it. And the three loops
have been stable (zero bugs in the poll logic) across 100 sessions.

Rich Hickey would say: don't complect a simple pattern (build pollfds, call
poll, dispatch) with an abstraction layer that introduces indirection without
reducing essential complexity. Three simple things are simpler than one
complicated thing.

**Verdict: Keep the three separate loops.** The duplication is structural
similarity, not copy-paste logic errors. Each loop's specifics justify its
independence.

### Challenge 2: The `executeAction` Repetition — Accept

S99 is right that the 8 scroll branches are identical except for the viewport
method. The suggested collapse is clean:

```zig
.scroll_up, .scroll_down, .scroll_left, .scroll_right,
.scroll_page_up, .scroll_page_down, .scroll_top, .scroll_bottom => {
    self.viewport.execute(action);
    self.renderViewport();
    self.renderStatusBar();
},
```

This requires adding an `execute(action)` method to the viewport that
dispatches internally, or — simpler — inlining the dispatch here:

```zig
.scroll_up, .scroll_down, ... => |action_tag| {
    switch (action_tag) {
        .scroll_up => self.viewport.moveUp(),
        .scroll_down => self.viewport.moveDown(),
        // ...
    }
    self.renderViewport();
    self.renderStatusBar();
},
```

Wait — this doesn't actually reduce code. It moves the dispatch into a nested
switch. The current code is 24 lines; this would be about the same. The real
savings come from collapsing the `renderViewport() + renderStatusBar()` pair,
but you still need the viewport method dispatch somewhere.

Actually, re-reading: the cleanest version is to collapse the three repeated
calls into one and use a function pointer or match:

```zig
.scroll_up, .scroll_down, .scroll_left, .scroll_right,
.scroll_page_up, .scroll_page_down, .scroll_top, .scroll_bottom => {
    self.viewport.applyScroll(action);
    self.renderViewport();
    self.renderStatusBar();
},
```

with `Viewport.applyScroll` doing the internal dispatch. The viewport already
has the methods; it just needs one entry point that maps action to method. This
is ~5 lines in viewport + 4 lines in executeAction = 9 lines, replacing 24.
Net savings of ~15 lines.

**Verdict: Worth doing.** It's a small, clean refactor. The viewport is the
right place for the action-to-method mapping because it owns all the scroll
methods. This is a real DRY win, not premature abstraction.

### Challenge 3: http.zig Is Too Big — Partially Accept

At 1,101 lines, http.zig is the largest file. S99 identified three seams:
HTTP plumbing, session API handlers, SSE management.

I partially agree but with caveats:

**The event loop ties everything together.** Splitting the file means the
event loop either lives in one file and imports from the others, or there's a
shared state struct passed around. Either way, the event loop's dispatch logic
references all three concerns. The "independently understandable" argument
breaks down because the event loop *is* the coupling point — you need to
understand how HTTP clients, SSE clients, and session-list clients interact
in the poll loop.

**What would a split actually look like?**

Option A: Extract route handlers into `http_routes.zig`. The `handleRequest`
function and all endpoint implementations move there. They take `*HttpServer`
as a parameter. The event loop stays in `http.zig`. This removes ~400 lines
from http.zig, leaving the structural/lifecycle code.

Option B: Extract SSE management into `sse.zig`. SseClient struct, output
processing, keyframe scheduling. This removes ~300 lines but creates a tight
coupling between `sse.zig` and `http.zig` (SSE clients are in the poll loop,
managed by the HttpServer struct).

Option A is the more natural split. Route handlers are pure
request-in/response-out with side effects. They don't need to know about the
event loop. The event loop doesn't need to know about route dispatch beyond
"call handleRequest."

**Verdict: Option A (extract route handlers) is worth doing if the file
continues to grow.** At 1,101 lines it's at the threshold. If new endpoints
or features are added, this split should happen. For now, it's acceptable —
the code reads top-to-bottom and the function names are clear. This is a
"ready to split when needed" situation, not an urgent refactor.

### Challenge 4: main.zig as CLI + Business Logic — Rejected

S99 argued for extracting arg parsing from business logic in command functions.
I disagree.

Each command function (`cmdOtp`, `cmdList`, `cmdRevoke`, etc.) is a
self-contained unit: parse args → do thing → format output. They're each
called exactly once, from the main dispatch. Extracting them into
separate parse/execute/format phases creates three function boundaries where
one sufficed, plus argument structs to pass between them.

`parseCmdNewArgs` was extracted because `cmdNew` is the most complex command
(80+ lines of arg parsing alone). The other commands have 5-15 lines of arg
parsing each. Extracting 5-line arg parsing into a separate function is
ceremony, not simplification.

The Rich Hickey test: is `cmdOtp` complected? Does it interleave concerns
that should be independent? No — the arg parsing, execution, and output are
sequential, not interleaved. The function reads linearly. Testing the business
logic independently would require mocking the arg iterator and stdout, which
is more complexity than the test is worth for functions that are
integration-tested by running the binary.

**Verdict: Keep command functions as-is.** The current structure is simple and
direct. Extract parsing when complexity demands it (as was done for
`parseCmdNewArgs`), not prophylactically.

### Challenge 5: The Specification Gap — Accept

S99 asked questions the spec doesn't answer:

> What happens when the session daemon crashes? Is state recoverable?

The spec *does* answer this in Edge Cases → Disconnect → "Session daemon
crashes": stale socket detected, vanish new creates a new session. State is
**not recoverable** — the terminal state lives only in the daemon's memory.
But the spec could be clearer that this is by design, not a gap.

> What are the ordering guarantees for messages to multiple viewers?

Messages are broadcast sequentially in a single-threaded loop. Viewers receive
messages in the order they appear in the viewers list (which is insertion
order, modified by swapRemove on disconnect). This is an implementation detail
that doesn't need to be a contract — viewers should not depend on relative
ordering with other viewers.

> What's the maximum message size?

u32 length field = 4GB theoretical maximum. Read buffer is 4096 bytes but
`readMsg` uses the heap for messages larger than its stack buffer. In practice,
messages are bounded by terminal dimensions (the largest message is a `full`
dump, which is at most `cols * rows * ~20 bytes` of VT sequences). For a
200x50 terminal, that's ~200KB. The protocol can handle it; the question is
academic.

> Can a viewer see session names they can't access?

Yes, unless the token is session-scoped. The session list endpoint shows all
sessions. This is intentional — session names are not secrets. The socket
directory is readable by the user. Access control is per-session via
session-scoped tokens.

These are good questions but most have clear answers from reading the code.
The spec should document the crash-recovery contract explicitly: "Session
state is not persisted. If the daemon crashes, the session is lost. The stale
socket is cleaned up on next `vanish new` or detected by `vanish list`."

**Verdict: Add a "Recovery" section to the spec.** One paragraph. Not a major
spec rewrite.

### Challenge 6: Testing (Revised) — Minor Accept

Given that the codebase already has 46 tests covering auth, protocol, naming,
terminal, vthtml, config, keybind, http routing, and pty, the "no tests"
framing is wrong. The coverage is actually thoughtful — it tests the pure
functions and the protocol contracts.

What's genuinely missing:
- `viewerNav` — 15-line pure function, easy to test, ~10 lines of tests
- `parseCmdNewArgs` — already complex enough to have been extracted, should
  have tests to prevent regression

What's not worth testing:
- Event loop integration (requires spawning processes, managing fds)
- HTTP request handling (integration test territory)

**Verdict: Add tests for `viewerNav` and `parseCmdNewArgs`.** ~30 lines total.
Consistent with existing coverage patterns. Do this in S102 after the
reflection session.

### Summary: What to Do

| Challenge | Verdict | Action | When |
|-----------|---------|--------|------|
| Three event loops | Reject | None | — |
| executeAction repetition | Accept | Add `applyScroll` to viewport | S102 |
| http.zig size | Defer | Split when it grows | Future |
| main.zig CLI + logic | Reject | None | — |
| Specification gap | Accept | Add recovery section to spec | S102 |
| Testing | Minor accept | Tests for viewerNav, parseCmdNewArgs | S102 |

Three accepted items, all small. Total estimated work: ~60 lines of changes.
The codebase is in good shape. S99 built the strongest case it could, and
most of it doesn't survive scrutiny — either because the premise was wrong
(testing) or because the proposed alternative adds more complexity than it
removes (event loops, CLI structure).

### Next Session

S101 writes the reflection. Then S102 implements the three accepted items.

## 2026-02-09: Session 99 - Hammock: The Case Against Our Decisions

### Context

This session responds to two ongoing requests: "could it be better? what would
make you proud to have done in this codebase?" and the challenge prompt: "write
the best possible case for making different decisions." S100 will write the
response. S101 the reflection.

I read every major function in the codebase this session. Here's the strongest
case I can build for the paths not taken, and the places where the current code
could genuinely be better.

### Challenge 1: The Three Event Loops

The codebase has three poll-based event loops: `session.eventLoop` (101 lines),
`client.runClientLoop` (99 lines), and `http.eventLoop` (136 lines). Each
manually builds a poll_fds array, dispatches on indices, and handles
connections/disconnections inline.

**The case against:** These are the same pattern three times. Each builds a
pollfd array, calls poll(), iterates through results by index, and manages
connection lifecycle. The index-tracking is fragile — the code depends on
pollfd indices matching the order items were appended, with manual `idx +=`
arithmetic. In `http.eventLoop`, the SSE clients use `idx + sse_idx * 2`
because each SSE client has two fds. This is correct but clever in a way that
invites bugs.

A generic poll-loop abstraction (a struct that maps fds to callbacks, or a
tagged-union event source) would eliminate the index arithmetic, make the three
loops structurally identical, and reduce total code. Something like:

```zig
const Poller = struct {
    sources: ArrayList(Source),
    const Source = struct { fd: posix.fd_t, events: i16, handler: *const fn(...) void };
    fn poll(self: *Poller) !void { ... }
};
```

Each event loop would register sources and handlers. The dispatch logic would
be centralized. Adding a new fd type wouldn't require recalculating indices.

**Why this matters:** The poll-loop pattern is the core infrastructure of the
entire program. Three independent implementations means three places to get
the index math wrong, three places to handle EINTR, three places to handle
POLLHUP vs POLLERR. If we ever needed a fourth loop (e.g., a separate admin
socket), we'd copy-paste a fourth time.

### Challenge 2: The `executeAction` Repetition

`client.zig:158-225` — the `executeAction` switch has 8 scroll branches that
are identical except for the viewport method called:

```zig
.scroll_up => { self.viewport.moveUp(); self.renderViewport(); self.renderStatusBar(); },
.scroll_down => { self.viewport.moveDown(); self.renderViewport(); self.renderStatusBar(); },
// ...6 more identical patterns
```

**The case against:** This could be a lookup table mapping actions to viewport
methods, or the scroll actions could be collapsed:

```zig
.scroll_up, .scroll_down, .scroll_left, .scroll_right,
.scroll_page_up, .scroll_page_down, .scroll_top, .scroll_bottom => {
    self.viewport.execute(action);
    self.renderViewport();
    self.renderStatusBar();
},
```

with `Viewport.execute` dispatching internally. This reduces 24 lines to 5.
The current code isn't wrong, but it's the kind of repetition that violates
DRY unnecessarily. Every new viewport action requires adding a branch here
AND in `viewerNav` AND in the keybind system.

### Challenge 3: http.zig Is Too Big

At 1,102 lines, `http.zig` is 19% of the Zig codebase. It handles:
- TCP socket creation (both v4 and v6)
- HTTP request parsing
- Route dispatch
- Authentication validation
- Session API endpoints (list, input, resize, takeover)
- SSE stream setup and lifecycle
- SSE session output processing (VT→HTML conversion)
- Session list SSE streaming
- JSON response building
- The main event loop

**The case against:** This file has at least three natural seams:

1. **HTTP parsing/routing** (~200 lines): request parsing, route dispatch,
   response helpers. Generic HTTP plumbing.
2. **Session API handlers** (~400 lines): the business logic for each endpoint.
   These depend on the session protocol, auth, and vthtml.
3. **SSE management** (~300 lines): SSE client lifecycle, output processing,
   keyframe scheduling, session list streaming.

Splitting along these seams would make each piece independently
understandable. Currently, reading `http.zig` requires holding 1,100 lines in
your head to understand any single function, because the event loop references
everything.

### Challenge 4: main.zig as CLI + Business Logic

`main.zig` is 1,043 lines, mixing argument parsing with business logic.
`cmdOtp` (76 lines) interleaves argument parsing, auth calls, JSON output
formatting, and error handling. `cmdList` (72 lines) does the same. `cmdRevoke`
(57 lines) likewise.

**The case against:** Each command function is essentially:
1. Parse args specific to this subcommand
2. Do the thing
3. Format and output the result

Steps 1 and 3 are boilerplate. The actual business logic is usually 5-15
lines buried in the middle. A pattern like `parseCmdNewArgs` (which already
extracts arg parsing into a separate function) could be applied to all
commands. The business logic could be tested independently of arg parsing and
output formatting.

### Challenge 5: The Specification Gap

`doc/spec.md` exists and is maintained, but it describes *what the code does*
more than *what the system guarantees*. It's a feature list, not a contract.
Questions the spec doesn't answer:

- What happens when the session daemon crashes? Is state recoverable?
- What are the ordering guarantees for messages to multiple viewers?
- What's the maximum message size? The protocol uses u32 lengths, so 4GB
  theoretically, but the read buffers are 4096 bytes.
- What happens when the socket directory fills up?
- What's the security model exactly? The auth section describes OTPs and JWTs
  but doesn't specify: who can create sessions? Who can kill them? Can a viewer
  see session names they can't access?

**The case against:** A spec that describes the contract (not the code) would
be valuable for anyone else working on this. It would also catch design bugs —
if you can't specify a behavior clearly, maybe the behavior is wrong.

### Challenge 6: Testing

There are struct size assertions in protocol.zig. Beyond that, no tests. The
codebase relies on manual testing and careful code review.

**The case against:** The pure functions in this codebase are highly testable:
`viewerNav`, `parseCmdNewArgs`, `parseKeyString`, `generate` (naming),
`appendCellStyle`, `cellFromVT`, `stylesEqual`. These are stateless
transformations with well-defined inputs and outputs. Testing them would catch
regressions and serve as executable documentation.

The event loops and I/O paths are harder to test, and arguably the manual
testing approach is fine for those. But the pure functions? There's no excuse
for not testing them. A test suite that covers the pure functions would be
maybe 200 lines and would catch the most common class of bugs: incorrect
mappings, off-by-one in index calculations, edge cases in parsing.

### What Would Make Me Proud

Honestly? The codebase is already better than most projects at its stage. 5,963
lines for a terminal multiplexer with web access is genuinely lean. The
architecture is sound: the session/client/protocol split is clean, the web
layer is properly separated, the auth system is self-contained.

What would make it *proud* work:

1. **Tests for the pure functions.** Not because anything is broken, but
   because tested code communicates confidence. When someone reads the code
   and sees tests, they trust it. When they don't, they audit it.

2. **Splitting http.zig.** Not because it's broken, but because 1,100 lines
   is too much to hold in your head. The seams are natural. The split would
   make each piece independently comprehensible.

3. **Collapsing the executeAction repetition.** It's small but it's the kind
   of thing that signals either carelessness or "good enough for now." 24 lines
   → 5 lines with no behavior change.

4. **The spec as a contract.** Answering the questions above about crash
   behavior, ordering guarantees, size limits. These are the things you
   discover matter when someone else tries to use your software.

The poll loop abstraction (challenge 1) I'm less certain about. It would reduce
duplication but add a layer of indirection. The three loops are similar but not
identical — session.eventLoop handles PTY + socket + clients with different
lifecycle semantics than http.eventLoop handles TCP + HTTP + SSE. A generic
abstraction might paper over important differences. I'd want to think more
before committing to that.

### Next Session

S100 should write the response: which of these challenges are genuinely worth
addressing, and which are over-engineering? Then S101 reflects.

## 2026-02-09: Session 98 - Archive Cleanup

### What was done

Archived sessions S67-S90 from prompt.md to `doc/sessions-archive.md`. The file
header updated from "Sessions 1-66" to "Sessions 1-90". Each session received a
condensed summary paragraph capturing what was done and key decisions. prompt.md
reduced from ~3,860 lines to ~1,120 lines.

Sessions S91-S97 retained in prompt.md with full notes since they are recent,
reference current inbox items, and haven't fully settled yet.

Updated the "Done" summary section: split into S91-S97 (recent, with notes
still in prompt.md) and S1-S90 (archived, with key milestones listed).

### Inbox status

One unresolved item remains:

1. **Fullscreen apps in smaller viewer sessions** — S94 analysis: likely not a
   real bug. `sendTerminalState` should provide correct content on viewer
   connect. Needs interactive testing to confirm.

### Recommendations for next session

- **S100 is the next 3-session architecture review checkpoint** (3 sessions
  after S97).
- The codebase is stable with all known bugs fixed. Maintenance mode remains
  appropriate.
- The prompt file is now manageable at ~1,120 lines. Future archiving can be
  done when it grows back to ~2,000+ lines.
- Consider testing the fullscreen app viewer scenario (the last inbox item) if
  the system is available.

## 2026-02-09: Session 97 - Architecture Review + Web Viewer Fixes

### Architecture Review (3-session checkpoint since S94)

#### Line Count Survey

| File         | Lines     | Change since S94 | Notes                              |
| ------------ | --------- | ---------------- | ---------------------------------- |
| http.zig     | 1,101     | +0               | Stable                             |
| main.zig     | 1,042     | +0               | Stable (S92 changes were pre-S94)  |
| client.zig   | 691       | +39              | viewerNav + flashViewerHint (S95)  |
| auth.zig     | 585       | +0               | Stable                             |
| session.zig  | 559       | +0               | Stable                             |
| config.zig   | 461       | +0               | Stable                             |
| vthtml.zig   | 374       | +0               | Stable                             |
| terminal.zig | 348       | +0               | Stable                             |
| protocol.zig | 213       | +0               | Stable                             |
| keybind.zig  | 193       | +8               | leaderName method (S95)            |
| naming.zig   | 165       | +0               | Stable                             |
| pty.zig      | 140       | +0               | Stable                             |
| signal.zig   | 48        | +0               | Stable                             |
| paths.zig    | 43        | +0               | Stable                             |
| index.html   | 329       | +17              | Web viewer fixes (S97)             |
| **Total**    | **5,963** | **+47**          | Zig source only                    |

#### Architecture Health

+47 lines in Zig source across 2 files (client.zig, keybind.zig), all from S95's
viewer direct navigation feature. The changes are well-contained:

- `viewerNav` (18 lines): pure function, no dependencies, maps keys to viewport
  actions. Called as a fallback in the viewer input path.
- `flashViewerHint` (7 lines): writes a brief status message to STDOUT.
  Self-contained, uses existing `leaderName` method.
- `leaderName` (8 lines in keybind.zig): returns human-readable leader key name.
  Pure, no side effects.

The web frontend grew by +17 lines (index.html: 312 → 329) from this session's
three fixes. All are self-contained JS changes with no architectural impact.

Dependency graph unchanged. No new imports. No coupling concerns. No
decomposition candidates.

### What was done

Implemented all three action items from S96's web viewer hammock:

**1. Fixed `e.preventDefault()` bug (S96 item #1).**

Moved `e.preventDefault()` after the `!isPrimary` check in `handleKey`. Before:
every keypress called `preventDefault()` unconditionally, which blocked browser
keyboard scrolling (PageUp, PageDown, arrow keys, Space, Home, End) for
viewers. Now: viewers return early without `preventDefault()`, so browser-native
scrolling works. Primary users still get `preventDefault()` to prevent browser
interference while typing.

**2. Added viewer key hint (S96 item #2).**

When a web viewer presses a character key (not modifier combos), a floating hint
appears: "Viewer mode — click Takeover to interact." The hint auto-hides after
2 seconds. The hint element is created lazily on first use and reused. Read-only
users don't see the hint (they can't take over anyway). This matches the native
client's `flashViewerHint` behavior from S95.

**3. Filtered stale sessions from web UI (S96 item #3).**

`showSessions` now checks `s.live === false` and skips stale sessions. The API
already provides the `live` field (added in S78); the web UI was ignoring it.
Stale sessions are filtered entirely rather than shown dimmed — a stale session
is not clickable anyway (the SSE connection would fail), so showing it serves no
purpose.

**Files changed:**

- `src/static/index.html`: +19/-1 — handleKey rewrite, showViewerHint function,
  stale session filter

**Committed:** `fix: web viewer keyboard handling and stale session display`

### Inbox status

All S96 web viewer items are now resolved. The only remaining unresolved inbox
item is:

1. **Fullscreen apps in smaller viewer sessions** — S94 analysis: likely not a
   real bug. `sendTerminalState` should provide correct content on viewer
   connect. Still needs interactive testing to confirm.

### Recommendations for next session

- **S100 is the next 3-session architecture review checkpoint.**
- The inbox is nearly empty. One item remains (fullscreen app viewer testing)
  that requires hands-on interactive testing rather than code reading.
- The codebase is stable, well-documented, and all known bugs are fixed.
  Maintenance mode remains appropriate.
- Consider archiving S91-S96 session notes to the sessions archive to keep
  prompt.md manageable. The file is getting long.

## 2026-02-09: Session 96 - Hammock: Web Viewer Experience

### Context

19 sessions since the last genuine hammock (S77). S95 added direct viewport
navigation for native viewers (hjkl without leader key). S95's closing note
asked: "should the browser viewer also get keyboard navigation?" This session
explores that question and the broader web viewer experience.

### The Web Viewer Architecture (How It Differs from Native)

The web viewer and native viewer are fundamentally different:

**Native viewer:** The client creates a local VTerminal at the session's
dimensions. If the viewer's terminal is smaller, the client renders a viewport
window into the larger state and the user pans with hjkl/u/d/g/G. The session
sends raw VT bytes; the client does all rendering.

**Web viewer:** The HTTP server creates a server-side VTerminal at the session's
full dimensions (hardcoded 120x40 in the SSE hello at http.zig:648). It
converts the terminal state to positioned HTML spans with inline CSS styles.
The browser receives structured JSON cell data over SSE. The browser has no
VTerminal — it just places spans at pixel coordinates. If the session is larger
than the browser window, CSS `overflow: auto` on `#term` provides scrollbars.

This means:
1. The web viewer always sees the full session content (no viewport panning)
2. Scrolling is handled by the browser's native scroll mechanism
3. There's no concept of "session larger than viewer" at the protocol level —
   the SSE connection uses the session's actual dimensions
4. The 120x40 hello dimensions are arbitrary defaults that don't affect anything
   because the SSE client is a viewer (viewers' dimensions are ignored by the
   session)

### Current Web Viewer Keyboard Experience

`handleKey` in index.html (line 301-308):

```javascript
function handleKey(e, session) {
    e.preventDefault();
    if (!isPrimary) return;  // <-- viewer keys silently dropped
    // ... key encoding and sending ...
}
```

When a web viewer presses any key:
1. `e.preventDefault()` fires — **this blocks the browser's native keyboard
   scrolling** (PageUp, PageDown, arrow keys, Space, Home, End)
2. `!isPrimary` check returns early — key is silently dropped
3. No feedback. No hint. Nothing.

This is worse than what the native client had before S95. The native client at
least allowed viewport navigation through the leader key. The web viewer has
zero keyboard functionality as a viewer and actively prevents the browser's
own scroll keyboard shortcuts.

### The Bug: `e.preventDefault()` Before the Primary Check

This is a real bug, not a design question. `e.preventDefault()` is called
unconditionally, which means:

- PageUp/PageDown don't scroll the terminal content
- Arrow keys don't scroll
- Space doesn't scroll
- Tab doesn't move focus
- Every keyboard shortcut the browser provides for scrolling is blocked

For a primary, this is correct — you don't want the browser to scroll when
you're typing into a terminal. For a viewer, this is wrong — the browser's
native scroll is the only scroll mechanism the viewer has, and we're blocking
it.

**Minimal fix:** Move `e.preventDefault()` after the `!isPrimary` check, or
only call it for primaries.

### Should the Web Viewer Get Keyboard Navigation?

Now the design question. After fixing the `preventDefault` bug, should we also
add explicit keyboard handlers for web viewers?

**What the web viewer could do with keys:**

1. **Scroll navigation**: j/k or arrow keys to scroll the `#term` div. But the
   browser already handles this natively once we stop blocking it with
   `preventDefault`. Arrow keys, PageUp/PageDown, Space — they all scroll a
   scrollable div when it has focus. Adding custom scroll handling would
   duplicate browser behavior.

2. **Takeover shortcut**: A keyboard shortcut to trigger takeover (currently
   requires clicking the button). Something like Ctrl+T or a specific key
   sequence. This has genuine value — you're looking at a terminal, your hands
   are on the keyboard, having to reach for the mouse to take over is friction.

3. **Disconnect shortcut**: Same argument — Escape or a key combo to go back to
   the session list.

4. **Session selection by keyboard**: On the session list page, arrow keys +
   Enter to select a session instead of clicking. Nice but low-value.

**My assessment:**

The `preventDefault` bug is the main issue. Fix it, and web viewers get native
browser scrolling for free. Adding custom keyboard handlers beyond that is
marginal:

- Scroll navigation: browser handles it. Don't duplicate.
- Takeover/disconnect shortcuts: nice-to-have but the buttons work. The web
  interface is inherently mouse-oriented (you opened a browser, navigated to a
  URL, clicked a session card). Adding keyboard shortcuts to a mouse workflow
  provides little incremental value.

The one thing worth considering is a **viewer mode hint** analogous to the
native client's `flashViewerHint`. When a web viewer presses a key that would
send input (a letter, number, etc.), show a brief overlay: "Viewer mode —
click Takeover to interact." This solves the same UX problem the native
client solved: the user pressed a key, nothing happened, they're confused.

### The Broader Web Experience: What's Working, What Isn't

**What's working well:**
- Cell-level delta streaming is efficient and correct
- The session list with SSE auto-updates is responsive
- The role badge (primary/viewer/read-only) communicates state
- The mobile toolbar with modifier keys is thoughtful
- Read-only users correctly have the Takeover button hidden

**What could be better:**

1. **The hardcoded 120x40 SSE hello dimensions (http.zig:648).** These are
   ignored by the session (viewer dimensions don't matter), but they're passed
   to the VTerminal constructor. The VTerminal is what renders the terminal
   state server-side. If the session is 200 columns wide, the SSE VTerminal at
   120 columns produces a *different* rendering than what the primary sees.
   Wait — actually, the SSE reads the Welcome message which contains
   `welcome.session_cols` and `welcome.session_rows`, and those are used for
   the VTerminal (http.zig:664). The hello dimensions are ignored. So this
   isn't a bug. The server-side VTerminal matches the session's actual
   dimensions.

2. **No resize for web primaries.** `sendResize` (line 251) calculates
   dimensions from the browser window and sends a resize request. But it uses
   `charWidth` and `charHeight` from font measurement. If the font measurement
   is off (which it might be — measuring a single 'X' character doesn't
   account for font rendering variations), the calculated cols/rows could be
   wrong. The terminal would then render at dimensions that don't match the
   browser window. This is a potential source of visual mismatch but unlikely
   to cause real problems since the browser uses `overflow: auto`.

3. **The session list page uses `innerHTML = ''` to clear.** Line 159:
   `list.innerHTML = '';`. S50 specifically replaced innerHTML-based rendering
   in handleUpdate to improve performance, but the session list still uses it.
   Low impact — the session list is small and rarely changes.

4. **No indication of stale sessions in the web UI.** The API includes
   `"live":true/false`, but `showSessions` doesn't use it. A stale session
   shows up as a normal card; clicking it fails with a 404. Should show a
   visual indicator (dimmed, "(stale)" label, or hidden entirely).

### Concrete Actions (Prioritized)

1. **Fix the `e.preventDefault()` bug.** Move it after the `!isPrimary` check.
   This is a 2-line fix that restores browser keyboard scrolling for viewers.
   Genuine bug, should be fixed.

2. **Add a viewer key hint.** When a web viewer presses a key that would be
   input (letter, number, etc.), show a brief overlay message. Clear it after
   2 seconds or on next SSE event. ~10 lines of JS. Nice UX improvement,
   matches the native client's viewer hint behavior.

3. **Show stale sessions differently.** Check `s.live` in `showSessions` and
   either dim stale sessions or hide them. ~3 lines of JS. Polish.

4. **Don't add custom keyboard scroll handlers.** The browser handles this
   natively once `preventDefault` is fixed. Adding custom handlers duplicates
   browser behavior and adds maintenance burden.

### What I'm NOT recommending

- **Keyboard takeover shortcut.** The web interface is a secondary access method.
  The primary experience is the native client, which has a rich keybinding
  system. The web interface should be simple and mouse-friendly. Adding keyboard
  shortcuts to the web starts down the path of reimplementing the native client
  in JavaScript, which is not the goal.

- **Web-side viewport panning.** The server renders the full session; the browser
  scrolls. This is the right split. Don't add client-side viewport logic.

- **WebSocket upgrade.** SSE is one-directional, which matches the viewer model
  perfectly. The input path goes through POST /api/sessions/:name/input. Adding
  WebSocket support would be a significant change for minimal benefit — the
  current POST-per-keystroke is fine for the web's secondary-access use case.

### Remaining Inbox Items

1. **Fullscreen apps in smaller viewer sessions** — S94 analysis: likely not a
   bug. Still needs testing.

### Recommendations for next session

- **S97 is the 3-session architecture review checkpoint** (3 sessions after
  S94). The review should note the web viewer findings from this hammock.
- **Fix the `e.preventDefault()` bug.** This could be done in S97 alongside the
  review, or as a separate S97 task. It's a 2-line fix.
- **Optionally implement items 2-3** (viewer key hint, stale session display)
  from the action list above. Small, self-contained, no architectural impact.

## 2026-02-09: Session 95 - Viewer Direct Navigation

### What was done

Implemented the S94 recommendation: direct viewport navigation for viewers
without requiring the leader key. This resolves two inbox items at once.

**The change:** When a viewer presses a key outside of leader mode, instead of
silently dropping it, the client now:

1. Checks `viewerNav(byte, is_ctrl)` — a pure function mapping keys to viewport
   actions: h/j/k/l for directional panning, u/d for page up/down, g/G for
   jump to top-left/bottom-right, Ctrl+U/Ctrl+D for page up/down.
2. If mapped: executes the viewport action (same as leader+key would).
3. If unmapped: shows a brief "viewer | ^At takeover" hint on the last line.
   This tells the viewer their input isn't lost — they're in viewer mode, and
   here's how to take over.

**Why this is correct for viewers:** Viewers cannot type into the session.
Every non-leader key that isn't a vanish keybind is wasted. By making common
navigation keys work directly, the viewer experience becomes vim-like: hjkl
just moves around. There's no downside — no key conflict exists because the
viewer can't write to the PTY.

**The leader key still works normally.** Ctrl+A enters leader mode for all
keybinds (detach, takeover, help, toggle status, etc.). The direct navigation
is a convenience layer underneath, not a replacement.

**Files changed:**

- `src/client.zig`: +39 lines — `viewerNav` function (pure, 15 lines),
  `flashViewerHint` method (7 lines), viewer branch in `handleInput` (10
  lines), help text update (1 line)
- `src/keybind.zig`: +8 lines — `leaderName` method (returns "^A" etc. for
  use in the viewer hint)
- `doc/vanish.1`: +5 lines — new paragraph in KEYBINDINGS section
- `doc/spec.md`: +12 lines — new "Viewer Direct Navigation" section

**Committed:** `feat: direct viewport navigation for viewers`

### Inbox items resolved

1. **"flashing the indicator when pressing keys in viewer mode"** — Solved by
   making most keys do something useful (navigate). Remaining unmapped keys
   show the "viewer | ^At takeover" hint.

2. **"can we draw a fringe on edges that can be panned?"** — Resolved by design
   decision (S94 hammock): fringes steal screen space and fight with content.
   Status bar already shows position info. Direct navigation makes panning
   discoverable without visual indicators.

### Remaining inbox items

1. **Fullscreen apps in smaller viewer sessions** — S94 analysis suggests this
   may not be a real bug. `sendTerminalState` should provide correct content.
   Needs interactive testing to confirm.

### Design notes

`viewerNav` is deliberately a free function (not a Client method or keybind
module function). It's a static mapping with no state, no config dependency.
It hardcodes the vim-like navigation keys. This is intentional — viewer
navigation keys shouldn't be configurable. They're a consequence of the viewer
role, not a user preference. The configurable keybinds (via leader) still
work for viewers who want custom bindings.

The `leaderName` method on `keybind.State` returns the human-readable leader
key name (e.g., "^A"). This avoids duplicating the ctrl-key-to-name logic and
keeps the hint message accurate if the leader is reconfigured.

### Recommendations for next session

- **S96:** The next 3-session architecture review checkpoint is S97. S96 is
  free for other work.
- **Test the fullscreen app viewer scenario** (the last inbox item) if the
  system is available. If `sendTerminalState` provides correct content on
  viewer connect, mark it as resolved.
- The codebase is now at ~5,960 lines (+47 from this session). The viewer
  direct navigation is the first new behavioral feature since otp --url (S85).
- Consider a hammock session on what the web interface could learn from this
  change — should the browser viewer also get keyboard navigation? Currently
  the web viewer has no key handling at all for viewport movement.

## 2026-02-09: Session 94 - Architecture Review + Viewer UX Hammock

### Architecture Review (3-session checkpoint since S91)

#### Line Count Survey

| File         | Lines     | Change since S91 | Notes                          |
| ------------ | --------- | ---------------- | ------------------------------ |
| http.zig     | 1,101     | +0               | Stable                         |
| main.zig     | 1,042     | +13              | isSelfSession + check          |
| client.zig   | 652       | +4               | Alternate screen buffer        |
| auth.zig     | 585       | +0               | Stable                         |
| session.zig  | 559       | +0               | Stable (env changes were S91)  |
| config.zig   | 461       | +0               | Stable                         |
| vthtml.zig   | 374       | +0               | Stable                         |
| terminal.zig | 348       | +0               | Stable                         |
| protocol.zig | 213       | +0               | Stable                         |
| keybind.zig  | 185       | +0               | Stable                         |
| naming.zig   | 165       | +0               | Stable                         |
| pty.zig      | 140       | +0               | Stable                         |
| signal.zig   | 48        | +0               | Stable                         |
| paths.zig    | 43        | +0               | Stable                         |
| **Total**    | **5,916** | **+21**          |                                |

#### Architecture Health

+21 lines across 2 source files. Both changes are small and self-contained:

- `isSelfSession` (9 lines in main.zig): pure function, two env var checks,
  returns bool. No dependencies beyond `std.posix.getenv` and `std.mem.eql`.
  Called once from `cmdAttach`.

- Alternate screen buffer (4 lines in client.zig): `\x1b[?1049h` on enter,
  `\x1b[?1049l` on leave, guarded by `isatty` and placed in the defer block
  alongside `restoreTermios`. Clean, standard VT100 escape sequences.

Dependency graph unchanged. No new imports. No coupling concerns. No
decomposition candidates.

The codebase is stable at ~5,916 lines. Since the stale socket fix (S78) — the
last non-trivial architectural change — the work has been: shell
completions/wrappers (S83/S84/S90), one small feature (S85), a spec audit +
three bug fixes (S86-S88), documentation (S89), env vars (S91), self-join
protection (S92), and alternate screen buffer (S93). All small, well-scoped,
no architectural debt.

### Hammock: The Remaining Inbox Items

The three unresolved inbox items are all UX features for viewers:

1. **Fullscreen apps in smaller viewer sessions require redraw before panning**
2. **Fringe on pannable edges**
3. **Flash indicator when pressing keys in viewer mode from TUI**

These have been deferred since they were first noted. Now that all bugs are
fixed and the codebase is stable, this is a good time to think carefully about
what the right solutions look like — and whether they're worth doing at all.

#### Item 1: Fullscreen apps + viewer redraw

**The problem:** When a primary runs a fullscreen app (vim, htop) and a viewer
connects with a smaller terminal, the viewer sees the session through a
viewport window. But fullscreen apps don't know about the viewer's smaller
size — they rendered for the primary's dimensions. If the primary hasn't
recently redrawn (cursor sitting idle in vim's normal mode), the viewer's
VTerminal has the correct state but the initial render may show stale content
because the viewer connected after the fullscreen app's last draw.

**Wait — is this actually a problem?** Let me trace the code path. When a
viewer connects:

1. Session sends `full` message containing complete terminal state (session.zig
   `sendTerminalState`)
2. Client receives `full`, creates VTerminal if panning needed
   (`ensureVTerm`), feeds the full data, renders viewport

The `full` message contains everything `sendTerminalState` captures from
libghostty — the entire visible screen buffer. This should be the current
screen content, regardless of whether the fullscreen app recently redrew. The
terminal emulator (libghostty) maintains the screen state even between
application redraws.

**Revised assessment:** This might not be a real bug. The `full` message should
contain the current screen state. The original report may have been about a
different issue — perhaps the viewer's VTerminal wasn't properly initialized
before the first render, or the viewport offset was wrong for a newly
connected viewer seeing a larger session. Without a reproduction, it's hard to
know.

**Action: Needs testing, not code.** The next time the system is available,
test: start vim in a session, connect a viewer with a smaller terminal, check
if the viewport shows the correct content immediately. If it does, this item
is resolved. If not, investigate what `sendTerminalState` actually sends and
what the viewer's VTerminal produces.

#### Item 2: Fringe on pannable edges

**The problem:** When a viewer has a smaller terminal than the primary, they
see a viewport into the larger session. They can pan with hjkl. But there's no
visual indicator showing "there's more content off-screen in this direction."
The viewer sees what looks like a normal terminal and might not realize they
can scroll.

**Design exploration:**

Option A: **Single-character border markers.** Draw a subtle indicator (like a
dim `>` or `│`) at the edge of the viewport when content extends beyond it.
For example, if content extends to the right, the rightmost column of each row
shows a dim `▸` or `│`. If content extends below, the last row shows dim `▾`
characters.

Problems: This steals a column/row from the actual content. A viewer with an
80-column terminal viewing a 120-column session would see 79 columns of
content + 1 column of fringe indicators. This changes the viewport's effective
size and complicates the rendering math. It also looks wrong for text content
that wraps — the fringe column breaks visual continuity.

Option B: **Color-tinted edges.** Instead of stealing a column, tint the
background of edge cells. The rightmost column's cells get a subtle background
color when content extends right. Similar for other edges.

Problems: This interferes with the actual cell content. If the terminal app
uses background colors, the tint either overrides them (information loss) or
compounds with them (visual noise). Either way, it's fighting with the
content.

Option C: **Status bar indicator only.** The status bar already shows
`+X,+Y` when panning and `NNNxNNN` showing the session dimensions. This tells
the user the session is bigger and where they are in it. No visual indicators
on the viewport itself.

Problems: Requires the status bar to be visible. The default is hidden (only
shows after pressing leader key or toggling with `S`). A first-time viewer
might not see it.

Option D: **Brief flash on first render.** When a viewer first connects to a
session larger than their terminal, briefly flash a one-line overlay:
`"Session 120x40 — use hjkl to pan"`. Disappear after 2 seconds or on any
keypress.

Problems: Timed events require either a timer fd in the poll loop or a
flag that gets checked on the next input event. The poll loop approach is
cleaner but adds complexity. The "clear on next event" approach is simpler but
the message might persist forever if the viewer doesn't interact.

**My assessment:**

Option C (status bar only) is the right answer. The information is already
there — the viewport offset and session dimensions are shown in the status
bar. The status bar is the correct place for this kind of metadata.

The real issue is that the status bar defaults to hidden. But that's
intentional — the design principle is "you shouldn't be able to tell you're
in a vanish session." Making the status bar auto-show for viewers breaks that
principle. And viewers who need to pan are exactly the users who will discover
the leader key (they'll press keys, see the hint bar, learn the bindings).

The fringe indicators (options A and B) are solutions looking for a problem.
They add visual noise, steal screen space, and fight with terminal content.
Every terminal multiplexer (tmux, screen) uses a status bar for this kind of
information, not viewport decorations. Vanish should follow that convention.

**Action: No code change.** The status bar already provides the information.
If this becomes a real user complaint, the fix is a config option to auto-show
the status bar for viewers, not viewport fringes.

#### Item 3: Flash indicator on viewer key press

**The problem:** When a viewer presses a non-leader key in the native TUI,
nothing happens. The key is silently consumed (client.zig:138 — the `else if
(self.role == .primary)` branch doesn't execute for viewers). The viewer
doesn't know why their input isn't working.

**Current behavior trace:**

1. Viewer presses `a` (not a leader key, not in leader mode)
2. `handleInput` calls `processKey(byte, is_ctrl)` — returns null (not a
   keybind)
3. `in_leader` is false — skip hint update
4. `role` is `.viewer` — skip input forwarding
5. Key is silently dropped. No feedback.

**Design exploration:**

Option A: **Brief status bar flash.** On non-leader key press by a viewer,
briefly show the status bar with "viewer" highlighted or show a brief message
like `"viewer — Ctrl+A t to take over"`. Clear it after the next output event
or after a short timeout.

This is the cleanest option. It reuses the existing status bar rendering. The
implementation would be: set a flag `viewer_input_flash`, render the status
bar with the hint, clear the flag on next output or after N output events.

No timer needed — terminal output is frequent enough that the flash will
naturally clear within a fraction of a second for active sessions. For idle
sessions, the flash persists until output occurs, which is fine — if the
session is idle, the status bar isn't obscuring dynamic content.

Option B: **Redirect viewer input to viewport navigation always.** Instead of
silently dropping non-keybind keys, treat them as viewport navigation. `h`
scrolls left, `j` scrolls down, etc. — without needing the leader key first.

Wait — re-reading the code, this is NOT what happens currently. The viewer's
non-leader keys are dropped at line 138 because `role != .primary`. The
viewport navigation keys (hjkl etc.) are handled through the keybind system
(leader+key → action). So a viewer who wants to pan must: press leader →
press h/j/k/l.

Is that right? Let me check the keybind config...

Actually, looking at client.zig:133, `processKey` is called for ALL input,
regardless of role. The keybind system is what determines if a key maps to an
action. If the viewer's config has direct bindings (without leader) for hjkl,
they'd work. But the default config uses leader+key for viewport navigation.

This is actually fine for primary users (you don't want hjkl intercepted when
typing in a shell). But for viewers — who can't type into the session
anyway — direct hjkl navigation would be natural.

**This is an interesting design question.** Should viewers have a different
default keybind set? When you're a viewer, the terminal content is read-only.
Every key that isn't a vanish keybind is wasted. Giving viewers direct hjkl
(and gg/G for top/bottom, u/d for page up/down) would make the viewing
experience much better without any downside — viewers can't type into the
session anyway, so there's no conflict.

**How would this work?** The keybind state (`keybind.State`) would need to
know the client's role, or the client would need to check: "if viewer AND key
isn't a keybind, try viewport navigation." This could be as simple as a
fallback in `handleInput`:

```
} else if (self.role == .viewer) {
    // Try viewport navigation for unbound keys
    if (tryViewerNav(byte)) |action| {
        self.executeAction(action);
        self.updateHint();
    }
    // else: show viewer flash
}
```

The `tryViewerNav` function maps hjkl → scroll actions, gg → scroll_top,
G → scroll_bottom, u/d → page up/down. Simple, stateless, no config needed.

**My assessment:**

Option B (viewer direct navigation) is the better answer. It solves the flash
indicator problem by making most viewer keys do something useful instead of
nothing. The flash is a band-aid for "your input was ignored." Direct
navigation means the input isn't ignored — it navigates. The remaining keys
(not navigation, not keybinds) could still show a brief viewer mode hint.

This combines two inbox items into one coherent solution:
- "flash indicator on viewer key press" → solved by making keys useful
- "fringe on pannable edges" → less needed when hjkl navigation is
  discoverable through the viewer's natural interaction

**Action: This is worth implementing.** It's a small change (~20 lines in
client.zig), doesn't affect the protocol or session model, and significantly
improves the viewer experience. A `tryViewerNav` function in client.zig that
maps ascii keys to viewport actions for viewers, called as a fallback when
`processKey` returns null and the role is viewer.

### Summary

The architecture review confirms the codebase is healthy and stable. +21 lines
since S91, no structural changes, no concerns.

The hammock produced a concrete recommendation: implement direct viewport
navigation for viewers (hjkl/gg/G/u/d without leader key). This solves two
inbox items at once — the key flash indicator becomes mostly unnecessary when
keys actually do something, and the fringe becomes less needed when navigation
is discoverable.

### Recommendations for next session

- **S95: Implement viewer direct navigation.** Add a `tryViewerNav` function
  to client.zig that maps hjkl/gg/G/u/d to viewport actions for viewer-role
  clients. ~20 lines. Also add a brief viewer mode flash for keys that don't
  map to any action ("viewer mode — Ctrl+A t to take over"). Update the spec
  and man page.
- Before implementing, test the fullscreen app viewer scenario (item 1) if the
  system is available. If `sendTerminalState` provides correct content on
  viewer connect, mark that item as resolved.
- The next 3-session architecture review checkpoint is S97.

## 2026-02-09: Session 93 - Alternate Screen Buffer Fix

### What was done

Fixed two inbox bugs at once: "The top line of a terminal on vanish new -a zsh
is a line from the output of a previous command still" and "are we properly
clearing/setting cursor on attach?"

**Root cause analysis:** When `Client.attach()` connected to a session, it set
raw mode but never cleared the screen. The user's existing terminal content
remained visible. When zsh started writing output (prompt, etc.), it overwrote
content from the cursor position down, but lines above the cursor — especially
the top line — retained stale content from the parent shell.

The PTY and terminal buffer themselves are clean (fresh `/dev/ptmx`, virgin
`VTerminal`). The problem was purely client-side: no screen clearing before
rendering session output.

**The fix:** Enter the alternate screen buffer (`\x1b[?1049h`) on attach, leave
it (`\x1b[?1049l`) on detach. This is the standard mechanism used by tmux,
screen, vim, less, and every well-behaved TUI application. It:

1. Saves the current screen content on enter
2. Provides a completely clean canvas (cursor at 1,1)
3. Restores the original screen content on leave

This is better than a simple `\x1b[2J\x1b[H` (clear screen + home) because the
user's pre-attach terminal history is preserved and restored when they detach.

**Files changed:**

- `src/client.zig`: +4/-1 — alternate screen enter/leave around the client loop
- `doc/spec.md`: +8 — new "Terminal State on Attach/Detach" section
- `doc/vanish.1`: +2 — note in `attach` description

**Committed:** `fix: use alternate screen buffer on attach/detach`

### Design consideration: why alternate screen, not just clear

- `\x1b[2J\x1b[H` (clear + home) destroys the user's terminal scrollback. When
  they detach, their previous commands and output are gone. Users expect `vanish
  attach` to behave like entering tmux — their shell history is waiting when
  they come back.
- The alternate screen buffer is the universally recognized way to do this.
  Every terminal emulator supports it. It's been standard since xterm.
- It also implicitly handles cursor state — the alternate screen starts with the
  cursor at (1,1), and the original cursor position is restored on leave. This
  addresses the second inbox item.

### Inbox status

After this session, the remaining unresolved inbox items are:

1. Fullscreen apps in smaller viewer sessions — redraw issue
2. Fringe on pannable edges — UX feature
3. Flash indicator on viewer key press — UX feature

All are UX enhancements. The two rendering bugs (stale top line, cursor on
attach) are now fixed.

### Recommendations for next session

- **S94 is the 3-session architecture review checkpoint** (3 sessions after
  S91). The review should be brief — the only code change since S91 is the
  alternate screen buffer fix (+4 lines in client.zig) and the self-join
  protection from S92.
- The remaining inbox items are UX features, not bugs. They can wait for usage.
- Consider a hammock session on the remaining inbox items: what would viewer
  panning fringe actually look like? What's the right UX for the key flash
  indicator? These benefit from design thinking before code.

## 2026-02-09: Session 92 - Self-Join Protection

### What was done

Implemented self-join protection — the inbox item "joining a session from
itself... breaks things and spins up fans." This was identified as low-hanging
fruit in S91 after `VANISH_SESSION` and `VANISH_SOCKET` env vars were added.

**The bug:** Running `vanish attach work` from within the `work` session would
attempt to attach the session to itself, creating infinite recursion (the
attached client reads output, which triggers more output, etc.) and causing high
CPU usage.

**The fix:** Added `isSelfSession(socket_path: []const u8) bool` to main.zig.
It checks two env vars:

1. `VANISH_SOCKET` — exact path comparison against the resolved socket path.
   This catches the common case and also handles path-based socket arguments.
2. `VANISH_SESSION` — basename comparison as fallback. This catches the case
   where the user specifies a different path that resolves to the same session.

`cmdAttach` calls `isSelfSession` after resolving the socket path but before
connecting. If it returns true, prints "Cannot attach to own session" and exits.

**Design decision: not protecting `cmdSend`.** `vanish send work "ls"` from
within the `work` session would fail with "Session already has a primary client"
(since the session already has a primary — the client that's running the
command). This is a clear error, not an infinite loop. Self-join protection is
unnecessary there.

**Files changed:**

- `src/main.zig`: `isSelfSession` function (+9 lines), check in `cmdAttach` (+4
  lines)
- `doc/spec.md`: documented self-join protection in Environment Variables
  section
- `doc/vanish.1`: note in `attach` description

**Committed:** `fix: prevent attaching to own session (self-join protection)`
(+21 lines across 3 files).

### Inbox status

After this session, the remaining unresolved inbox items are:

1. Top line of terminal on `vanish new -a zsh` — rendering artifact
2. Cursor clearing/setting on attach — needs investigation
3. Fullscreen apps in smaller viewer sessions — redraw issue
4. Fringe on pannable edges — UX feature
5. Flash indicator on viewer key press — UX feature

Items 1-3 are rendering bugs requiring hands-on testing. Items 4-5 are UX
enhancements. All remaining items are in the "future work driven by usage"
category.

### Recommendations for next session

- **S94 is the next 3-session architecture review checkpoint** (3 sessions after
  S91). S93 is free for other work.
- The remaining inbox items are all rendering/UX issues that would benefit from
  interactive testing rather than code reading. If the system is available for
  testing, investigate items 1-2 (terminal top line artifact, cursor on attach).
- Otherwise, consider a hammock session on what a v1.1 might look like — the
  last genuine hammock was S77, and S82 deferred it.
- The shell wrapper (`contrib/v.sh`) could benefit from self-join protection too
  — when `v work` is run inside the `work` session, the wrapper will call
  `vanish attach -p work`, which will now be caught by `isSelfSession`. This
  already works correctly without any wrapper changes.

## 2026-02-09: Session 91 - Environment Variables + Architecture Review

### What was done

**VANISH_SESSION and VANISH_SOCKET environment variables:**

Investigated the inbox bug "env vars don't seem to be getting copied over to the
child process." Analysis: the env inheritance path works correctly — `fork()`
preserves the address space including `std.c.environ`, and `childSetup` in
pty.zig falls back to `std.c.environ` when `null` is passed for the env
parameter. The parent environment is inherited.

The real gap was vanish-specific env vars. Implemented `setSessionEnv()` in
session.zig which calls libc `setenv()` in the session daemon (forked child)
before `pty.spawn()`. This sets:

- `VANISH_SESSION` — session name (e.g., `work`)
- `VANISH_SOCKET` — full socket path (e.g., `/run/user/1000/vanish/work`)

These propagate to the PTY child (shell) via `std.c.environ` on exec. Use cases:
shell prompt integration, scripts detecting vanish context, the self-join
protection (inbox item — can now check `$VANISH_SESSION` before attaching).

**Implementation detail:** `setenv` is not exposed in Zig 0.15's `std.c`, so
used an `extern "c"` declaration inside a local struct namespace. The function
copies the name/value into null-terminated stack buffers before calling setenv.

**Files changed:**

- `src/session.zig`: added `setSessionEnv()`, added `session_name` parameter to
  `run` and `runWithNotify`
- `src/main.zig`: thread `session_name` through `forkSession` to
  `Session.runWithNotify`
- `doc/spec.md`: new "Environment Variables" section, updated creation step 4
- `doc/vanish.1`: added VANISH_SESSION and VANISH_SOCKET to ENVIRONMENT section

**Committed:** `feat: set VANISH_SESSION and VANISH_SOCKET env vars in child
process` (+50/-7 across 4 files).

### Architecture Review (3-session checkpoint since S88)

#### Line Count Survey

| File         | Lines     | Change since S88 | Notes                           |
| ------------ | --------- | ---------------- | ------------------------------- |
| http.zig     | 1,101     | +0               | Stable                          |
| main.zig     | 1,029     | +3               | session_name threading          |
| client.zig   | 648       | +0               | Stable                          |
| auth.zig     | 585       | +0               | Stable                          |
| session.zig  | 555       | +17              | setSessionEnv + param additions |
| config.zig   | 461       | +0               | Stable                          |
| vthtml.zig   | 374       | +0               | Stable                          |
| terminal.zig | 348       | +0               | Stable                          |
| protocol.zig | 213       | +0               | Stable                          |
| keybind.zig  | 185       | +0               | Stable                          |
| naming.zig   | 165       | +0               | Stable                          |
| pty.zig      | 140       | +0               | Stable (no changes needed)      |
| signal.zig   | 48        | +0               | Stable                          |
| paths.zig    | 43        | +0               | Stable                          |
| **Total**    | **5,895** | **+20**          |                                 |

#### Architecture Health

Minimal growth: +20 lines across 2 source files. The new `setSessionEnv`
function is small (15 lines), self-contained, and has no dependencies beyond
libc's `setenv`. No new module imports. Dependency graph unchanged from S88.

The `extern "c"` pattern for `setenv` is slightly unusual but correct — libc is
linked, the function exists in every POSIX system. An alternative would be
building a modified environ array and passing it to `pty.spawn`, but that's
significantly more complex for zero benefit.

No decomposition candidates. No coupling concerns. No growth concerns.

### Inbox Status

After this session, the remaining unresolved inbox items are:

1. Top line of terminal on `vanish new -a zsh` — rendering artifact
2. Cursor clearing/setting on attach — needs investigation
3. Fullscreen apps in smaller viewer sessions — redraw issue
4. Fringe on pannable edges — UX feature
5. Flash indicator on viewer key press — UX feature
6. Self-join protection — can now be implemented using `$VANISH_SESSION`

Items 1-3 are rendering bugs that require hands-on testing. Items 4-5 are UX
enhancements. Item 6 is now straightforward with `$VANISH_SESSION`.

### Recommendations for next session

- **Self-join protection** is now low-hanging fruit: in `cmdAttach` (or
  `client.zig`), check if `$VANISH_SESSION` matches the session being attached
  to. If so, error with "Cannot attach to own session." This directly addresses
  the inbox item "joining a session from itself... breaks things."
- Alternatively, investigate one of the rendering bugs (items 1-3).
- The next 3-session architecture review checkpoint is S94.

---

> Earlier session notes (1-90) archived to
> [doc/sessions-archive.md](doc/sessions-archive.md).

<!-- Archive marker: S90 and earlier archived in S98. -->

