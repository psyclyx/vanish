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

Done (Session 65):

- ✓ Response to devil's advocate case for splitting index.html. Addressed all 7
  points. Key conclusions: the analogy to Zig file separation is false (HTML/CSS/
  JS in a browser is one deployment unit, not three independent concerns), 189
  lines across 6 subsystems is ~31 lines each (too small to warrant files), the
  globals are UI state (inherently shared), splitting requires non-trivial server
  changes (@embedFile is single-file, not directory-based), and testability
  gains are real but don't justify the cost for 8 lines of key-mapping code.
  Verdict: don't split. Reflection to be written in session 66.

Done (Session 64):

- ✓ Devil's advocate case for splitting index.html. 7-point argument examining:
  separation of concerns (3 languages in 1 file), JS complexity (6 subsystems in
  189 lines), global mutable state (11 globals), ES modules as zero-build-step
  alternative, marginal benefit of single HTTP request, testability, and
  threshold methodology. Response written in session 65.

Done (Session 63):

- ✓ Tagged v1.0.0. Committed outstanding work from sessions 58-62 in 4 logical
  commits (LICENSE+PKGBUILD, docs fixes, dual-bind fix, session notes), then
  created annotated tag. Build clean, 44 tests passing. PKGBUILD version
  derivation verified: `1.0.0.r0.ga5d7de1`.
- ✓ Devil's advocate topic identified for future: single-file web frontend
  (index.html at 312 lines). See notes below.

Done (Session 62):

- ✓ Pre-v1 documentation audit. README missing `--read-only`, `--daemon`,
  `--indefinite` from otp command table, and `--temporary`/`--session`/etc from
  revoke table. Fixed both.
- ✓ Man page: added `--read-only` flag to otp section. Fixed serve description.
- ✓ Fixed IPv6 dual-bind bug: `vanish serve` with default config only bound IPv4
  (127.0.0.1). The "listen on both localhost addresses" fallback was dead code.
  Restructured `start()` to bind IPv4 then best-effort IPv6 when using
  localhost. Also handles arbitrary addresses (try IPv4 then IPv6).
- ✓ Architecture review (3-session checkpoint since S60). http.zig 1,070→1,082
  (+12 from bind fix). Total 6,088. Zero TODO/FIXME/HACK. 44 tests. Build clean.
  13/15 files unchanged. No architectural issues. See notes below.

Done (Session 61):

- ✓ Devil's advocate reflection on http.zig splitting. Concluded the real
  question was about coupling, not file length. The coupling between SSE, auth,
  routing, and the event loop is essential (not incidental), so splitting would
  create the illusion of modularity without actual decoupling. Split trigger
  should be "understanding concern A requires understanding concern B," not a
  line count threshold. Debate cycle complete for this topic.
- ✓ Archived sessions 36-55 to doc/sessions-archive.md. prompt.md: 4,056 →
  ~1,100 lines. Condensed Done summaries for sessions 26-54 into a single
  paragraph. Removed resolved "OLD" section.

Done (Session 60):

- ✓ Architecture review (3-session checkpoint since session 57). Codebase at
  6,076 lines across 15 files (14 .zig + index.html at 312). 44 unit tests. Zero
  TODO/FIXME/HACK. Build clean. http.zig grew to 1,070 lines - assessed and
  determined it does NOT need splitting. Event loop grew by ~15 lines for
  session list clients, well-structured. validateAuth call sites now at 6 (was
  5). Remaining duplication unchanged and stable. No architectural issues found.
  Wrote "devil's advocate" section on the decision to keep http.zig monolithic.
  See detailed notes below.

Done (Session 59):

- ✓ Session list SSE. New `GET /api/sessions/stream` SSE endpoint pushes live
  session list updates to connected browsers. Server polls the socket directory
  every 2 seconds and sends events only when the list changes (Wyhash-based
  change detection). Refactored `handleListSessions` to share
  `buildSessionListJson` with the new SSE path, eliminating duplicated directory
  scanning code. Web frontend subscribes on auth instead of one-shot fetch.
  Session cards update live when sessions are created/destroyed. http.zig: 936 →
  1070 (+134 net, +184/-42 with dedup refactor). index.html: 304 → 312 (+8).

Done (Session 58):

- ✓ Arch PKGBUILD. Created `pkg/arch/PKGBUILD` for `vanish-git` AUR package.
  Uses `zig>=0.15` from official extra repo. `prepare()` fetches all zig deps
  (including lazy ghostty dep) via `zig build --fetch=all`. Builds with
  ReleaseSafe. Installs binary, man page, and LICENSE. Uses git-describe for
  version with fallback to rev-count. Also created LICENSE file (MIT).
- ✓ Rendering architecture redesign moved to done. Hammock iterations 1-3
  concluded: targeted fixes (resize re-render S55, cursor tracking S56) resolved
  the concrete bugs. Full redesign correctly rejected. Echo/noecho mode
  detection remains a potential future optimization with no bug reports driving
  it.

Done (Session 57):

- ✓ Architecture review (3-session checkpoint since session 54). Codebase at
  5,934 lines across 15 files (14 .zig + index.html at 304). 44 unit tests. Zero
  TODO/FIXME/HACK. Build clean. No new architectural issues found. See detailed
  notes below.

Done (Session 56):

- ✓ Fixed cursor position bug. Three fixes across native and web clients:
  1. dumpViewport (panning mode): cursor now positioned at correct location
     after rendering cells, adjusted for viewport offset.
  2. dumpScreen (full state transfer): TerminalFormatter now includes cursor
     position in VT output (was using .styles extra which omitted cursor).
  3. Web terminal: cursor position (cx/cy) now included in SSE JSON updates.
     Dedicated cursor element overlays the cell at cursor position. Also tracks
     cursor-only moves (no cell changes) via last_cursor_x/y on SseClient.
     terminal.zig: 335 → 351 (+16), vthtml.zig: 370 → 374 (+4), http.zig: 923 →
     936 (+13), index.html: 292 → 304 (+12). Net +45 lines.

Done (Session 55):

