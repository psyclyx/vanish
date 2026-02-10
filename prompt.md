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

- fullscreen apps in smaller viewer sessions require the primary to force a
  redraw before it pans. S94 analysis: likely not a real bug — `sendTerminalState`
  should provide correct content on viewer connect. Needs testing to confirm.
- spend many iterations hammocking about the problem. it's complete - but could
  it be better? what would make you proud to have done in this codebase?

All other inbox items resolved. See session archive for details: web viewer
keyboard/hints/stale sessions (S97), alternate screen buffer (S93), viewport
fringes rejected (S94/S95), viewer direct navigation (S95), env vars (S91),
self-join protection (S92), TUI resize (S55), browser input/perf (S49/S50),
read-only OTPs (S52).

Current:

- None. v1.0.0 tagged. Future work driven by usage.

Done (Sessions 1-105): See [doc/sessions-archive.md](doc/sessions-archive.md).
Key milestones: HTML deltas (S26), web input fix (S32), cell gaps (S35), status
bar (S37), auto-naming (S38-40), docs (S45), browser perf (S50), read-only OTPs
(S52), resize fix (S55), PKGBUILD+LICENSE (S58), v1.0.0 tag (S63), protocol
debate + struct tests (S67-69), function decomposition (S70-75), UX hammock
(S77), socket clobbering fix (S78), session model debate (S80-82), completions
(S83-84), otp --url (S85), spec audit + bug fixes (S86-87), shell wrappers
(S90), env vars (S91), self-join protection (S92), alternate screen buffer (S93),
viewer direct navigation (S95), web viewer fixes (S97), challenge/response/
reflection cycle (S99-S101), accepted refactors + tests (S102), archive cleanup
+ spec audit (S103), architecture pre-review (S104), architecture review +
refactors (S105).

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
  **Done in S103.**

## 2026-02-09: Session 103 - Archive Cleanup + Spec Audit

### What was done

**Archived S91-S101 to sessions-archive.md.** Each session received a condensed
summary paragraph matching the existing archive format. Archive header updated
from "Sessions 1-90" to "Sessions 1-101". prompt.md reduced from ~1,847 lines
to ~240 lines.

**Cleaned up inbox.** Removed 15 resolved items (all marked ✓), leaving only
two active items: the fullscreen app viewer testing item and the ongoing
hammock prompt. Added a brief summary of resolved items with session references.

**Spec audit.** Verified doc/spec.md against all code-changing commits since
S88 (the last spec sync). All four feature commits (S91 env vars, S92
self-join, S93 alternate screen, S95 viewer navigation) updated the spec in
the same commit. Cross-checked CLI commands, HTTP endpoints, and protocol
message types against source — zero gaps found. Spec is fully synchronized.

**Updated Done section.** Merged the two-part Done summary into a single section
covering S1-S102 with key milestones listed.

**Files changed:**

- `prompt.md`: -1,607 lines (archiving + inbox cleanup)
- `doc/sessions-archive.md`: +67 lines (11 session summaries)

### Recommendations for next session

- **S105 is the next 3-session architecture review checkpoint.**
- One inbox item remains: fullscreen apps in smaller viewer sessions (needs
  interactive testing).
- The ongoing hammock prompt ("could it be better?") was addressed by the
  S99-S101 challenge cycle. No new items have emerged since.
- prompt.md is now lean at ~240 lines. No archiving needed for many sessions.

## 2026-02-09: Session 104 - Architecture Pre-Review

Full review of every source file. Identified 5 concrete candidates for S105:
(1) connectToSession duplication, (2) auth pattern duplication in http.zig,
(3) http.zig event loop poll index complexity, (4) vthtml loop duplication,
(5) writeAll duplication. Simplicity scorecard: 10 components rated "Yes",
3 "Mostly", 1 "No" (http.zig). Architecture is sound overall. See git history
for full analysis.

## 2026-02-09: Session 105 - Architecture Review + Refactors

### What was done

**3-session architecture review checkpoint.** Evaluated all 5 items from S104.

**Accepted and implemented:**

1. **`connectToSession` → `paths.zig`.** Moved the identical 5-line function
   from both `main.zig` and `http.zig` to `paths.zig`. Both callers now use
   `paths.connectToSession()`.

