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

Done (Sessions 1-107): See [doc/sessions-archive.md](doc/sessions-archive.md).
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
refactors (S105), hammock on pride (S106), protocol utilities + spec fix (S107).

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

## 2026-02-09: Session 108 - Architecture Review (3-Session Checkpoint)

### Context

This is the S108 architecture review checkpoint (3 sessions after S105). I
re-read every source file and the spec.

### Simplicity scorecard

| Component | Simple? | Change since S105 |
|-----------|---------|-------------------|
| protocol.zig (230) | Yes | +17 (readStruct, skipBytes). Still clean. |
| session.zig (545) | Yes | -14. handleClientInput down to 61 lines. |
| client.zig (705) | Yes | -6. skipBytes cleanup only. |
| terminal.zig (348) | Yes | No change. |
| vthtml.zig (374) | Yes | No change. |
| config.zig (461) | Yes | No change. |
| auth.zig (585) | Yes | No change. |
| keybind.zig (193) | Yes | No change. |
| naming.zig (165) | Yes | No change. |
| pty.zig (140) | Yes | No change. |
| paths.zig (53) | Yes | No change. |
| signal.zig (48) | Yes | No change. |
| main.zig (1,079) | Mostly | No change. Procedural CLI — acceptable. |
| http.zig (1,056) | Mostly | -9. Event loop still the weakest spot. |

**Total: 5,982 lines, 53 unit tests + 11 integration tests.**

### What changed since S105

Only S107 had code changes. Two protocol utilities (`readStruct`, `skipBytes`)
consolidated 3 inline patterns. A spec compliance bug was fixed (unknown message
types now skip payload in session.zig). `handleClientInput` dropped from 75→61
lines. Net -12 lines.

The changes were surgical and correct. Nothing destabilized.

### Items evaluated

**1. JSON escaping duplication: `paths.zig:appendJsonEscaped` vs inline in
`vthtml.zig:updatesToJson`.**

These are the same escaping logic (switch on `"`, `\\`, `\n`, `\r`, `\t`,
control chars). One operates on `[]const u8` via `std.ArrayList`, the other
on `[4]u8` char slices inline. Could share a common function.

**Verdict: Accept.** The vthtml version can call `paths.appendJsonEscaped`
for the char slice. This is a real duplication — same switch, same escape
sequences, same control char handling. A 1-line call replaces 13 lines of
inline escaping. Will implement next session.

**2. http.zig event loop (lines 165-299).**

Re-examined for the fourth time (S99, S104, S105, now S108). The poll index
arithmetic is still correct, still ugly, still contained. Nothing has changed
about the analysis. The epoll alternative would be cleaner but is a rewrite.

**Verdict: No change.** Same conclusion as S105. Stopping re-evaluating this
unless the event loop needs modification for a feature.

**3. handleClientInput (session.zig:304-364).**

S107 brought this from 75→61 lines. S106 flagged it as "at the edge" at 75.
At 61 lines with 8 branches, most 2-4 lines, this is well within the comfort
zone. The `.input` branch is the longest at 11 lines and it's doing real work
(read payload, forward to PTY).

**Verdict: Resolved.** No longer a concern.

**4. vthtml `updateFromVTerm` vs `fullScreen` duplication (~30 lines).**

Re-examined from S105. The two functions share the same row/cell iteration
loop but differ in whether they check `eql` before appending. Could extract
the iteration into a helper that takes a `should_diff: bool` parameter or
a callback.

**Verdict: Reject again.** The functions are adjacent, easy to audit visually,
and parameterizing would obscure the core difference (one diffs, one doesn't).
A reader would have to understand the parameterization to know what each does.
Two clear functions > one clever one.

### New observations

**1. SSE keyframe interval is hardcoded at ~30s (via counter in http.zig).**

Not configurable. Probably fine — 30s is reasonable for web viewing — but
worth noting as a future config candidate if usage reveals problems.

**2. No request body size limit on HTTP input endpoint.**

The `handleInput` endpoint reads from the HTTP body without a size cap. In
practice the input is keystrokes (small), and the server is localhost-only, but
a malicious or buggy client could send a large body. This is a minor hardening
item, not urgent.

**3. The spec documents "approximately 1 second" for SSE keyframe timing
(line 547)** but the actual interval is ~30 seconds (counter-based, resets
after 30 updates). The spec should say "approximately 30 seconds" or describe
the counter mechanism.

**Verdict on new items:**

- Item 1: Leave. Config for this is YAGNI.
- Item 2: Note for future hardening. Not a real risk on localhost.
- Item 3: **Accept.** Fix the spec. This is a factual error. Will include in
  next session's commit.

### Architecture summary

The architecture is sound. Three review cycles (S99-S102, S104-S105, S108)
have converged on the same conclusion: the design works, the code is clean,
the remaining rough edges (http event loop, main.zig boilerplate) are
acceptable tradeoffs.

Two small items for next session:
1. Deduplicate JSON escaping in vthtml.zig (use `paths.appendJsonEscaped`).
2. Fix spec: SSE keyframe timing description.

### Next architecture review

S111 (3 sessions from now). Unless features are added, these reviews should
stay lightweight.

### Recommendations for next session

- Implement the two accepted items (JSON escaping dedup, spec timing fix).
- The fullscreen app viewer inbox item still needs interactive testing.
- Consider archiving S102-S106 — prompt.md has been getting long again.

---

> Earlier session notes (1-107) archived to
> [doc/sessions-archive.md](doc/sessions-archive.md).

<!-- Archive marker: S107 and earlier archived in S108. -->