- ✓ Fixed TUI viewer resize re-render. Both session_resize (remote) and SIGWINCH
  (local) handlers now properly re-render after dimension changes. Session
  resize: resizes local VTerm if it exists, re-renders viewport in panning mode,
  clears screen in passthrough mode. Local resize: re-renders viewport in
  panning mode, updates status bar. client.zig: 636 → 648 (+12). This was the
  probable root cause of reported TUI viewer breakage (identified in hammock
  iteration 2, session 54).

Done (Sessions 26-58): See [doc/sessions-archive.md](doc/sessions-archive.md)
for detailed notes. Key milestones: HTML deltas (S26), web input fix (S32),
resize+measurement (S34), cell gaps (S35), Ctrl+Space (S36), status bar (S37),
auto-naming (S38-40), autostart serve (S41), main.zig dedup (S43), docs (S45),
mobile toolbar (S46/53), Nix fix (S47), browser perf (S50), read-only OTPs
(S52), XSS fix (S54), resize re-render (S55), cursor position (S56),
architecture review (S57), Arch PKGBUILD + LICENSE (S58).

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

## 2026-02-09: Session 64 - Devil's Advocate: Splitting index.html

### The Decision Under Examination

index.html is a single 312-line file containing all CSS (72 lines), HTML
structure (40 lines), and JavaScript (189 lines) for the web frontend. The
project has maintained this single-file approach since the beginning. It has been
informally assessed as "fine" multiple times but never formally debated. This is
the case for splitting.

### The Case for Splitting

**1. Three languages in one file is three concerns.**

The file contains CSS, HTML, and JavaScript. These are not one concern. CSS is
presentation. HTML is structure. JavaScript is behavior. The fact that the
browser can consume them in one file doesn't mean they belong together any more
than putting your Zig, build config, and man page in one file would be a good
idea.

The Zig codebase is meticulous about separation: terminal.zig doesn't contain
auth logic, protocol.zig doesn't contain HTTP routing. Each file has one job.
But index.html has three jobs. The single-file frontend is an anomaly in a
codebase that otherwise follows clean separation of concerns.

**2. The JS is doing real work.**

At 189 lines, the JavaScript isn't a trivial glue layer. It manages:

- Two SSE connections (session list, terminal stream) with lifecycle management
- A virtual terminal renderer with cell-level DOM manipulation and a cursor
  overlay
- Character measurement and resize handling (including visualViewport API)
- Keyboard input translation (including Ctrl modifier state machine, special
  key mapping, mobile toolbar integration)
- Auth flow (cookie reading, fetch probing, SSE-after-auth sequencing)
- Navigation state (auth → sessions → terminal → back to sessions)

That's 6 distinct subsystems in 189 lines. The code is compact because it's
well-written, not because the concerns are simple. Each subsystem has its own
state, its own event handlers, and its own failure modes. In the Zig codebase,
these would be separate files without question.

**3. Global state is the coupling mechanism.**

All JS state lives in module-level `let` declarations: `sse`, `isPrimary`,
`ctrlActive`, `termCols`, `termRows`, `charWidth`, `charHeight`,
`currentSession`, `cellMap`, `isReadOnly`, `sessionsSse`. That's 11 mutable
globals. Functions read and write these freely. `handleUpdate` reads `termCols`,
`termRows`, `charWidth`, `charHeight`. `sendResize` reads `currentSession`,
`isPrimary`, writes nothing but calls `measureChar` which mutates `charWidth`
and `charHeight`. `handleKey` reads `isPrimary`, `ctrlActive`, writes
`ctrlActive`.

This is the textbook definition of complected. Every function is implicitly
coupled to every other through shared mutable state. You can't understand
`handleKey` without knowing what sets `isPrimary`. You can't understand
`sendResize` without knowing what sets `currentSession`. In a single file this
is manageable because you can grep, but it's still complected. ES modules would
make the dependencies explicit.

**4. ES modules require no build step.**

The strongest argument for keeping a single file has been "no build step."
But `<script type="module">` and `<script type="module" src="...">` are natively
supported in every browser that supports EventSource (which is a hard
requirement anyway). You could split into:

```
static/
  index.html        (40 lines: structure only)
  style.css         (72 lines: presentation)
  js/
    main.js         (30 lines: init, auth flow, navigation)
    terminal.js     (80 lines: SSE, rendering, cursor, resize)
    input.js        (40 lines: keyboard, modifier bar)
    sessions.js     (30 lines: session list SSE, card rendering)
```

No bundler. No build step. No npm. Just files served by the same static file
handler that already serves index.html. The Zig server already serves static
files from an embedded directory - adding more files to that directory is free.

**5. The "one HTTP request" argument is weaker than it appears.**

The current setup saves ~3 HTTP requests on initial load compared to a
module-based split. But:

- HTTP/2 multiplexing (which any modern browser supports) means additional
  requests for small files have near-zero cost.
- The files would be tiny (30-80 lines each). Total transfer size identical.
- The server already handles static file serving.
- Caching: Split files cache independently. Changing one JS module doesn't
  invalidate the CSS cache.

The real benefit of one request is simplicity of deployment and embedding. But
the Zig server embeds static files at compile time - it doesn't matter if it's 1
file or 5 files. The deployment story is identical.

**6. Testability.**

The JS is currently untestable in isolation. You can't import `handleUpdate` into
a test harness because it's a global function in a `<script>` tag that depends on
DOM elements by ID. With ES modules, you could export pure functions
(`handleUpdate`, `handleKey`, key mapping logic) and test them. The key
translation logic in particular (lines 301-308) is dense and error-prone -
exactly the kind of code that benefits from unit tests.

**7. The 400-line threshold is arbitrary.**

Previous sessions set a "reconsider at ~400 lines" threshold. But the question
isn't about line count. The question is: does the current structure make
maintenance harder than it needs to be? At 312 lines with 11 mutable globals,
6 subsystems, and 3 languages, the answer is arguably yes - regardless of
whether it crosses some arbitrary threshold.

### What Splitting Would Cost

To be fair to the other side:

- **More files to navigate.** 4-5 files instead of 1. More tabs, more context
  switching.
- **Import/export ceremony.** ES module syntax adds boilerplate. Shared state
  needs to be explicitly passed or managed.
- **The embed changes.** The Zig `@embedFile` for the static directory would
  pick up new files automatically (it embeds the whole directory), but the
  static serving route would need to handle CSS and JS content types (it likely
  already handles HTML - needs verification).