2. **`requireWriteAuth` helper in `http.zig`.** Extracted the 3× repeated
   pattern (validateAuth + read_only check + session scope check) into a single
   `requireWriteAuth` method returning `!?Auth.TokenPayload`. The three write
   endpoints (`handleInput`, `handleResize`, `handleTakeover`) each collapsed
   from ~19 lines of auth boilerplate to 2 lines:
   `const payload = try self.requireWriteAuth(client, headers, session_name) orelse return;`

**Rejected with rationale:**

3. **http.zig event loop simplification.** The poll index arithmetic is fragile
   but stable and tested. A tagged-union approach would add allocation and
   complexity for marginal clarity. The fragility is contained to one function.
   Not worth the churn.

4. **vthtml loop duplication (~30 lines).** The two functions are adjacent and
   easy to keep in sync. Parameterizing would make each harder to read for a
   small dedup gain.

5. **writeAll duplication (9 lines).** Different semantic contexts (general I/O
   vs protocol internals). Making `writeAllFd` public would create a dependency
   from main→protocol for a utility function.

**Files changed:**

- `src/http.zig`: 1,101 → 1,065 (-36) — requireWriteAuth helper, removed
  connectToSession + 3× auth pattern
- `src/main.zig`: 1,089 → 1,079 (-10) — removed connectToSession, updated call
- `src/paths.zig`: 43 → 53 (+10) — added connectToSession

### Line count

| File | Lines | Change |
|------|-------|--------|
| http.zig | 1,065 | -36 |
| main.zig | 1,079 | -10 |
| paths.zig | 53 | +10 |
| **Total Zig** | **5,994** | **-36** |

### Updated simplicity scorecard

| Component | Simple? | Notes |
|-----------|---------|-------|
| http | Mostly | Auth dedup done; event loop still complex but stable |

http.zig moves from "No" to "Mostly". The auth duplication was the primary
smell; now only the event loop poll indexing remains as a concern, and it's
deliberately left alone.

### Next architecture review

S108 (3 sessions from now). The codebase is at 5,994 lines with 53 tests.
Two review cycles (S99-S102 challenge/response, S104-S105 architecture) have
confirmed the design is sound. Future reviews should be lighter unless new
features are added.

### Recommendations for next session

- The fullscreen app viewer inbox item still needs interactive testing.
- No code changes warranted. The system is stable at v1.0.0.
- Next architecture review: S108.

## 2026-02-09: Session 106 - Hammock: What Would Make Me Proud

### The prompt

"It's complete — but could it be better? What would make you proud to have done
in this codebase?"

I re-read every source file. Not skimming — actually reading, tracing the flow,
sitting with it. Here's what I found.

### What I'm genuinely proud of

**The protocol is right.** 10 structs, 17 message types, no version negotiation
needed because client and server are the same binary. Native byte order because
it's same-host UDS. Struct sizes pinned by comptime tests. This is the kind of
decision that sounds reckless until you realize UDS *guarantees* same-host, and
the simplicity it buys is enormous. No serialization library, no protobuf, no
schema evolution headaches. The protocol file is 213 lines and hasn't needed
significant changes since S67.

**The session model is clean.** One primary, N viewers, PTY multiplexing with
terminal state tracking. The core `session.zig` is 559 lines and does exactly
one thing. No configuration, no policies, no optional behaviors — it's a
session. The event loop is straightforward poll(). The Client struct is 7 fields.

**The client is invisible.** The design goal was "you shouldn't even be able to
tell that you're in one of these sessions." That's achieved. No chrome by
default. Leader key activates a compact hint line, not a persistent bar. The
status bar is opt-in. This restraint is harder than adding features.

**The auth is boring.** OTP→JWT→cookie. No OAuth, no API keys, no refresh
tokens. SHA256 hashes stored instead of plaintext. HMAC key rotation for
revocation. 585 lines, four scopes, done. It's the kind of auth system where
nothing is clever.

### What nags at me

**1. `main.zig` is 1,079 lines of procedural argument parsing.**

Every `cmdFoo` function follows the same pattern: parse flags with a while loop,
validate, resolve socket path, connect, do something, format output. This isn't
wrong — it's explicit, obvious, each function is self-contained. But there's a
lot of boilerplate: the error output formatting, the `writeAll(STDERR_FILENO, ...)`
pattern, the `std.process.exit(1)` calls scattered everywhere.

