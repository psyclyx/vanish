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

Done (Sessions 1-108): See [doc/sessions-archive.md](doc/sessions-archive.md).
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
refactors (S105), hammock on pride (S106), protocol utilities + spec fix (S107),
architecture review checkpoint (S108).

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

## 2026-02-09: Session 109 - Accepted Refactors from S108

### What was done

Implemented the two items accepted in S108's architecture review:

1. **JSON escaping dedup**: `vthtml.zig:updatesToJson` now calls
   `paths.appendJsonEscaped` instead of inlining identical escape logic.
   -15 lines, 1 new import. Existing tests pass unchanged.

2. **Spec fix**: `doc/spec.md` SSE keyframe timing corrected from
   "approximately 1 second" to "approximately 30 seconds (time-based)."
   The actual implementation uses `now - sse.last_update >= 30` (seconds),
   which is a 30-second wall-clock check, not a counter as I described in
   S108. Corrected my own notes here.

### Line count delta

vthtml.zig: 375 → 361 (-14 lines, +1 import line = net -13)

### Next architecture review

S111 (2 sessions from now).

### Recommendations for next session

- The fullscreen app viewer inbox item still needs interactive testing.
- The inbox "hammocking about pride" item is open-ended — consider whether
  the dedup just done is the last cleanup, or if there's more to find.
- S108 had two minor hardening observations (SSE keyframe config YAGNI,
  HTTP input body size limit) — no action needed now.

---

> Earlier session notes (1-108) archived to
> [doc/sessions-archive.md](doc/sessions-archive.md).

<!-- Archive marker: S108 and earlier archived in S109. -->