- **Loses the "view source" simplicity.** Right now, right-click → View Source
  shows you everything. With modules, you'd need to click through imports.
- **Migration effort.** The globals would need to become module-level exports or
  be passed as arguments. This is refactoring work with risk of introducing
  bugs in a working system.

### Summary

The case for splitting rests on: (1) three concerns in one file violates the
project's own separation principles, (2) the JS is substantial enough to warrant
organization, (3) global mutable state is complected, (4) ES modules provide
organization without a build step, (5) the "one request" benefit is marginal,
(6) testability would improve, (7) the threshold should be about structure, not
line count.

**Response written in session 65 (see below).**

### Recommendations for Next Sessions

1. ~~**Session 65:** Write the response to this case.~~ Done.

2. **Session 66:** Reflection + architecture review (3-session checkpoint since
   S62).

---

## 2026-02-09: Session 65 - Response: The Case Against Splitting index.html

This is the response to the 7-point case made in session 64. Each point is
addressed directly.

### Point-by-Point Response

**1. "Three languages in one file is three concerns" — This analogy is wrong.**

The comparison to "putting Zig, build config, and man page in one file" is
misleading. Zig source, build.zig.zon, and a man page are consumed by different
tools at different times for different purposes. They have genuinely independent
lifecycles.

HTML, CSS, and JavaScript in a `<style>` and `<script>` tag are not like that.
They are one deployment unit, consumed together by one runtime (the browser), at
one time (page load), for one purpose (this specific UI). The browser's rendering
pipeline treats them as a single document. The `<style>` tag scopes CSS to the
document. The `<script>` tag has direct access to the DOM the HTML created and
the styles the CSS defined. They are designed to coexist in one file.

The Zig codebase separates files by _module boundary_: terminal.zig doesn't
import auth.zig. They have no dependency. But the JavaScript _must_ know about
the HTML structure (it queries elements by ID) and the CSS _must_ know about the
HTML structure (it targets classes). Splitting them into files doesn't remove the
coupling — it just makes you open three files to understand one page.

The real question isn't "how many languages?" but "how many independent things?"
The answer here is one: the vanish web frontend.

**2. "The JS is doing real work" — Yes, but the work is small.**

Six subsystems in 189 lines is ~31 lines per subsystem. Let's look at what each
one actually is:

- SSE connections: `openSse()` is 10 lines. `openSessionsSse()` is 6 lines.
- Terminal renderer: `handleUpdate()` is 34 lines.
- Char measurement + resize: `measureChar()` is 9 lines. `sendResize()` is 11 lines.
- Keyboard input: `handleKey()` is 8 lines. `toggleCtrl()` is 3 lines. Toolbar
  listener is 7 lines.
- Auth flow: 1 line (`fetch` + `then`).
- Navigation: `connect()` is 13 lines. `disconnect()` is 7 lines.
  `showSessions()` is 15 lines.

The case makes these sound like substantial subsystems. They're not. They're
short functions. The proposed split would create 4 JS files averaging 45 lines
each, plus import/export boilerplate. A 30-line `sessions.js` file that exports
two functions is not a meaningful module — it's a fragment.

In the Zig codebase, the smallest module is paths.zig at 43 lines, and it
exists because it's imported by 4 other modules. The proposed `sessions.js`
would be imported by one file (main.js) and export two functions. That's not
modular design — it's filing.

**3. "Global state is the coupling mechanism" — This misidentifies the problem.**

The 11 "mutable globals" are categorized as:

- _UI state_ (6): `isPrimary`, `ctrlActive`, `termCols`, `termRows`,
  `currentSession`, `isReadOnly`. These describe the current state of the UI.
  They are inherently shared because the UI is one thing.
- _Connection handles_ (2): `sse`, `sessionsSse`. These are the active SSE
  connections. They need to be accessible to connect/disconnect functions.
- _Rendering state_ (3): `charWidth`, `charHeight`, `cellMap`. These are
  caches used by the renderer.

The case says "you can't understand `handleKey` without knowing what sets
`isPrimary`." But `isPrimary` is set in exactly two places: `connect()` (to
false) and `takeover()` (to true). That's the entire lifecycle. In a 189-line
file, this is not hard to find.

ES modules would make the imports explicit, but they'd also make the state
management more complex. Either you pass state through function parameters
(threading 6+ variables through every call), create a shared state module (one
more file that everything imports — centralizing the globals with extra steps),
or use a class (which is just globals with `this.` prefix). None of these reduce
complexity. They relocate it.

The http.zig splitting debate (session 61) concluded that the right question is
"can you understand concern A without understanding concern B?" In this 189-line
file, yes. Each function is self-contained and short. The globals are simple
flags and dimensions, not complex nested state.

**4. "ES modules require no build step" — True, but they require server changes.**

The case states: "The Zig server already serves static files from an embedded
directory - adding more files to that directory is free."

This is factually wrong. The server uses `@embedFile("static/index.html")` to
embed a single file. There is no directory embedding. There is no general static
file server. The `handleIndex` function serves exactly one file with a hardcoded
`text/html` content type.

Splitting would require:

1. Changing `@embedFile` to embed multiple files (or using `@embedFile` once per
   file).
2. Adding content-type detection (`.css` → `text/css`, `.js` →
   `application/javascript`).
3. Adding a route that maps URL paths to embedded files.
4. Either embedding a directory listing at compile time or hardcoding the file
   list.

This is not "free." It's a new feature in the HTTP server — a static file
serving system that doesn't exist today. The current design (one embedded file,
one route) is simpler than any multi-file alternative. The case for splitting
the frontend implicitly requires complicating the backend.

**5. "The 'one HTTP request' argument is weaker than it appears" — Misframes the
benefit.**

The benefit of a single file is not "one HTTP request." The benefit is:

- One `@embedFile` call in the Zig source
- One route in the router
- One content type
- Zero path-traversal attack surface for static file serving
- Zero questions about cache headers for different file types
- Zero MIME type sniffing concerns

The case frames this as "one HTTP request vs four." The real comparison is "zero
static file serving infrastructure vs a static file server." The current design
has no concept of serving arbitrary files — that's an entire category of code
(and security surface) that doesn't exist.

HTTP/2 multiplexing is irrelevant because the server uses plain HTTP/1.1 on
localhost. The caching argument is irrelevant because the page sends
`Cache-Control: no-cache`.