The counter-argument: this is a CLI. The boilerplate is the domain. Abstracting
it would add indirection without reducing complexity. Every "framework" for CLI
argument parsing in Zig is worse than just writing the loops. The functions are
boring and that's fine.

**Verdict**: Leave it. The boilerplate is essential complexity, not accidental.
What I'd do differently if starting over: nothing. This is how CLIs should look.

**2. The `handleClientInput` switch in `session.zig` (lines 304-378).**

This is a 75-line function with 8 switch branches. Some branches are 2 lines,
some are 10. The `input` branch has a reader/skipper split. The `resize` branch
has validation + application + notification. These are different levels of
complexity jammed into one switch.

The fix would be: extract `handleInputMsg`, `handleResizeMsg`, etc. Each would
be 5-15 lines. The switch would become 8 lines of dispatch.

But I keep not doing this, and I should ask why. The reason is that these
functions would only be called from one place, and the switch reads fine as-is.
It's a message handler — you switch on the message type and handle it. The
locality matters: someone reading the code sees all behaviors in one place.

**Verdict**: This one I'm less sure about. The function is at the edge of "too
long." If any branch grew, it should split. But right now, it reads.

**3. The http.zig event loop (165-299) is the ugliest code in the project.**

134 lines of poll index arithmetic with manual `idx` tracking across 4 client
types. This has been identified in S104, S105, and the S99-S101 cycle. It's
correct. It's tested (indirectly through integration tests). It's contained.
But it's the one place where I can't quickly glance at the code and know it's
right.

Every proposed fix makes it worse. Tagged unions add allocation. Separate arrays
with a merge step add complexity. An epoll-based design would be cleaner but
is a rewrite.

**Verdict**: This is genuinely the weakest code in the project. The right fix
might be epoll (which would also make the server more scalable), but that's
a substantial rewrite for a working system. For now, the complexity is
contained and stable.

### What's missing that usage would reveal

- **Reconnection UX.** When a session dies, there's no notification beyond the
  socket going away. In daily use, you notice your terminal froze, try to type,
  realize it's dead, detach. A heartbeat or keepalive would detect this faster.

- **Multiple sessions in one terminal.** The design is one session per terminal.
  Tmux's splits are out of scope (and wrong for this tool), but quick-switching
  between sessions (like screen's Ctrl+A n) could be valuable.

- **Clipboard integration.** Copy/paste in the web viewer works through the
  browser. In the native client, it's whatever your terminal does. If vanish
  is your primary terminal wrapper, clipboard support could matter.

These are all v2 features. None of them should be built until usage demands them.

### What simplicity looks like

The codebase is 5,994 lines across 14 files. That's smaller than most argument
parsing libraries. It replaces tmux (71k lines of C) for the use case of
persistent sessions with web access. The protocol is 213 lines. The auth is
585. The session daemon is 559.

The things I'd be proud to show someone:

1. `protocol.zig` — here's the entire wire protocol. 213 lines, all struct
   sizes tested at compile time. No versioning needed.
2. `session.zig` — here's a complete session multiplexer. 559 lines.
3. The fact that you can use it every day without knowing it's there.

### Conclusion

The codebase is better than it needs to be. That's the right place to stop.
Every improvement from here would either (a) fix something that isn't broken,
(b) add something nobody's asked for, or (c) change something for aesthetic
reasons that would churn the test suite. The S99-S101 cycle identified this
correctly: the system is complete, and improvement requires usage feedback.

What would make me proud? Restraint. The codebase is ~6k lines and does what
tmux does for the subset of users who want persistent sessions with web access,
without any of what tmux does that those users don't want. Every feature request
I've rejected has been the right call. The hardest part of this project has been
not adding things.

I'm proud of it as it stands.

### Next session

- S107 is a normal session. No architecture review until S108.
- The fullscreen app viewer inbox item remains. Interactive testing, not code.
- No code changes from this session — pure hammock.

---

> Earlier session notes (1-101) archived to
> [doc/sessions-archive.md](doc/sessions-archive.md).

<!-- Archive marker: S101 and earlier archived in S103. -->