**6. "Testability" — The only valid point, but insufficient to justify the cost.**

This is the strongest argument in the case, and it's genuinely true: the key
mapping logic (lines 306-307) is dense, error-prone, and untestable as-is. If
there were a bug in Ctrl+key translation or special key mapping, the only way
to test it would be manually in a browser.

However, the key mapping is 8 lines. The total "should really be tested" surface
is the key mapping object literal plus the Ctrl character computation. That's
not enough to justify a multi-file restructuring. If testability became a
priority, the minimal change would be to extract just the key mapping into a
separate `<script>` tag or a single external file — not a 4-file module system.

Also: the Zig backend has 44 unit tests. The frontend has zero — not because
it's untestable, but because it's a thin UI layer that's effectively tested by
using it. The ROI on frontend unit tests for a 189-line file with no complex
business logic is low.

**7. "The 400-line threshold is arbitrary" — Agreed, but the conclusion doesn't
follow.**

The case is right that the question isn't about line count. But if the question
is "does the current structure make maintenance harder than it needs to be?"
the answer is no. The file has been maintained across 40+ sessions with only
+8 lines of growth in the last 5 sessions. Every change has been straightforward
to make. No bug has been mislocated or hard to find. No change has required
understanding unrelated code.

The structure isn't making anything harder. The case identifies theoretical
concerns (complected state, separation of concerns) but can't point to a
concrete maintenance problem that splitting would solve, because there isn't one.

### What the Case Gets Right

Two things deserve acknowledgment:

1. **The key mapping logic should be tested.** Lines 306-307 are a one-liner
   that handles 14 special keys and a Ctrl modifier. A bug here would be silent
   and painful. But the fix is "add tests for this function," not "restructure
   into 5 files."

2. **The @embedFile assumption was a useful probe.** The case assumed the server
   had general static file serving. Discovering it doesn't reveals that splitting
   has a hidden cost that tips the balance further toward keeping the single
   file.

### Verdict

Don't split. The case for splitting rests on principles (separation of concerns,
explicit dependencies, testability) that are good principles — but the costs
they identify are theoretical, while the costs of splitting are concrete. The
single-file frontend works. It's maintained easily. The one genuine improvement
(key mapping tests) doesn't require splitting. The server would need a new
feature (static file serving) that adds complexity and attack surface.

The http.zig debate concluded that the split trigger is "understanding concern A
requires understanding concern B." The same test applies here. You can understand
`handleKey` without understanding `handleUpdate`. You can understand the CSS
without understanding the JavaScript. The concerns are collocated but not
complected.

**Reflection to be written in session 66 alongside architecture review.**

### Recommendations for Next Sessions

1. **Session 66:** Reflection on this debate + architecture review (3-session
   checkpoint since S62).

2. **Session 67:** If the reflection closes the debate cleanly, the project is
   in maintenance mode. Consider archiving sessions 56-60 to keep prompt.md
   lean.

---

## 2026-02-09: Session 63 - v1.0.0 Tag

### What Happened

Committed all outstanding work from sessions 58-62 and tagged v1.0.0.

**Commits made (4):**

1. `5711103` - add MIT license and Arch PKGBUILD (from S58)
2. `20cc9b0` - docs: fix missing flags in README and man page (from S62)
3. `5cd0093` - fix: bind both IPv4 and IPv6 on localhost by default (from S62)
4. `a5d7de1` - docs: session notes for sessions 61-62

**Tag:** `v1.0.0` on commit `a5d7de1`. Annotated tag with feature summary.

**Verification:**

- Build: clean
- Tests: 44 passing
- PKGBUILD `pkgver()`: produces `1.0.0.r0.ga5d7de1` (correct)

### Devil's Advocate Topic: Single-File Web Frontend

Session 62 identified this as the next unexamined decision. index.html is 312
lines with ~190 lines of JS. The project has maintained a single-file frontend
since the beginning, with the justification that it avoids build steps, module
loading, and extra HTTP requests.

**The case for splitting (to be written next session):**

This should examine: (1) whether the JS is outgrowing a single `<script>` tag,
(2) whether separating CSS/JS/HTML would improve maintainability, (3) whether
the "no build step" constraint is worth the cost, (4) whether ES modules
(`<script type="module">`) could provide organization without a build step.

### Post-v1 Direction

The project is tagged and complete. From here:

- Bug fixes only, driven by actual usage
- New features only if users request them
- Potential small additions: `vanish version`, shell completions,
  `vanish attach
  --last`, clipboard integration (OSC 52). None speculative.

### Recommendations for Next Sessions

1. **Session 64:** Devil's advocate case for splitting index.html.

2. **Session 65:** Response to the case.

3. **Session 66:** Reflection + architecture review (3-session checkpoint since
   S62). At this point, if there are no bug reports or feature requests, the
   project is in maintenance mode.

---

## 2026-02-09: Session 62 - Documentation Audit + Dual-Bind Fix + Architecture Review

### Documentation Audit

Systematically verified README, man page, and DESIGN.md against the actual
codebase. Found three classes of issues:

**README command tables (fixed):**

- `otp` was listed as `[--duration time] [--session name]` but actually supports
  5 flags: `--duration`, `--session`, `--daemon`, `--indefinite`, `--read-only`.
  Added `--read-only` to the table (the most user-facing omission). Kept
  `--daemon`/`--indefinite` omitted since they're advanced and the default
  (indefinite) is correct for most users.
- `revoke` was listed as `[--all]` but supports 5 flags. Added `--temporary` and
  `--session` to the table.

**Man page (fixed):**

- Serve command claimed "Default bind address is 127.0.0.1 and ::1" - was wrong
  (see dual-bind bug below). Updated to match reality after the fix.
- `otp` section was missing `--read-only` flag. Added with description.

**DESIGN.md:** Accurate. No changes needed.

### Dual-Bind Bug Fix

**The bug:** `vanish serve` with default config (no `--bind` flag) only bound to
IPv4 127.0.0.1. The code had a comment "Default: listen on both localhost
addresses" with a fallback path at lines 120-128, but this path was unreachable
because `cmdServe` defaults `bind_addr` to `"127.0.0.1"`, which matched the
first `if` branch and created only an IPv4 socket.

**The fix:** Restructured `start()` in http.zig:

1. Bind the explicitly requested address (IPv4 or IPv6).
2. If localhost, also bind the other protocol as best-effort (`catch null`).
3. If the address doesn't match any known pattern, try it as IPv4 then IPv6.
4. Fail only if neither socket was created.

This means `vanish serve` now listens on both 127.0.0.1 and ::1 by default. The
old fallback path was also buggy for arbitrary addresses (e.g., "192.168.1.5"
would silently bind to localhost instead). The new code correctly tries the
user's address.

**http.zig:** 1,070 → 1,082 (+12 lines).

### Architecture Review (3-session checkpoint since S60)

Sessions 61-62 were documentation/reflection work. Only code change was the
dual-bind fix in http.zig (+12 lines). 13/15 files unchanged.

| File         | Lines     | Change from S60 | Purpose                    |
| ------------ | --------- | --------------- | -------------------------- |
| http.zig     | 1,082     | +12             | Web server, SSE, routing   |
| main.zig     | 976       | 0               | CLI entry point            |
| client.zig   | 648       | 0               | Native client, viewport    |
| auth.zig     | 585       | 0               | JWT/HMAC, OTP exchange     |
| session.zig  | 526       | 0               | Daemon, poll loop          |
| config.zig   | 461       | 0               | JSON config parsing        |
| vthtml.zig   | 374       | 0               | VT→JSON, delta computation |
| terminal.zig | 351       | 0               | ghostty-vt wrapper         |
| index.html   | 312       | 0               | Web frontend               |
| protocol.zig | 192       | 0               | Wire format                |
| keybind.zig  | 185       | 0               | Input state machine        |
| naming.zig   | 165       | 0               | Auto-name generation       |
| pty.zig      | 140       | 0               | PTY operations             |
| signal.zig   | 48        | 0               | Signal handling            |
| paths.zig    | 43        | 0               | Shared utilities           |
| **Total**    | **6,088** | **+12**         | 15 files                   |

Build: Clean. Tests: 44 unit tests. All passing. Zero TODO/FIXME/HACK.

**Assessment:** Architecture remains clean. The dual-bind fix was the only issue
found during the documentation audit - a latent bug that never surfaced because
most systems connect via IPv4 anyway. No other architectural concerns.

### What's Working Well

Everything from the session 60 review holds. The codebase is stable. The only
change in 2 sessions was a 12-line bug fix found through documentation review -
which is exactly the kind of bug that pre-release audits are designed to catch.

### Remaining Duplication (unchanged)

All 4 duplication items from session 60 remain unchanged and stable. No action
needed.

### v1 Readiness

After this session:

- Documentation is accurate (README, man page, DESIGN.md all verified)
- The one bug found during audit (dual-bind) is fixed
- Build clean, 44 tests passing, zero markers
- All inbox items resolved

**The project is ready for v1 tag.** Next session should tag it.

### Recommendations for Next Sessions

1. **Session 63:** Tag v1.0.0. `git tag -a v1.0.0 -m "v1.0.0"`. Consider if the
   Arch PKGBUILD version derivation works with the new tag.

2. **Session 64:** Post-v1. Only work driven by actual usage. Possible:
   `vanish
   version`, shell completions, `vanish attach --last`.

3. **Devil's advocate topic for future sessions:** The decision to keep the web
   frontend as a single HTML file (now 312 lines). This hasn't been formally
   debated yet - just informally assessed as "fine for now." Worth a proper
   pro/con analysis at some point.

---

## 2026-02-09: Session 61 - Devil's Advocate Reflection + Archive Cleanup

### Reflection: The http.zig Splitting Decision

Session 60 wrote the case for splitting http.zig and a response. This is the
reflection - stepping back from both positions to find the real truth.

**The case was:** (1) Cognitive load at 1,070 lines, (2) growth trajectory as
the only file that consistently grows, (3) zero test coverage with test
isolation impossible, (4) event loop as a God function.

**The response was:** (1) Clear internal structure mitigates load, (2) growth is
slowing with no new features planned, (3) SSE logic is too coupled to HTTP
lifecycle to test in isolation, (4) 136 lines for 4 client types is reasonable.

**The reflection:**

Both sides are mostly right, and the disagreement is actually about _when_, not
_whether_. The case for splitting describes real costs that accumulate. The
response correctly notes those costs aren't painful _today_. The question is
whether the current decision creates a trap - a file that's increasingly
expensive to split the longer you wait.

The answer is: not really. And here's why.

The coupling argument cuts both ways. The case says "extract SSE for
testability." The response says "SSE is too coupled to extract cleanly." But the
_reason_ SSE is coupled to the HTTP server is because it genuinely is one
concern. Terminal SSE streaming isn't a separable abstraction from "HTTP server
that serves terminal sessions." The SSE clients are managed by the event loop,
authenticated by the auth system, routed by the router, and connected to
sessions through shared socket utilities. This isn't incidental coupling that
could be refactored away - it's essential coupling. The server _is_ these things
working together.

The test isolation argument is the strongest one for splitting, but it points at
the wrong solution. The right approach for testing http.zig would be integration
tests (start server, connect client, verify behavior), not unit tests on
extracted modules. The SSE delta logic is already tested via vthtml.zig tests.
The auth logic is tested via auth.zig tests. What's untested is the plumbing -
and plumbing is best tested by running it.

The God function concern (eventLoop at 136 lines) is worth watching but not
acting on. Poll-based event loops are inherently linear: check each fd type,
handle events, repeat. The 136 lines aren't doing 136 lines worth of logic -
they're dispatching to handlers. This is the nature of a multiplexer's main
loop. Splitting the dispatch by client type into separate functions would just
move the complexity into function call overhead without reducing it.

**What I got wrong in previous reviews:** Repeatedly flagging line count
thresholds (1,000, 1,500) as if line count is the metric. It's not. The metric
is: can you understand any single concern without understanding all the others?
In http.zig, yes. Each handler is self-contained. The event loop is linear. The
shared utilities are obvious. The file is long, but it's not complex.

**What I got right:** Not splitting. Every review since session 42 has concluded
"leave it." Each time, the concerns were real but the costs of splitting were
higher than the costs of staying monolithic. This is still true.

**Final verdict:** http.zig stays monolithic. The split trigger isn't a line
count - it's when a developer needs to understand concern A but is forced to
understand concern B first. That hasn't happened. If a new concern is added that
creates a genuinely independent responsibility (e.g., WebSocket support with a
different protocol), that's when splitting makes sense. Not before.

The devil's advocate cycle is complete for this topic. This was a good exercise

- it clarified that the real question was about coupling, not file length.

### Archive Cleanup

Archived sessions 36-55 from prompt.md to doc/sessions-archive.md. The archive
now covers sessions 1-55. prompt.md went from 4,056 to ~1,070 lines. Condensed
the Done summaries for sessions 26-54 into a single paragraph with key
milestones. Removed the "OLD" section (all items resolved long ago).

Active session notes retained: 56-60 (plus this session, 61).

### v1 Assessment

Session 60 recommended considering a v1 tag. The assessment stands:

- All inbox items resolved
- All features from the task description implemented
- Codebase stable (13/15 files unchanged for 10+ sessions)
- Documentation current (README, DESIGN.md, man page)
- Packaging done (Nix, Arch)
- 44 tests, zero TODO/FIXME/HACK, clean build

The project is v1. What remains is driven by actual usage, not speculation.

### Inbox Status

No remaining items. Project at v1.

### Recommendations for Next Sessions

1. **Session 62:** Final polish pass before v1 tag. Verify README accuracy,
   verify man page accuracy, verify DESIGN.md accuracy. Run a manual smoke test
   of the full workflow. If everything checks out, tag v1.

2. **Session 63:** Post-v1. Consider: `vanish version` command, shell
   completions, or `vanish attach --last`. Only if driven by usage.

3. **Session 63 (review):** Architecture review (3-session checkpoint since
   session 60).

---

## 2026-02-09: Session 60 - Architecture Review (3-session checkpoint)

### Architecture Review

Last review was session 57. Sessions 58-59 were the Arch PKGBUILD/LICENSE and
session list SSE respectively.

### Codebase Stats

| File         | Lines     | Change from S57 | Purpose                    |
| ------------ | --------- | --------------- | -------------------------- |
| http.zig     | 1,070     | +134            | Web server, SSE, routing   |
| main.zig     | 976       | 0               | CLI entry point            |
| client.zig   | 648       | 0               | Native client, viewport    |
| auth.zig     | 585       | 0               | JWT/HMAC, OTP exchange     |
| session.zig  | 526       | 0               | Daemon, poll loop          |
| config.zig   | 461       | 0               | JSON config parsing        |
| vthtml.zig   | 374       | 0               | VT→JSON, delta computation |
| terminal.zig | 351       | 0               | ghostty-vt wrapper         |
| index.html   | 312       | +8              | Web frontend               |
| protocol.zig | 192       | 0               | Wire format                |
| keybind.zig  | 185       | 0               | Input state machine        |
| naming.zig   | 165       | 0               | Auto-name generation       |
| pty.zig      | 140       | 0               | PTY operations             |
| signal.zig   | 48        | 0               | Signal handling            |
| paths.zig    | 43        | 0               | Shared utilities           |
| **Total**    | **6,076** | **+142**        | 15 files                   |

Build: Clean. Tests: 44 unit tests across 9 files. All passing.

The +142 line growth since session 57 is entirely from session list SSE (+134 in
http.zig, +8 in index.html). 13 of 15 files unchanged. The growth was well-
contained: one new SSE concern added to the existing HTTP server.

### What's Working Well

**1. Core stability is absolute.** Protocol, session, terminal, pty, signal,
paths, auth, config, keybind, naming, main, vthtml, client - 13 modules
unchanged since session 57 or earlier. Most haven't changed in 10+ sessions.
These are finished code.

**2. Session list SSE landed cleanly.** The new feature added a 4th struct
(SessionListClient), 4 new functions, and ~15 lines to the event loop. It reused
the existing patterns (SSE headers, poll-based multiplexing, auth validation)
without modifying them. The buildSessionListJson extraction actually reduced
duplication from the existing handleListSessions.

**3. Zero TODO/FIXME/HACK markers.** Still clean.

**4. No inbox items remain.** Every feature request, bug report, and polish item
from the inbox has been resolved. The project has reached feature completeness.

### http.zig at 1,070 Lines - Does It Need Splitting?

This is the main question for this review. http.zig is now the largest file by a
significant margin (1,070 vs main.zig at 976). It grew 134 lines in session 59.

**Structural analysis of http.zig concerns:**

1. Server core & initialization (lines 1-150): 150 lines
2. Event loop (lines 152-287): 136 lines
3. HTTP I/O (lines 289-334): 46 lines
4. Request routing (lines 336-409): 74 lines
5. Static serving (lines 411-423): 13 lines
6. Auth endpoint (lines 425-473): 49 lines
7. Session list one-shot (lines 475-489): 15 lines
8. Terminal control endpoints (lines 491-618): 128 lines
9. Terminal SSE streaming (lines 620-824): 205 lines
10. Session list SSE streaming (lines 826-946): 121 lines
11. Auth validation (lines 948-965): 18 lines
12. Response helpers & socket utils (lines 967-1070): 104 lines

**Assessment: No split needed.**

The file has one clear responsibility: HTTP server. All 12 sections serve that
responsibility. The event loop coordinates all client types. The routing
dispatches to handlers. The handlers use shared auth, response, and socket
utilities. Splitting would force inter-module communication for things that are
currently simple method calls on `*HttpServer`.

Where would you split? The most natural boundary would be terminal SSE (section
9) and session list SSE (section 10) into separate files. But both depend on:

- HttpServer struct (client lists, alloc, auth, config)
- validateAuth
- sendError / sendJson
- connectToSession
- The event loop (poll fd management)

Extracting them would require either passing HttpServer pointers around (which
is what method calls already do) or creating an interface/callback system (which
adds complexity). The benefit would be shorter files. The cost would be more
files to navigate, more import lines, and the illusion of modularity without
actual decoupling.

**The file is 1,070 lines with clear internal structure. Every function is small
(largest is eventLoop at 136 lines). Navigation is straightforward. Leave it.**

### Devil's Advocate: The Case for Splitting http.zig

_Per the ongoing request to interrogate decisions:_

**The case for splitting:**

1. **Cognitive load.** 1,070 lines is a lot to hold in your head. When debugging
   terminal SSE, you don't care about session list SSE or auth endpoints. A
   developer opening http.zig for the first time faces a 1,070-line wall.

2. **Growth trajectory.** http.zig was 898 lines at session 42, then 923, then
   936, now 1,070. It's the only file that consistently grows. Every new web
   feature lands here. If a future feature adds another SSE concern (e.g.,
   streaming session logs), it adds another 100+ lines.

3. **Test isolation.** http.zig has zero tests. It's the largest file with zero
   test coverage. If the SSE streaming logic were in a separate module, it could
   be tested against mock data without needing a full HTTP server.

4. **The event loop is a God function.** At 136 lines, it manages 4 different
   client types, 6+ index calculations, and dispatches to 5+ handlers. This is
   the most complex function in the codebase. Splitting client types into
   separate modules with their own poll handling could simplify it.

**Response (next session should reflect on this):**

These are real concerns. The counter-arguments:

1. Cognitive load: mitigated by clear internal section structure and small
   functions. Reading eventLoop → handler → utility is linear, not nested.

2. Growth trajectory: true, but the growth is slowing. Session list SSE was the
   last planned web feature. No new SSE concerns are on the horizon.

3. Test isolation: valid. But the SSE streaming logic is tightly coupled to the
   HTTP lifecycle (poll fds, client management, protocol reading). Extracting it
   for testing would require mocking most of what makes it work.

4. God function: 136 lines for a poll-based event loop managing 4 client types
   is not unreasonable. Each client type's handling is 10-20 lines. The
   complexity is inherent to multiplexed I/O, not incidental.

The split would be warranted if: (a) http.zig crosses 1,500 lines, (b) a new SSE
concern is added, or (c) testability becomes a priority. None of these
conditions exist today.

### Remaining Duplication (unchanged, stable)

1. **connectToSession (3 copies):** main.zig:666, http.zig:1061, client.zig:588.
   ~8 lines each. Still not worth extracting.

2. **Auth validation pattern (6 copies in http.zig):** Lines 476, 492, 528, 584,
   623, 829. Up from 5 (session list stream added one). Each ~4 lines. The
   pattern is consistent and grep-friendly. Not worth a middleware abstraction.

3. **Scroll actions (8 copies in client.zig):** Lines 173-212. Stable. Leave it.

4. **TCP socket creation (2 copies in http.zig):** createTcpSocket4 and
   createTcpSocket6. Stable. Leave it.

### Simple vs Complected Analysis

**Simple (good):**

- Everything from session 57 remains simple.
- Session list SSE: simple design. Poll directory, hash JSON, compare, send if
  changed. No inotify, no file watchers, no pubsub. Just a timer and a hash.
- The SessionListClient struct is 12 lines. Minimal state.
- buildSessionListJson shared between one-shot and SSE paths. Clean extraction.

**Watch items:**

- **index.html at 312 lines.** Previous reviews flagged 250-280 as the threshold
  for considering a JS split. We're past it. The JS section is ~190 lines. But
  the code remains readable - functions are short, no framework state, linear
  flow. The same assessment from session 57 holds: the benefit of a single file
  (no build step, no module loading, one HTTP request) outweighs the cost at
  this scale. Would reconsider past ~400 lines.

- **eventLoop at 136 lines.** Largest function in the codebase. The session list
  client disconnect loop (lines 272-283) is nearly identical to the pattern in
  the SSE client loop. If a third client type were added, extracting a generic
  "check for disconnect and remove" helper would be warranted. Not yet.

**No complected code found.** Architecture remains clean.

### The v1 Question

All inbox items are resolved. All features from the task description are
implemented. The project has:

- Core terminal multiplexing with libghostty
- Session management (create, list, attach, detach, kill, kick, clients)
- Native client with leader key, status bar, viewport panning, scrollback
- Web access with JWT/OTP auth, SSE streaming, delta rendering, resize
- Read-only tokens, mobile toolbar, live session list
- Auto-naming, auto-serve
- Config file, man page, README
- Nix package, Arch PKGBUILD

What remains for a "v1 tag":

1. **Confidence in correctness.** The codebase has been stable for many
   sessions. Bug reports are resolved. No known issues.

2. **Documentation completeness.** README, DESIGN.md, and man page are all
   current.

3. **Packaging.** Nix and Arch both work.

4. **The "pride" question.** The user asked "what would make you proud?" The
   honest answer: this codebase is already something to be proud of. 6,076 lines
   for a terminal multiplexer with web access, clean architecture, zero tech
   debt markers, stable for 20+ sessions. The economy of design - 15 files, 44
   tests, 17 protocol message types - is the kind of minimalism that lasts.

**Recommendation:** Tag v1. The project is done. Future work should be driven by
actual usage and bug reports, not speculative features.

### Hammock: What Would Make This Even Better?

Since the project is feature-complete, the "pride" hammock shifts from "what's
missing" to "what's excellent."

**What's excellent:**

- The protocol. 5-byte header, 17 message types. Simple enough to implement in
  any language. No versioning needed because there's nothing to version.
- The naming system. "dark-knot-zsh" is delightful.
- The auth design. OTP → JWT exchange is simple, stateless on the server after
  exchange, no database.
- The delta streaming. Cell-level diffs, hash-based change detection. Minimal
  data on the wire.
- The single-file frontend. 312 lines of vanilla JS, no dependencies, no build
  step. Loads instantly.

**What could be polished (if driven by usage):**

- A `vanish version` command that prints build info
- Shell completions (bash, zsh, fish)
- A `vanish attach --last` to reattach the most recently detached session
- Clipboard integration (OSC 52) in the web terminal

None of these are worth doing speculatively. They'd be worth doing if users
request them.

### Inbox Status

| Item         | Status | Priority | Notes                      |
| ------------ | ------ | -------- | -------------------------- |
| All features | ✓ Done | -        | Project at v1              |
| Architecture | ✓ Done | -        | Session 60 review complete |

No remaining inbox items.

### Recommendations for Next Sessions

1. **Session 61:** Devil's advocate reflection. The case for splitting http.zig
   was written above. Next session should write the reflection on that debate.
   Also: consider whether to tag v1. The project meets all stated requirements.

2. **Session 62:** If tagging v1, do final polish pass: verify README accuracy,
   verify man page accuracy, verify DESIGN.md accuracy. Run a manual smoke test
   of the full workflow (create session, web access, viewer, takeover, kill).

3. **Session 63:** Archive sessions 43-55 to doc/sessions-archive.md. The prompt
   file is getting long. Keep sessions 56-60 in the active notes.

---

## 2026-02-09: Session 59 - Session List SSE

### What Changed

Implemented reactive session list for the web frontend. When sessions are
created or destroyed from the terminal, the browser's session list updates live
without page reload. This was the last major web UX gap.

**http.zig (936 → 1070 lines, +134 net)**

**New struct: `SessionListClient` (12 lines)**

Much simpler than `SseClient` - no VTerminal, no screen buffer, no session
socket. Just the HTTP fd for writing SSE events, a hash of the last-sent session
list for change detection, and the auth scope/filter for session-scoped tokens.

**New handler: `handleSessionListStream()` (30 lines)**

Route: `GET /api/sessions/stream`. Validates auth, sends SSE headers, sends
initial session list event, then transfers the client from the regular HTTP
client list to the `session_list_clients` list. Same lifecycle pattern as
`handleSseStream()` for terminal streams.

**New helper: `buildSessionListJson()` (33 lines)**

Extracted the directory scanning + JSON building logic that was inline in
`handleListSessions()`. Now shared between the one-shot `handleListSessions()`
endpoint and the SSE stream. This eliminated ~30 lines of duplicated code from
`handleListSessions()`, which is now just 10 lines (validate auth, call helper,
send response).

**New helper: `sendSessionListEvent()` (9 lines)**

Writes an SSE event using `writev()` to combine the event prefix, JSON payload,
and suffix in a single syscall. Avoids allocating a concatenated buffer.

**New function: `updateSessionListClients()` (24 lines)**

Called on every event loop iteration (and on timeout). Throttled to scan at most
every 2 seconds via `last_session_scan` timestamp. For each connected session
list client, builds the JSON, hashes it with Wyhash, and compares against the
last-sent hash. Only sends an event when the hash changes.

**New function: `removeSessionListClient()` (4 lines)**

Cleanup: close fd, free filter, remove from list.

**Event loop changes (+22 lines)**

- Session list client fds added to poll (listen for disconnect only)
- Timeout condition includes session list clients (not just terminal SSE)
- Disconnect detection loop after the terminal SSE loop
- `updateSessionListClients()` called both on timeout and after event handling

**Refactored: `handleListSessions()` (-20 lines)**

Now delegates to `buildSessionListJson()` instead of doing inline directory
scanning. 30 lines → 10 lines.

**index.html (304 → 312 lines, +8)**

- `sessionsSse` variable tracks the session list EventSource.
- `openSessionsSse()`: Creates EventSource to `/api/sessions/stream`, listens
  for `sessions` events.
- Auth check flow: `fetch('/api/sessions')` still used as auth probe (can't
  distinguish 401 from network error on EventSource). If auth succeeds, opens
  the SSE stream instead of using the fetch response data.
- `showSessions()` simplified: no longer async, no longer unwraps a promise.
  Called directly from the SSE event handler with parsed JSON.
- `disconnect()`: Reopens session list SSE if it was closed while viewing a
  terminal (error recovery).

### Design Decisions

- **Poll-based, not inotify:** Directory scan every 2 seconds is simple and
  correct. inotify would add Linux-specific code, edge cases around socket
  creation timing, and complexity for marginal latency improvement. 2-second
  resolution is responsive enough for session creation/destruction.

- **Wyhash for change detection:** Instead of maintaining a sorted list of
  session names and doing set comparison, hash the entire JSON output. If the
  hash matches the last-sent hash, skip. Simple, O(n) where n is JSON length, no
  additional data structures. False negatives (hash collision causing a missed
  update) are astronomically unlikely with 64-bit Wyhash, and the next scan 2
  seconds later would catch it.

- **Auth check before SSE:** EventSource API doesn't expose HTTP status codes. A
  401 response just triggers the `onerror` handler, indistinguishable from a
  network error. So the auth check is done via a regular fetch first, and the
  SSE stream is only opened after successful auth.

- **SSE stays open while viewing terminal:** The session list SSE connection
  persists even when the user navigates to a terminal view. When they disconnect
  from the terminal, the session list is already current. If the SSE connection
  dropped in the meantime, `disconnect()` reopens it.

- **writev for SSE events:** `sendSessionListEvent` uses `writev()` with 3
  iovecs (prefix, json, suffix) instead of allocating a concatenated buffer.
  Avoids one allocation per event.

- **Scope-aware updates:** Session-scoped tokens only see the sessions they're
  authorized for. The `SessionListClient` stores the scope and filter, and
  `buildSessionListJson` applies the same filtering as the one-shot endpoint.

### Line Count Impact

| File       | Before | After | Change   |
| ---------- | ------ | ----- | -------- |
| http.zig   | 936    | 1070  | +134     |
| index.html | 304    | 312   | +8       |
| **Net**    |        |       | **+142** |

Total codebase: 15 files, ~6,076 lines.

### Testing

- Build: Clean
- Unit tests: 44 tests, all passing

### Inbox Status

| Item               | Status | Priority | Notes                          |
| ------------------ | ------ | -------- | ------------------------------ |
| Session list SSE   | ✓ Done | -        | Session 59                     |
| All major features | ✓ Done | -        | Project at v1 feature-complete |

### Recommendations for Next Sessions

1. **Session 60 (review):** Architecture review (3-session checkpoint since
   session 57). http.zig grew from 936 to 1070 lines - assess whether it needs
   splitting. Assess whether the project is "done" for v1. index.html at 312
   lines - re-evaluate split threshold.

2. **Session 61:** Consider what "v1" means. Tag a release? Update README to
   reflect completeness? The project has no remaining inbox items. All features
   from the task description are implemented. This is a good time to step back
   and evaluate.

3. **Session 62:** Hammock: the ongoing request about "what would make you
   proud." With all features done, this is about polish, correctness, and the
   user experience of the codebase itself (for future maintainers).

---

> Earlier session notes (1-58) archived to
> [doc/sessions-archive.md](doc/sessions-archive.md).
