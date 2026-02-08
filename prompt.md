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

- Every 3 sessions, take some time to interrogate your abstractions. Is this
  architecture sound? Is the code maintainable? What's working? What isn't?
  What's simple, and what's complected? Think about the long term. You'll have
  to maintain this, don't make that hard on yourself.

Inbox: keep this up to date.

New:

- The nix package doesn't seem to be usable. I've tried the overlay, and the
  default.nix directly. I can get the package, but putting it on my path doesn't
  work. I believe we also need to get the man pages in the package?
- Clean up the documentation. Make it clean, professional, to the point. Not
  slop. (man page and README.md)

- spend many iterations hammocking about the problem. it's complete - but could
  it be better? what would make you proud to have done in this codebase?

Current:

- Mobile web: resizable terminal, modifier buttons (Ctrl, etc.), generally more
  mobile-friendly without being UX slop. Target audience falls back to termux if
  bad.
- Cursor position bug for narrow primary sessions.
- Session list SSE (reactive in web).
- Arch PKGBUILD.

Done (Session 46):

- ✓ Hammock session: mobile web terminal design. Designed the modifier button
  toolbar, responsive layout changes, and touch interaction model. Identified
  the minimal set of changes needed. See notes below.

Done (Session 45):

- ✓ Documentation cleanup. Rewrote README.md: removed outdated info, added web
  access section, configuration section, all 11 commands documented in a table.
  98 → 151 lines, denser and more complete. Created man page (doc/vanish.1):
  covers all commands, flags, keybindings, configuration, environment variables,
  and files. Renders cleanly. Rewrote DESIGN.md: updated protocol table (added
  KillSession 0x09), added Web Terminal section, updated source file listing to
  all 15 files, removed stale "Implementation Status" checklist. 225 → 133
  lines.

Done (Session 44):

- ✓ Web refresh button. Added "Refresh" button to terminal header that closes
  and reopens the SSE connection, getting a fresh keyframe. Extracted
  `openSse()` helper to deduplicate SSE setup between `connect()` and
  `refresh()`. Resets `isPrimary` on refresh since the new connection starts as
  viewer. index.html: 220 → 231 lines (+11). No server changes needed.

Done (Session 43):

- ✓ Deduplicated main.zig: extracted `daemonize()` helper (9-line
  setsid/close/devnull/dup2 block appeared 3×) and `connectAsViewer()` helper
  (25-line viewer handshake pattern appeared 3×). Renamed local `daemonize` var
  to `run_as_daemon` in `cmdServe` to avoid shadowing. main.zig: 1,041 → 972
  lines (-69). Build clean, all tests passing.

Done (Session 42):

- ✓ Architecture review (3-session checkpoint). See notes below.

Done (Session 41):

- ✓ Autostart HTTP daemon (`--serve` / `-s` flag on `vanish new`, plus
  `auto_serve` config option). When enabled, checks if HTTP server is already
  listening on the configured port before spawning. If not running, forks a
  daemonized HTTP server automatically. Supports both IPv4 and IPv6 bind
  addresses. Config: `"serve": { "auto_serve": true }`. CLI:
  `vanish new --serve -a zsh`.

Done (Session 40):

- ✓ Expanded naming.zig wordlists from 4 to 16 words per bucket (832 total
  words, up from 208). Fixed Q-nouns duplicate. Changed array type from
  `[]const []const u8` to `[16][]const u8` for compile-time size enforcement.
  Decorrelated adjective/noun selection: adjective uses `second % 16`, noun uses
  `(epoch_secs / 4) % 16`. Added uniqueness test that validates all 52 buckets
  have no duplicate words. naming.zig: 209 -> 166 lines (denser format).

Done (Session 39):

- ✓ Architecture review (3-session checkpoint). See notes below.

Done (Session 38):

- ✓ Auto-name sessions (`--auto-name` / `-a` flag). Generates
  adjective-noun-command names (e.g. "dark-knot-zsh"). Adjective letter keyed to
  hour, noun letter to minute, specific word chosen with second-based jitter.
  Linear probes with numeric suffix on collision. New naming.zig module (~170
  lines, 3 tests). Name printed to stderr so user knows what was created.

Done (Session 37):

- ✓ Revamped status bar and leader hint. Replaced full-width inverse video bar
  with minimal, dim-styled text. Status bar now shows dim " ─ " prefix + session
  name (left), with role/offset/dimensions (right) in dim text. Only shows
  "viewer" when not primary (primary is expected, not worth showing). Leader
  hint now shows curated bindings (detach, scrollback, status, takeover, help)
  with bold keys and dim separators, instead of all 14 bindings crammed into
  inverse video. Deduplicated by action to avoid showing `d` and `^A^A` both for
  detach.

Done (Session 36):

- ✓ Fixed Ctrl+Space leader key - The is_ctrl detection in client.zig only
  covered bytes 1-26. Ctrl+Space (0x00) and Ctrl+\/]/^/_ (0x1C-0x1F) were
  excluded, so they never matched as leader despite config parsing being correct
  since session 28. One-line fix.
- ✓ Architecture review (3-session checkpoint). See notes.

Done (Session 35):

- ✓ Fixed cell gaps in browser terminal. Each cell span now gets explicit width,
  height, and line-height matching measured character dimensions. Without this,
  spans only covered text content area, leaving visible gaps between rows. CSS +
  JS fix in index.html (+6 lines).

Done (Session 34):

- ✓ Web terminal resize + runtime char measurement. Replaced hardcoded
  charWidth/charHeight with runtime font measurement via probe element.
  Implemented /resize endpoint (was a stub) - routes through SSE client's
  session socket like input/takeover. Browser sends resize on window change and
  after takeover. http.zig: 862→898 (+36), index.html: 185→215 (+30).

Done (Session 33):

- ✓ Architecture review (3-session checkpoint). Codebase stable at 5,452 lines
  across 14 files (13 .zig + 1 .html). Analyzed new inbox items. See notes.

Done (Session 32):

- ✓ Fixed web terminal input - The /input and /takeover endpoints were creating
  ephemeral socket connections per keystroke (connect as primary, handshake,
  skip full state, send 1 byte, disconnect). This always failed when a native
  primary existed. Now input/takeover route through the SSE client's existing
  persistent session socket. Auto-takeover on first keypress. http.zig: 949→862
  (-87 lines).

Done (Session 31):

- ✓ Extract shared utilities (paths.zig) - Moved appendJsonEscaped,
  getDefaultSocketDir, and resolveSocketPath into paths.zig. Removed ~60 lines
  of duplication across main.zig, http.zig, and vthtml.zig. 13 source files now.
  All tests passing.

Done (Session 30):

- ✓ Architecture review - Codebase is stable at 5,410 lines across 12 files.
  Core multiplexing and web terminal both working well. Identified code
  duplication (appendJsonEscaped, getDefaultSocketDir, resolveSocketPath) as
  technical debt to address. Project approaching "done" for stated scope.

Done (Session 29):

- ✓ Updated prompt.md scope - Reorganized task description into sections (Core,
  Sessions, Native Client, Web Access, Design Principles). Web access is now
  documented as a first-class feature with its key characteristics: JWT/OTP
  auth, SSE streaming, server-side VT→HTML, cell-level deltas.

Done (Session 27):

- ✓ Ctrl+Backslash and Ctrl+Space leader keys - Fixed config parsing and
  writeJson to handle special control characters (0x00, 0x1B-0x1F). Now `"^\\"`,
  `"^ "`, and `"Ctrl+Space"` all work in config.json.

Done (Session 26):

- ✓ HTML deltas - Implemented server-side VT→HTML rendering with cell-level
  diffing. Each SSE client maintains a ScreenBuffer of last-sent state. Only
  changed cells are sent as JSON. See vthtml.zig.
- ✓ Character bugs - Fixed by doing all rendering server-side. Browser just
  positions pre-rendered HTML spans.
- ✓ http module refactor (partial) - Extracted vthtml.zig (395 lines), http.zig
  now 988 lines.
- ✓ Native vs web client analysis - Session 24 concluded they should stay
  separate; fundamentally different pipelines.
- ✓ Kill command - Session 25 added `vanish kill <session>`.

OLD:

- Can we do json instead of toml for config?
- I'm not sure the claudes earlier properly understood by the scrolling support.
  I think we explicitly don't want an additional scrollback thing in the viewer.
  However, for full-screen apps, viewers may be smaller than the primary
  session, in height and/or width. That's what the scrolling is for - to pan
  around a terminal larger than the bounds of the viewer. If it's smaller, we
  can just draw it wherever is convinient - center or top-left corner are both
  valid choices.
- You may already have it, but can you please make sure we can take over
  sessions from viewers? If sizes differ, we'll send a resize to the emulated
  terminal, and switch the other session to viewer mode.
- A command to list and disconnect users is helpful
- It's probably already supported, but just in case - if a primary session is
  detached from (as opposed to exiting), we want to run it in the background,
  even if there aren't any viewers.
- XDG_RUNTIME_DIR might be the best place for this, idk - but we will likely be
  using this extensively on machines both from a desktop session as well as from
  ssh. We want sessions to default to a user-specific directory, but all
  sessions should be accessible, and we shouldn't tie this to a particular login
  session. (In fact, I think we want these to persist even if the login session
  that created them closed!)
- generally, human-readable and json output is helpful for scripting. Make sure
  we have a --json flag.

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

## 2026-02-07: Session 46 - Hammock: Mobile Web Terminal Design

The user asked for "many iterations hammocking about the problem" and to think
about what would make this codebase something to be proud of. This session
focuses on the mobile web experience - the highest priority remaining feature.

### The Problem

The web terminal works well on desktop but is barely usable on mobile. The
target audience "falls back to termux if bad." That's a high bar. To beat termux
for quick SSH-style access, the web terminal needs to be:

1. Functional enough to run commands, edit files, use vim/nano
2. Not annoying - no accidental taps, no obscured terminal
3. Fast - no input lag, no rendering jank

What it does NOT need to be: a full termux replacement. This is for quick access
from a phone/tablet when you don't have termux installed. The user already said
"not UX slop" - no unnecessary chrome, no "app-like" UI nonsense.

### What's Currently Broken on Mobile

1. **No way to send Ctrl+anything.** Mobile keyboards don't have Ctrl. Without
   Ctrl+C, Ctrl+D, Ctrl+A (the leader key!), the terminal is nearly useless.
   This is the critical gap.

2. **No way to send Escape, Tab, or function keys.** Same issue. Mobile
   keyboards lack these. Can't exit vim, can't tab-complete, can't use Ctrl+Z.

3. **Font is too small.** 14px monospace on a phone is unreadable. Need larger
   default on small screens, or let the user control it.

4. **Touch targets are too small.** The header buttons are tiny. The OTP input
   works fine but the terminal header buttons need bigger hit areas.

5. **Soft keyboard may cover the terminal.** When the keyboard appears, the
   visible terminal area shrinks dramatically. Need to handle this.

6. **No way to scroll the terminal output.** `overflow: auto` on `#term` should
   allow scrolling, but on mobile this might conflict with the viewport/page
   scrolling.

### Design: Modifier Button Toolbar

The core addition: a floating toolbar with modifier buttons. Here's the design.

**Buttons needed (minimal set):**

- **Ctrl** - Toggle. Tapping Ctrl makes the next keypress send Ctrl+key.
  Auto-resets after one keypress (like a phone's Shift key).
- **Esc** - One-shot. Sends `\x1b` immediately on tap.
- **Tab** - One-shot. Sends `\t` immediately on tap.
- **Arrows** - Left/Right/Up/Down. These are often missing or awkward on mobile
  keyboards. But four arrow buttons add a lot of chrome...

**Rejected alternatives:**

- Alt button: Rarely needed in terminal use. Skip.
- F-key row: Too many buttons, rarely used. Skip. (Can always use escape
  sequences typed manually.)
- Separate Ctrl+C / Ctrl+D / Ctrl+Z buttons: Too specific. A generic Ctrl toggle
  covers all cases with one button.
- Swipe gestures for arrows: Discoverable only if documented, fragile, conflict
  with scrolling. Skip.

**Arrow key decision:** Include them. Four small buttons in a row. On mobile,
arrow keys are the most painful gap after Ctrl. Tab-completing a path and then
moving the cursor is basic terminal usage. Without arrows, editing command lines
is miserable.

**Toolbar layout:**

```
[ Esc ] [ Tab ] [ Ctrl ] [ ← ] [ → ] [ ↑ ] [ ↓ ]
```

Position: Bottom of screen, above the soft keyboard. Fixed position. Thin (~40px
height). Semi-transparent dark background. Only visible on touch devices (or
togglable).

**Detection:** Use `'ontouchstart' in window` or similar to detect touch
capability. Show toolbar only on touch devices. This avoids cluttering the
desktop experience.

**Ctrl toggle behavior:**

1. User taps Ctrl button → button highlights (active state)
2. User types a key on keyboard → key sent as Ctrl+key, Ctrl auto-deactivates
3. If user taps Ctrl again before typing → Ctrl deactivates (cancel)
4. This mirrors iOS/Android Shift behavior. Intuitive.

**One-shot button behavior (Esc, Tab, Arrows):**

1. User taps button → character sent immediately
2. No toggle state. Tap = send.

### Design: Responsive Layout

**Font scaling:**

- Desktop (>768px): 14px (current)
- Tablet (481-768px): 13px
- Phone (≤480px): 12px

Or: just let the user pinch-to-zoom and rely on `measureChar()` to adapt. The
grid rendering already uses measured dimensions. If the user zooms in, the
characters get bigger, `measureChar()` reports bigger dimensions, and
`sendResize()` sends fewer cols/rows to the session.

Actually, this is elegant. **Don't fight the browser's zoom.** Let the user
control font size with pinch-to-zoom. The existing `measureChar()` +
`sendResize()` pipeline handles it automatically. Just make sure we don't
prevent zoom with `maximum-scale=1` or `user-scalable=no`.

Current viewport meta: `width=device-width, initial-scale=1.0`. Good - no zoom
restrictions.

**Header on mobile:**

Make header buttons taller (min-height: 44px for Apple touch guidelines).
Consider icon-only buttons on small screens to save horizontal space.

**Soft keyboard handling:**

The `visualViewport` API reports the visible area excluding the keyboard. Use
`visualViewport.resize` event to trigger `sendResize()`. This way, when the
keyboard appears, we automatically resize the session to fit the remaining
visible area.

```js
if (window.visualViewport) {
  window.visualViewport.addEventListener("resize", sendResize);
}
```

And `sendResize()` should use `visualViewport.height` instead of
`term.clientHeight` when available, to get the actual visible area.

### Design: Touch Interaction

**Focus management:**

When user taps the terminal area, show the soft keyboard. The `#term` div
already has `tabindex="0"` which makes it focusable. But we might need an
invisible `<textarea>` or `<input>` to reliably trigger the mobile keyboard,
since `div[tabindex]` doesn't always trigger it.

Common pattern in web terminals (xterm.js, hterm): hidden textarea that captures
input. The div is purely for display. The textarea triggers the keyboard and
captures keystrokes.

**Current approach:** `term.onkeydown = handleKey`. This works on desktop but is
unreliable on mobile. Mobile browsers fire different events:

- `keydown` fires for some keys but not all on mobile
- `input` / `beforeinput` events are more reliable on mobile
- Composition events (for CJK input) complicate things

**Pragmatic approach:** Add a hidden `<input>` element that stays focused. On
mobile, this triggers the keyboard. Use the `input` event to capture typed
characters. Keep `keydown` for special keys (Enter, Backspace, arrows). This is
the standard web terminal pattern.

But... is this scope creep? The user's target audience falls back to termux. The
bar is "functional enough to be useful, not annoying." Do we need
production-grade IME support? No. Do we need the keyboard to appear when you tap
the terminal? Yes.

**Minimal approach:** Keep `keydown` handler. Add the modifier toolbar. Add a
`touchstart` listener on the terminal that focuses the `#term` div. Test on
actual mobile browsers. If `keydown` works (it does on most modern Android/iOS
browsers for ASCII), ship it. If not, add the hidden input later.

### Implementation Plan (For Future Sessions)

**Session 47: Modifier toolbar**

Add the touch toolbar to index.html:

1. Detect touch device: `const isTouch = 'ontouchstart' in window`
2. If touch, show toolbar div at bottom of terminal view
3. Toolbar: Esc, Tab, Ctrl (toggle), ←, →, ↑, ↓
4. Wire Ctrl toggle into handleKey
5. Wire one-shot buttons to send input directly
6. CSS: position above keyboard, min-height 44px touch targets
7. Use `visualViewport` API for resize handling on mobile

Estimated: ~50-60 lines added to index.html. No server changes.

**Session 48: Architecture review**

Review the mobile implementation. Test on actual devices.

**Session 49: Polish**

- Fix any mobile issues found in testing
- Header button touch targets
- Consider the hidden input approach if keydown is unreliable

### What Would Make Me Proud

Stepping back from mobile specifically: what would make this codebase something
to be proud of?

**What's already good:**

- The architecture is clean. 15 files, clear boundaries, no circular deps.
- The protocol is simple and stable. 9+8 message types, 5-byte header.
- The native client is polished. Leader key, status bar, viewport panning.
- The web terminal works. Delta streaming, auth, takeover.
- The naming system is delightful. "dark-knot-zsh" is a good name.
- The code is short. ~5,800 lines total for a terminal multiplexer with web
  access. tmux is 70,000+.

**What would push it over the line:**

1. **The mobile experience working well.** This is the remaining big gap. When
   you can SSH into your box from your phone via the web terminal and actually
   get work done, that's a meaningful capability that dtach/tmux don't offer.

2. **The Arch PKGBUILD.** Making it installable via `makepkg -si` or an AUR
   package would make it real. Currently it's a project; with packaging it's a
   tool.

3. **The cursor position bug being fixed.** This is a correctness issue. Narrow
   primary sessions with wrong cursor position undermines trust.

4. **Session list SSE.** The web session list polling feels janky. When you
   create a session from the terminal and the web UI updates live, that's
   polished.

**What I'd cut:**

- Brotli/gzip compression: already decided to skip. Correct.
- Render deduplication: already decided to skip. Correct.
- Splitting index.html into separate JS: not yet needed at 230 lines. The
  modifier toolbar will push it to ~290. Still manageable in one file if the
  code stays clean.

### Inbox Status

| Item                     | Status | Priority | Notes                     |
| ------------------------ | ------ | -------- | ------------------------- |
| Mobile modifier toolbar  | ○ Todo | **High** | Designed this session     |
| Cursor position (narrow) | ○ Todo | Low      | Needs investigation       |
| Session list SSE         | ○ Todo | Low      | Reactive web session list |
| Arch PKGBUILD            | ○ Todo | Low      | Packaging                 |

---

## 2026-02-07: Session 45 - Documentation Cleanup

Addressed the user's request: "Clean up the documentation. Make it clean,
professional, to the point. Not slop."

### What Changed

**README.md (98 → 151 lines, complete rewrite)**

The old README was outdated - missing web terminal, configuration, auto-naming,
kill command, serve command, otp/revoke commands. The new README:

- Opens with a one-line description and a two-sentence explanation
- Quick start section with 5 commands showing the core workflow
- All 11 commands in a single reference table
- Keybindings table (complete)
- Web access section with auth flow
- Configuration section with example JSON and all leader key formats/actions
- Removed the "Implementation Status" checklist (project is feature-complete)
- Removed verbose design section (that's what DESIGN.md is for)

**doc/vanish.1 (new, man page)**

Created a proper Unix man page covering:

- SYNOPSIS, DESCRIPTION
- All 11 COMMANDS with flags
- Global OPTIONS
- KEYBINDINGS section
- CONFIGURATION with example JSON
- ENVIRONMENT (XDG_RUNTIME_DIR, XDG_CONFIG_HOME)
- FILES
- SEE ALSO (dtach, tmux, screen)

Renders cleanly with `man ./doc/vanish.1`.

**DESIGN.md (225 → 133 lines, rewrite)**

The old DESIGN.md had stale information:

- Missing KillSession (0x09) from protocol table
- File structure listed only 8 of 15 source files
- "Implementation Status" section with incomplete checklist
- Missing Web Terminal section entirely
- CLI examples used old syntax (`vanish new <name> -- <command>`)
- "Leader Key: Ctrl-A (configurable when config is implemented)" - config has
  been implemented since session 16

The new DESIGN.md is focused: architecture diagram, protocol tables, web
terminal overview, viewport panning, source file listing, design principles. No
checklists, no open questions, no implementation status.

### Inbox Status

| Item                     | Status | Priority | Notes                     |
| ------------------------ | ------ | -------- | ------------------------- |
| Documentation            | ✓ Done | -        | Session 45                |
| Mobile modifier buttons  | ○ Todo | Medium   | Ctrl/Alt/Esc toolbar      |
| Cursor position (narrow) | ○ Todo | Low      | Needs investigation       |
| Session list SSE         | ○ Todo | Low      | Reactive web session list |
| Arch PKGBUILD            | ○ Todo | Low      | Packaging                 |

---

## 2026-02-07: Session 44 - Web Refresh Button

Added a "Refresh" button to the web terminal that force-reconnects the SSE
stream, getting a fresh keyframe from the server. This addresses the "garbled
text on connect" issue reported in the inbox.

### What Changed

**index.html (220 → 231 lines, +11)**

**`openSse(name)`** (10 lines): Extracted SSE connection setup into a helper
function. Closes any existing SSE, clears the cell grid, creates new
EventSource, wires up keyframe/delta/exit/error handlers. Used by both
`connect()` and `refresh()`, eliminating the duplication that would otherwise
exist.

**`refresh()`** (3 lines): Resets `isPrimary` to false (the new SSE connection
starts as viewer), then calls `openSse(currentSession)`.

**Refresh button**: Added to terminal header alongside existing Takeover and
Disconnect buttons.

**`connect()` simplified**: Now delegates SSE setup to `openSse()` instead of
doing it inline. Reduced from 12 lines to 8.

### How It Works

1. User clicks "Refresh" in the terminal header
2. `refresh()` resets `isPrimary` and calls `openSse()`
3. `openSse()` closes the old SSE connection (server detects hangup, cleans up
   the SseClient and its session socket)
4. New SSE EventSource connects to `/api/sessions/{name}/stream`
5. Server creates new SseClient, connects to session as viewer, sends initial
   keyframe with full screen state
6. Browser receives fresh keyframe, renders all cells from scratch
7. If user was previously primary, they can click Takeover or type (auto-
   takeover on first keypress) to regain primary status

### Design Decisions

- **No server changes needed**: The existing SSE lifecycle already handles
  reconnection correctly. Server sends a keyframe on every new SSE connection.
  Closing and reopening the EventSource is sufficient.
- **Extracted `openSse()` helper**: The SSE wiring code (EventSource creation,
  event listeners) was already 5 lines in `connect()`. Adding `refresh()` would
  have duplicated it. The helper keeps both callers clean.
- **Reset isPrimary**: The old SSE connection's session socket gets closed on
  the server side. The new connection starts as a viewer. Without resetting
  isPrimary, the client would incorrectly think it's still primary and try to
  send input without taking over first.
- **Grid cleared on refresh**: `openSse()` clears the grid and cellMap before
  reconnecting. The incoming keyframe will repopulate all cells from scratch.

### Line Count Impact

| File       | Before | After | Change |
| ---------- | ------ | ----- | ------ |
| index.html | 220    | 231   | +11    |

Total codebase: 15 files, ~5,763 lines.

### Testing

- Build: Clean
- Unit tests: All passing

### Inbox Status

| Item                     | Status | Priority | Notes                     |
| ------------------------ | ------ | -------- | ------------------------- |
| Web refresh button       | ✓ Done | -        | Session 44                |
| Mobile modifier buttons  | ○ Todo | Medium   | Ctrl/Alt/Esc toolbar      |
| Cursor position (narrow) | ○ Todo | Low      | Needs investigation       |
| Session list SSE         | ○ Todo | Low      | Reactive web session list |
| Man page, readme         | ○ Todo | Medium   | Documentation             |
| Arch PKGBUILD            | ○ Todo | Low      | Packaging                 |
| Render deduplication     | ✗ Skip | -        | Not worth the complexity  |
| Brotli/gzip compression  | ✗ Skip | -        | Not worth the complexity  |

---

## 2026-02-07: Session 43 - Deduplicate main.zig

Addressed the top recommendation from the session 42 architecture review:
extract `daemonize()` and `connectAsViewer()` helpers to eliminate duplicated
boilerplate in main.zig.

### What Changed

**main.zig (1,041 → 972 lines, -69)**

Two new helper functions:

**`daemonize()`** (10 lines): The setsid + close stdio + open /dev/null + dup2
pattern that appeared identically in three places:

- `cmdNew` child fork (line 326)
- `maybeStartServe` child fork (line 787)
- `cmdServe` daemonize fork (line 861)

All three call sites replaced with `daemonize()`.

**`connectAsViewer()`** (21 lines): The viewer handshake pattern (create Hello
as viewer → send → read welcome → check denied → read welcome struct → skip full
state) that appeared identically in three places:

- `cmdClients` (lines 554-585)
- `cmdKick` (lines 674-697)
- `cmdKill` (lines 723-746)

All three call sites replaced with `connectAsViewer()`. Error handling at call
sites now uses `error.ConnectionDenied` to distinguish denial from connection
failure.

**Variable rename**: `var daemonize` in `cmdServe` renamed to
`var
run_as_daemon` to avoid shadowing the new `daemonize()` function.

### Why This Matters

- **Bug fix consistency**: A fix to the daemonize or handshake logic now applies
  everywhere. Previously, a bug fix in one copy could miss the other two.
- **Readability**: `cmdKick` dropped from ~50 lines to ~25. The intent (connect,
  send kick, done) is immediately clear.
- **main.zig back under 1,000 lines**: 972, down from 1,041.

### Line Count Impact

| File     | Before | After | Change |
| -------- | ------ | ----- | ------ |
| main.zig | 1,041  | 972   | -69    |

Total codebase: 15 files, ~5,752 lines (down from 5,821).

### Testing

- Build: Clean
- Unit tests: All passing

### Inbox Status

| Item                     | Status | Priority | Notes                     |
| ------------------------ | ------ | -------- | ------------------------- |
| main.zig dedup cleanup   | ✓ Done | -        | Session 43                |
| Mobile modifier buttons  | ○ Todo | Medium   | Ctrl/Alt/Esc toolbar      |
| Web refresh button       | ○ Todo | Medium   | Close+reopen SSE          |
| Cursor position (narrow) | ○ Todo | Low      | Needs investigation       |
| Session list SSE         | ○ Todo | Low      | Reactive web session list |
| Man page, readme         | ○ Todo | Medium   | Documentation             |
| Arch PKGBUILD            | ○ Todo | Low      | Packaging                 |
| Render deduplication     | ✗ Skip | -        | Not worth the complexity  |
| Brotli/gzip compression  | ✗ Skip | -        | Not worth the complexity  |

---

## 2026-02-07: Session 42 - Architecture Review (3-session checkpoint)

Last review was session 39. This is the fifth consecutive architecture review
where the codebase is fundamentally healthy. The project is mature and stable.

### Codebase Stats

| File         | Lines     | Change from S39 | Purpose                    |
| ------------ | --------- | --------------- | -------------------------- |
| main.zig     | 1,041     | +68             | CLI entry point            |
| http.zig     | 898       | 0               | Web server, SSE, routing   |
| client.zig   | 636       | 0               | Native client, viewport    |
| auth.zig     | 556       | 0               | JWT/HMAC, OTP exchange     |
| session.zig  | 526       | 0               | Daemon, poll loop          |
| config.zig   | 461       | +7              | JSON config parsing        |
| vthtml.zig   | 375       | 0               | VT→HTML, delta computation |
| terminal.zig | 335       | 0               | ghostty-vt wrapper         |
| index.html   | 220       | 0               | Web frontend               |
| protocol.zig | 192       | 0               | Wire format                |
| keybind.zig  | 185       | 0               | Input state machine        |
| naming.zig   | 165       | -44             | Auto-name generation       |
| pty.zig      | 140       | 0               | PTY operations             |
| signal.zig   | 48        | 0               | Signal handling            |
| paths.zig    | 43        | 0               | Shared utilities           |
| **Total**    | **5,821** | **+31**         | 15 files                   |

Build: Clean. Tests: All ~40 unit tests passing. Integration: 19/19 passing.

### Codebase Health

**Good.** The +31 line growth from session 39 is entirely from the autostart
serve feature in main.zig (+68) offset by naming.zig shrinking (-44 from the
16-word bucket reformatting). 13 of 15 files are unchanged since session 39.

The core is done. Protocol, session, terminal, pty, signal, paths, auth, http,
vthtml, keybind, client - all stable and untouched for multiple review cycles.

### What's Working Well

**1. Stability.** 11 of 15 modules have been unchanged for 6+ sessions. The
architecture has converged. Bug reports are rare, and when they occur, fixes are
small and localized.

**2. Module boundaries remain excellent.** No circular dependencies. Clean
downward dependency flow. Each file has single responsibility. No file exceeds
1,041 lines.

**3. Zero TODO/FIXME/HACK markers.** There is no acknowledged technical debt
left as comments in the source. All known issues are tracked in this prompt
rather than scattered through code.

**4. Test coverage is reasonable.** ~40 unit tests across 9 modules, plus 19
integration tests. The modules with tests (protocol, terminal, keybind, config,
auth, naming, vthtml, pty, main) cover the correctness-critical paths.

### Issues Found

**1. Daemonization boilerplate duplicated 3× in main.zig**

The 9-line setsid/close/devnull/dup2 block appears identically at:

- Lines 326-336 (cmdNew child fork)
- Lines 787-795 (maybeStartServe child fork)
- Lines 861-869 (cmdServe daemonize fork)

This is the most clear-cut duplication in the codebase. A `daemonize()` helper
function would eliminate 18 lines and make intent clearer.

**2. Protocol handshake boilerplate duplicated 3× in main.zig**

The pattern: create viewer Hello → send → read welcome → check denied → read
welcome struct → skip full state appears near-identically in:

- cmdClients (lines 554-585)
- cmdKick (lines 674-697)
- cmdKill (lines 723-746)

Each copy is ~25 lines. A `connectAsViewer(socket_path)` helper returning
`(fd, Welcome)` would reduce this to 3 one-liners.

**3. connectToSession duplicated across 3 files**

The UNIX socket connect function exists in:

- main.zig:754 (connectToSession)
- http.zig:889 (connectToSession)
- client.zig:576 (connectSocket)

All three are functionally identical. This could live in paths.zig alongside the
other shared utilities, though the current duplication is mild (~10 lines each).

**4. main.zig has crossed 1,000 lines**

main.zig grew from 973 (session 39) to 1,041. It now handles 11 CLI commands
plus the autostart serve logic. The `cmdNew` function alone is 132 lines.

This isn't critical - CLI entry points are naturally large - but it's worth
noting as the largest file. The duplication issues (#1 and #2 above) account for
~70 of those lines. Addressing the duplication would bring it back under 1,000.

**5. executeAction scroll repetition in client.zig**

Noted in session 39 and still present: 8 scroll actions at lines 173-212 all
follow `self.viewport.moveX(); self.renderViewport(); self.renderStatusBar();`.
This is 40 lines that could be ~8 with a single scroll-action handler. Not
urgent since these actions are stable and unlikely to change.

### Simple vs Complected Analysis

**Simple (good):**

- Everything from session 39 remains simple
- The autostart serve feature is clean: probe port → fork if needed. No PID
  files, no lock files, no shared state.
- naming.zig with 16-word buckets: flat data, compile-time size enforcement,
  pure function generation.

**Watch items:**

- main.zig duplication. Three copies of daemonize boilerplate and three copies
  of handshake boilerplate in the same file is starting to smell. Each copy is
  identical, so a bug fix in one would need to be applied to all three. This is
  the strongest candidate for cleanup.

- index.html at 220 lines. Mobile modifier buttons will push it past 250.
  Previous reviews recommended splitting JS into a separate file at that point.
  Still valid.

**No complected code found.** Architecture remains clean.

### Recommendations for Next Sessions

**1. Session 43: Extract daemonize() and connectAsViewer() helpers in main.zig**

This is the most impactful cleanup available. Two small helper functions would:

- Remove ~50 lines of duplication
- Bring main.zig back under 1,000 lines
- Make cmdNew, cmdKick, cmdKill, cmdClients, cmdServe all more readable
- Reduce the risk of inconsistent bug fixes across copies

Estimated: -50 lines, +15 lines = net -35.

**2. Session 44: Mobile modifier buttons (web)**

The web terminal is the biggest remaining feature gap. Touch users need Ctrl,
Alt, Esc, Tab buttons. This is a UX design task first, implementation second.

**3. Session 45 (review): Documentation push**

Man page and README update. The web terminal, auto-naming, autostart serve, and
the full config format are all undocumented. By session 45 we should have mobile
modifiers done and can document everything together.

### Inbox Status

| Item                     | Status | Priority | Notes                      |
| ------------------------ | ------ | -------- | -------------------------- |
| main.zig dedup cleanup   | ○ Todo | **High** | 3× daemonize, 3× handshake |
| Mobile modifier buttons  | ○ Todo | Medium   | Ctrl/Alt/Esc toolbar       |
| Web refresh button       | ○ Todo | Medium   | Close+reopen SSE           |
| Cursor position (narrow) | ○ Todo | Low      | Needs investigation        |
| Session list SSE         | ○ Todo | Low      | Reactive web session list  |
| Man page, readme         | ○ Todo | Medium   | Documentation              |
| Arch PKGBUILD            | ○ Todo | Low      | Packaging                  |
| Render deduplication     | ✗ Skip | -        | Not worth the complexity   |
| Brotli/gzip compression  | ✗ Skip | -        | Not worth the complexity   |

---

## 2026-02-07: Session 41 - Autostart HTTP Daemon

Implemented the inbox item: config option / flag to autostart the HTTP daemon
when a session is started.

### What Changed

**config.zig:**

- Added `auto_serve: bool = false` to `ServeConfig` struct
- Config parser now handles `"auto_serve"` boolean in the `"serve"` object
- `writeJson()` outputs the `auto_serve` field

**main.zig:**

- Added `--serve` / `-s` flag to `cmdNew()`
- Added `maybeStartServe()`: checks if HTTP server is already running on the
  configured port, forks a daemonized server if not
- Added `isPortListening()`: probes the configured bind address and port via TCP
  connect. Handles both IPv4 and IPv6 addresses.
- Usage text updated to show `--serve` flag

### How It Works

1. User runs `vanish new --serve -a zsh` (or has `"auto_serve": true` in config)
2. After the session daemon is started and ready, `maybeStartServe()` is called
3. It tries to TCP connect to `cfg.serve.bind:cfg.serve.port` (default
   127.0.0.1:7890)
4. If connection succeeds → server is already running, nothing to do
5. If connection fails → fork a child process that daemonizes and runs
   `HttpServer.init() + run()` (same pattern as `vanish serve -d`)
6. Parent continues to auto-attach (or exit if `--detach`)

### Design Decisions

- **Port probing over PID files**: No lock files, no state files, no cleanup
  needed. Just try to connect. If something is listening, assume it's our
  server. Simple and robust.
- **Reuses existing daemonize pattern**: The fork + setsid + close stdio + run
  pattern is identical to `cmdServe --daemonize`. No new abstractions.
- **Config + CLI flag**: `auto_serve` in config means "always start server on
  session creation." `--serve` flag means "start server this time." Either
  triggers the same logic.
- **IPv4 + IPv6**: `isPortListening` tries IPv4 first, then IPv6. Handles
  `127.0.0.1`, `0.0.0.0`, `::1`, `::` correctly.

### Usage

```sh
# One-time: start server with this session
vanish new --serve -a zsh

# Always: set in config
# ~/.config/vanish/config.json:
# { "serve": { "auto_serve": true } }
vanish new -a zsh  # server starts automatically

# Combine flags
vanish new -s -a -d zsh  # serve + auto-name + detach
```

### Line Count Impact

| File       | Before | After | Change  |
| ---------- | ------ | ----- | ------- |
| config.zig | 455    | 461   | +6      |
| main.zig   | 974    | 1041  | +67     |
| **Net**    |        |       | **+73** |

### Testing

- Build: Clean
- Unit tests: All passing
- Integration tests: 19/19 passing

---

## 2026-02-07: Session 40 - Expand Naming Wordlists to 16 Per Bucket

Addressed the user's explicit request: "Let's try and have 16 words per bucket."

### What Changed

**naming.zig: Wordlist expansion**

- Adjective buckets: 4 → 16 words each (416 total adjectives)
- Noun buckets: 4 → 16 words each (416 total nouns)
- Total vocabulary: 208 → 832 words

**Array type change:**

Changed from `[26][]const []const u8` (runtime-sized inner slices) to
`[26][16][]const u8` (compile-time fixed-size buckets). This means the compiler
enforces exactly 16 words per bucket. A bucket with 15 or 17 words is now a
compile error, not a runtime surprise.

Added `bucket_size` constant to avoid magic number 16.

**Word selection math:**

Before (4-word buckets):

- Adjective: `second % 4` (cycles every 4 seconds)
- Noun: `(second / 4) % 4` (cycles every 16 seconds, correlated with adj)

After (16-word buckets):

- Adjective: `second % 16` (cycles every 16 seconds, covers full bucket)
- Noun: `(epoch_secs / 4) % 16` (decorrelated from second, shifts every 4s)

The old noun selection was `(second / 4) % bucket_len`, which with 4-word
buckets gave range 0-3 (fine), but was correlated with the adjective since both
derived from `second`. With 16-word buckets, using `second` for both would
create a fixed offset pattern. Using `epoch_secs / 4` breaks the correlation -
the noun cycles independently from the adjective.

**Bugs fixed:**

- Q-nouns: "quay" appeared twice. Now all 16 Q-nouns are unique.
- I-nouns: "ivory" appeared twice. Fixed.

**Quality improvements:**

- Removed non-adjectives from adjective list (e.g., "elm", "awl", "alms")
- Removed non-nouns from noun list (e.g., "upon", "utile")
- All words are recognizable English (X-words get creative license)

**New test:**

Added `"all buckets have exactly 16 unique words"` test that iterates all 52
buckets, verifies each has exactly `bucket_size` entries, and checks for
duplicates within each bucket using O(n^2) comparison.

### Combinatorics

With 16 words per bucket:

- 16 adj × 16 noun = 256 combinations per letter-pair
- 26 × 26 = 676 letter-pairs (hour × minute mapping)
- 256 × 676 = 173,056 unique adj-noun combinations
- × N commands = 173,056 × N total unique names

Collisions are effectively impossible in normal use.

### Line Count Impact

| File       | Before | After | Change |
| ---------- | ------ | ----- | ------ |
| naming.zig | 209    | 166   | -43    |

The file is actually shorter despite 4× more words because: removed per-line
comments (letter comments moved to end of line), removed doc comment verbosity,
and the fixed-size array declaration is more compact.

### Testing

- Build: Clean
- Unit tests: All passing (4 tests in naming.zig, including new uniqueness test)

---

## 2026-02-07: Session 39 - Architecture Review (3-session checkpoint)

Last review was session 36. This is the fourth consecutive architecture review
where the codebase is fundamentally healthy. The project is mature.

### Codebase Stats

| File         | Lines     | Change from S36 | Purpose                    |
| ------------ | --------- | --------------- | -------------------------- |
| main.zig     | 973       | +31             | CLI entry point            |
| http.zig     | 898       | 0               | Web server, SSE, routing   |
| client.zig   | 636       | +16             | Native client, viewport    |
| auth.zig     | 556       | 0               | JWT/HMAC, OTP exchange     |
| session.zig  | 526       | 0               | Daemon, poll loop          |
| config.zig   | 454       | 0               | JSON config parsing        |
| vthtml.zig   | 375       | 0               | VT→HTML, delta computation |
| terminal.zig | 335       | 0               | ghostty-vt wrapper         |
| index.html   | 220       | 0               | Web frontend               |
| naming.zig   | 209       | new             | Auto-name generation       |
| protocol.zig | 192       | 0               | Wire format                |
| keybind.zig  | 185       | +11             | Input state machine        |
| pty.zig      | 140       | 0               | PTY operations             |
| signal.zig   | 48        | 0               | Signal handling            |
| paths.zig    | 43        | 0               | Shared utilities           |
| **Total**    | **5,790** | **+267**        | 15 files                   |

Build: Clean. Tests: All passing.

### Codebase Health

**Good.** The +267 line growth from session 36 is almost entirely from two
additions: naming.zig (209 lines, new module) and the status bar/leader hint
revamp (keybind +11, client +16, main +31). No file exceeds 973 lines. No
circular dependencies. Module boundaries remain clean.

11 of 15 files are completely unchanged since session 36. The core is done.

### What's Working Well

**1. Stability.** Protocol, session, terminal, pty, signal, paths, auth, config,
vthtml, http - 10 modules unchanged for 6+ sessions. These are finished code.

**2. naming.zig is well-isolated.** New module added cleanly with zero coupling
to the rest of the system. Three tests. Only imported by main.zig. This is how
new features should land.

**3. Status bar revamp (session 37) improved UX significantly.** Moving from
full inverse video to dim text was the right call. The curated leader hint (5
actions vs 14) reduces noise without losing discoverability.

**4. Bug density remains very low.** No bugs reported in sessions 37-38. The
only fix in this window was the Ctrl+Space fix in session 36, which was a
one-line classification error.

### Issues Found

**1. naming.zig Q-nouns bucket has a duplicate**

Line 92: `&.{ "quay", "quad", "quay", "quiz" }` - "quay" appears twice. This
reduces the effective vocabulary. Will be fixed when expanding to 16 words.

**2. naming.zig word selection math with 16-word buckets**

Currently: `adj_bucket[second % 4]` and `noun_bucket[(second / 4) % 4]`. With 16
words: `second % 16` covers 0-15 directly (60 seconds, 16 words = each word maps
to ~3.75 seconds). For nouns: `(second / 4) % 16` gives 0-14 range (since
second/4 maxes at 14). Need to rethink the jitter for 16-word buckets.

Better approach with 16 words: use `second % 16` for adjective selection and a
different time component (or hash) for noun selection. Since we have 16×16 = 256
combinations per letter-pair per command, collisions become very unlikely. Could
use `(epoch_secs / 4) % 16` for nouns to get different cycling.

**3. executeAction repetition in client.zig**

Lines 173-212: Eight scroll actions all follow the same pattern:
`self.viewport.moveX(); self.renderViewport(); self.renderStatusBar();`. This is
40 lines that could be 5 with a helper or grouping the scroll actions.

Not critical, but it's the kind of thing that Rich Hickey would notice as
"incidental complexity." The viewport operation varies, but the render + status
pattern is identical across all 8.

### New Inbox Items Analysis

**1. 16 words per bucket (naming.zig)**

Currently 4 words × 26 letters × 2 lists = 208 words. With 16 words: 16 × 26 × 2
= 832 words.

This is a content task, not an architecture task. The module structure doesn't
change. The word selection math needs adjustment (see issue #2 above).

Combinatorics: 16 adj × 16 noun × N commands = 256N unique names per
letter-pair. With 26×26 = 676 letter-pairs, that's 173,056 × N names before any
suffix probing. Collisions become essentially impossible in normal use.

Assessment: Straightforward. ~350 lines of wordlists (up from ~110), plus a
small math change. naming.zig will grow to ~450 lines, which is fine for a
self-contained wordlist module.

Priority: Do it next session (40). The user explicitly asked for it.

**2. Autostart HTTP daemon**

Still in inbox from session 36. The cleanest approach: a `--serve` flag on
`vanish new` that checks if an HTTP server is already running (try binding the
port or checking a PID file), and spawns one if not.

Alternative: config option `"auto_serve": true`. Checked in cmdNew().

Implementation: ~30-40 lines in main.zig. Need to decide: fork a separate
process (like the session daemon), or embed in the session daemon.

Embedding in the session daemon would mean each session runs its own HTTP server
on a different port. That's wrong - the HTTP server should be shared across all
sessions. So it must be a separate process.

Flow: `vanish new --serve -a zsh` → fork session daemon → check if HTTP server
is running → if not, fork HTTP server → attach.

Priority: Medium. Useful but not blocking anything.

**3. Render deduplication across viewer sizes**

Analyzed in session 36, verdict was "not worth it." The per-client ScreenBuffer
is ~7.5KB and the diff is O(cells), which is trivial. The optimization would add
complexity for negligible benefit with few concurrent web viewers.

Assessment unchanged. Skip.

**4. Brotli/gzip compression**

Also analyzed in session 36. SSE + compression has flush semantics issues. The
current delta payloads are small (few hundred bytes typically). Not worth the
complexity.

Could revisit if someone reports slow web terminal over high-latency links. But
even then, the delta approach already minimizes data transfer.

Assessment unchanged. Skip unless user reports performance issues.

### Simple vs Complected Analysis

**Simple (good):**

- Everything from session 36 remains simple
- naming.zig: pure function, no I/O except timestamp, no side effects
- Status bar revamp: less code, better UX
- Leader hint deduplication: clean seen-array approach

**Watch items:**

- naming.zig will grow significantly with 16 words per bucket. Keep the
  structure flat (just bigger arrays). Don't try to get clever with word
  generation or compression.

- client.zig executeAction scroll repetition (noted above). Consider a
  `handleScroll(comptime fn)` helper if adding more scroll variants, but don't
  refactor now since the current 8 are stable.

- index.html at 220 lines. Mobile modifier buttons will push this past 250.
  Previous reviews noted splitting JS into a separate file at that point. Still
  valid advice.

**No complected code found.** Architecture remains clean.

### Inbox Status

| Item                     | Status | Priority | Notes                     |
| ------------------------ | ------ | -------- | ------------------------- |
| 16 words per bucket      | ○ Todo | **High** | User explicitly asked     |
| Autostart HTTP daemon    | ○ Todo | Medium   | Config flag + spawn logic |
| Render deduplication     | ✗ Skip | -        | Not worth the complexity  |
| Brotli/gzip compression  | ✗ Skip | -        | Not worth the complexity  |
| Mobile modifier buttons  | ○ Todo | Medium   | Ctrl/Alt/Esc toolbar      |
| Web refresh button       | ○ Todo | Medium   | Close+reopen SSE          |
| Cursor position (narrow) | ○ Todo | Low      | Needs investigation       |
| Session list SSE         | ○ Todo | Low      | Reactive web session list |
| Man page, readme         | ○ Todo | Medium   | Documentation             |
| Arch PKGBUILD            | ○ Todo | Low      | Packaging                 |

### Recommendations for Next Sessions

1. **Session 40:** Expand naming.zig to 16 words per bucket. User explicitly
   requested this. Fix the Q-nouns duplicate. Adjust word selection math for
   larger buckets. Content-heavy but architecturally simple.

2. **Session 41:** Mobile modifier buttons for web terminal. Or autostart HTTP
   daemon. Both are medium priority.

3. **Session 42 (review):** Assess documentation needs. By then we'll have the
   naming expansion done and can focus on polish.

---

## 2026-02-07: Session 38 - Auto-Name Sessions

Implemented the `--auto-name` / `-a` flag for `vanish new`.

### What Changed

**New file: naming.zig (~170 lines)**

- Two wordlists: 26 adjective buckets (A-Z) and 26 noun buckets (A-Z), 4 words
  each. All words are short (3-4 chars) to keep names compact.
- `generate()`: Maps current hour → adjective letter, minute → noun letter.
  Second is used as jitter to pick the specific word within each 4-word bucket.
  Command name (basename of argv[0], truncated to 12 chars) appended as suffix.
  Format: `adjective-noun-command` (e.g. "dark-knot-zsh").
- `nameExists()`: Checks if a socket exists at the given path.
- `generateUnique()`: Calls `generate()`, then linear probes with numeric
  suffixes (2-9) on collision.
- 3 unit tests.

**main.zig:**

- Added `naming` import.
- `cmdNew()` now parses `--auto-name` / `-a` flag in a while loop (previously
  only checked first arg for `--detach`).
- When `--auto-name` is set, the session name is generated instead of read from
  args. Command is the first positional arg (name arg is not consumed).
- Generated name printed to stderr so user knows what was created.
- Usage text updated.

### Usage

```sh
# Auto-name a session
vanish new --auto-name zsh
# stderr: dark-knot-zsh
# (attaches automatically)

# Auto-name + detach
vanish new -a -d zsh
# stderr: calm-nest-zsh
# (returns to shell)

# Traditional explicit name still works
vanish new myshell zsh
```

### Design Notes

- **Time correlation**: Names created in the same hour start with the same
  adjective letter. Names created in the same ~2-minute window share the same
  noun letter. This gives rough temporal ordering when listing sessions.
- **Jitter**: The second component picks which word from the 4-word bucket,
  preventing two sessions created in quick succession from getting the same
  name.
- **Collision handling**: Linear probe with numeric suffix. With 4×4=16 possible
  combinations per time bucket plus suffix probing, collisions in normal usage
  are negligible.
- **Command suffix**: Makes names immediately useful - "calm-nest-zsh" vs
  "calm-nest-nvim" distinguishes purpose at a glance.

### Line Count Impact

| File       | Before | After | Change   |
| ---------- | ------ | ----- | -------- |
| naming.zig | -      | 170   | +170     |
| main.zig   | 942    | 962   | +20      |
| **Net**    |        |       | **+190** |

### Testing

- Build: Clean
- Unit tests: All passing (3 new in naming.zig)
- Integration tests: 19/19 passing
- Manual test: `vanish new -a -d zsh` → created "dark-knot-zsh", listed, killed

---

## 2026-02-07: Session 37 - Status Bar Revamp

Redesigned the status bar and leader hint to be minimal and unobtrusive.

### What Changed

**client.zig - `renderStatusBar()`:**

Before: Full-width inverse video bar (`\x1b[7m`). Session name padded to fill
entire line. "primary" or "viewer" always shown on right. Dense, high-contrast,
visually heavy.

After: No background/inverse. Dim `─` prefix, normal session name. Right side in
dim text. Only shows contextually relevant info:

- "viewer" only when in viewer mode (primary is the default, no need to say it)
- Panning offset only when offset is non-zero
- Session dimensions only when panning is possible

Also added `\x1b[K` (clear line) on positioning to prevent leftover characters.

**keybind.zig - `formatHint()`:**

Before: All 14 bindings crammed into one inverse video bar with `|` separators.
Included pan binds (h/j/k/l/g/G/^U/^D) which are only relevant for viewers with
smaller terminals. Two detach binds shown (`d` and `^A`).

After: Curated set of 5 actions (detach, scrollback, status, takeover, help).
Bold keys with dim `│` separators, no inverse video. Deduplicated by action
(won't show both `d` and `^A^A` for detach). Pan binds available via `?` help.

Added `isHintBind()` filter and a `seen` array for deduplication.

**client.zig - `showHint()`:**

Added `\x1b[K` before writing hint content. Without this, the new non-full-width
hint would leave stale characters from previous renders.

### Visual Comparison

Before (status bar):

```
mysession                                                        primary
```

(full inverse video, entire line)

After (status bar):

```
─ mysession                                              viewer  120x50
```

(dim framing, only relevant info, no background)

Before (leader hint):

```
^A: d:detach | ^A:detach | [:scrollback | h:pan left | j:pan down | ...
```

(all bindings, inverse video, overflows on narrow terminals)

After (leader hint):

```
─  d detach │[ scrollback │s toggle status │t takeover │? help
```

(curated, bold keys, dim separators)

### Line Count Impact

| File        | Before | After | Change  |
| ----------- | ------ | ----- | ------- |
| client.zig  | 621    | 625   | +4      |
| keybind.zig | 175    | 185   | +10     |
| **Net**     |        |       | **+14** |

### Testing

- Build: Clean
- Unit tests: All passing
- Integration tests: 19/19 passing

---

## 2026-02-07: Session 36 - Ctrl+Space Fix + Architecture Review

### Bug Fix: Ctrl+Space Leader Key

The user reported Ctrl+Space still doesn't work as leader despite session 28
claiming to fix it. Session 28 fixed config _parsing_ (correctly storing 0x00 as
the leader byte) but missed the actual input detection in client.zig.

**Root cause:** `client.zig:131` had `const is_ctrl = byte >= 1 and byte <= 26`.
This excludes 0x00 (Ctrl+Space) from being recognized as a control key. When
Ctrl+Space arrives as byte 0x00, `is_ctrl` was `false`, so
`isLeaderKey(0x00,
false)` didn't match the config's `(0x00, true)`.

**Fix:** Extended the range to also cover 0x00 and 0x1C-0x1F:
`const is_ctrl = byte == 0 or (byte >= 1 and byte <= 26) or (byte >= 0x1C and byte <= 0x1F);`

This was a classic case of fixing the parser but not the consumer. The config
system, keybind state machine, and JSON serialization were all correct - only
the byte-to-ctrl classification at the point of input was wrong.

### Architecture Review (3-session checkpoint)

Last review was session 33.

### Codebase Stats

| File         | Lines     | Change from S33 | Purpose                    |
| ------------ | --------- | --------------- | -------------------------- |
| main.zig     | 942       | 0               | CLI entry point            |
| http.zig     | 898       | +36             | Web server, SSE, routing   |
| client.zig   | 620       | 0               | Native client, viewport    |
| auth.zig     | 556       | 0               | JWT/HMAC, OTP exchange     |
| session.zig  | 526       | 0               | Daemon, poll loop          |
| config.zig   | 454       | 0               | JSON config parsing        |
| vthtml.zig   | 375       | 0               | VT→HTML, delta computation |
| terminal.zig | 335       | 0               | ghostty-vt wrapper         |
| index.html   | 220       | +35             | Web frontend               |
| protocol.zig | 192       | 0               | Wire format                |
| keybind.zig  | 174       | 0               | Input state machine        |
| pty.zig      | 140       | 0               | PTY operations             |
| signal.zig   | 48        | 0               | Signal handling            |
| paths.zig    | 43        | 0               | Shared utilities           |
| **Total**    | **5,523** | **+71**         | 14 files                   |

Build: Clean. Tests: All passing.

### Codebase Health

**Excellent.** Growth from session 33 to 36 is +71 lines, entirely from the web
resize endpoint (http.zig +36) and frontend resize/measurement (index.html +35).
The Zig source files have been essentially unchanged for 6 sessions. This is a
healthy sign - the core architecture is stable.

### What's Working Well

**1. Core is rock solid.** No changes needed to protocol, session, terminal,
keybind, pty, signal, or paths in 6 sessions. These modules are done.

**2. Module boundaries are excellent.** No file exceeds 942 lines. No circular
dependencies. Each module has single responsibility. The dependency graph flows
cleanly downward.

**3. Web terminal is functional.** Delta streaming, resize, input routing
through SSE client - all working. The architectural choice to route web input
through the SSE client's session socket (session 32) was correct and simplified
the code.

**4. Bug density is low.** The Ctrl+Space bug was a classification oversight,
not an architectural problem. The fix was a one-line change.

### New Inbox Items Analysis

**1. Autostart HTTP daemon on session start**

Would require: a config flag (`"autostart_serve": true` or CLI
`--serve`/`--with-http`), and `cmdNew()` spawning the HTTP server as a
background process alongside the session daemon. Could fork twice (once for
session daemon, once for HTTP server), or have the session daemon optionally
embed the HTTP server.

Assessment: The cleanest approach is a `--serve` flag on `vanish new` that forks
an additional process for the HTTP server. Or better: a config option that makes
`vanish new` automatically run `vanish serve` in the background if not already
running. Check if a serve process exists first (PID file or try binding the
port).

Complexity: Low. Implementation is straightforward.

**2. Auto-name sessions (adjective-noun, A→Z progression)**

The user wants a `--auto-name` or similar flag that generates names like
"amber-nest", progressing A→Z through the hour for adjectives and tracking hours
for nouns. This is a fun, deterministic naming scheme.

Design: Embed two wordlists (26 adjectives A-Z, 24-26 nouns A-Z). Map current
minute (0-59) to letter index with some jitter. Map current hour (0-23) to noun
index. Check for conflicts, pick adjacent if needed.

Complexity: Low. Self-contained function, no architectural impact. Maybe 30-40
lines for the wordlists + generation logic.

**3. Revamp status bar**

Current status bar: full-width inverse video bar showing session name (left) and
role (right). User says it's "garish and dense."

Alternatives to consider:

- **Zellij style**: Tab-like segments, subtle colors, only key info. Bottom bar
  with mode indicator and session name.
- **Helix style**: Minimal mode indicator on the left, file/position info on the
  right. Very clean, muted colors.
- **mini.nvim style**: Ultra-minimal, just colored mode word + filename. No
  full-width bar, just the text needed.

Recommendation: Go with a helix-like approach. Instead of full inverse video
bar, use subtle colored text. Show mode only when relevant (viewer vs primary
only when it matters). The status bar should feel like it belongs to a terminal
tool, not a full IDE.

Possible redesign:

```
vanish ─ mysession                              viewer ─ 80×24
```

With muted colors (dim white, maybe a subtle accent for the session name). No
inverse video. Just text.

Or even more minimal - only show when something is noteworthy. If you're the
primary on a normal-sized session, show nothing. If you're a viewer, show
"viewer" somewhere unobtrusive.

**4. Render deduplication across viewer sizes**

The idea: if we're rendering 80×24 and 120×50 for two viewers, the 80×24 render
could be derived from the 120×50 render (it's a subset). Currently each SSE
client has its own ScreenBuffer and does its own diff against the VTerminal.

Assessment: The current approach is already efficient. Each ScreenBuffer is
~7.5KB. The diff computation is O(cols × rows) per client, which is trivial (<
2000 cells). The actual VTerminal reading is the shared part, and we already
only have one VTerminal per session.

The optimization would save: one vthtml.updateFromVTerm() call per additional
viewer of the same or smaller size. Given that we expect few concurrent web
viewers, this optimization would add complexity for negligible benefit.

Verdict: Not worth it. The current per-client ScreenBuffer approach is already
O(n) where n is cells, and the constant is tiny.

**5. Brotli compression on HTTP server**

Would reduce SSE payload sizes. The cells JSON is repetitive (lots of `data-x`,
`data-y`, `<span>` patterns). Brotli would compress well.

Assessment: This requires linking a brotli library or implementing compression.
Zig doesn't have brotli in std. Could use gzip (available in std.compress) as a
simpler alternative. The `Accept-Encoding` header negotiation is
straightforward.

Complexity: Medium. Need to handle content negotiation, buffer management for
compressed output, and flush semantics for SSE (each event must be a complete
compressed frame). SSE + compression has subtleties around flushing.

Verdict: Nice-to-have, not urgent. The current payloads are small (delta updates
are typically a few hundred bytes). Could use gzip from std instead of requiring
an external brotli dependency.

### Simple vs Complected Analysis

**Simple (good):**

- Everything from previous reviews remains simple
- The Ctrl+Space fix shows the system is well-factored: the bug was isolated to
  one line in one file

**Watch items:**

- index.html at 220 lines. Adding mobile modifier buttons will push it past 250.
  Consider splitting JS into a separate file when that happens.
- The "autostart serve" feature could add complexity to cmdNew(). Keep the logic
  clean - check if server is running, spawn if not, don't try to embed the
  server in the session daemon.

**No complected code found.** The architecture remains clean.

### Inbox Status

| Item                     | Status | Priority | Notes                     |
| ------------------------ | ------ | -------- | ------------------------- |
| Ctrl+Space leader        | ✓ Done | -        | Session 36                |
| Autostart HTTP daemon    | ○ Todo | Medium   | Config flag + spawn logic |
| Auto-name sessions       | ○ Todo | Low      | Fun, self-contained       |
| Revamp status bar        | ○ Todo | Medium   | Design first, then impl   |
| Render deduplication     | ✗ Skip | -        | Not worth the complexity  |
| Brotli/gzip compression  | ○ Todo | Low      | Nice-to-have              |
| Mobile modifier buttons  | ○ Todo | Medium   | Ctrl/Alt/Esc toolbar      |
| Web refresh button       | ○ Todo | Medium   | Close+reopen SSE, simple  |
| Cursor position (narrow) | ○ Todo | Low      | Needs investigation       |
| Session list SSE         | ○ Todo | Low      | Reactive web session list |
| Man page, readme         | ○ Todo | Medium   | Documentation             |
| Arch PKGBUILD            | ○ Todo | Low      | Packaging                 |

### Recommendations for Next Sessions

1. **Session 37:** Status bar revamp. Design and implement a cleaner, more
   minimal status bar. This affects both native experience and user perception.
   Good design task.

2. **Session 38:** Auto-name sessions. Fun feature, self-contained, low risk.
   Also a good time to add the `--serve` flag for autostarting the HTTP daemon.

3. **Session 39 (review):** Mobile modifier buttons for web terminal. By then
   we'll have the status bar sorted and can focus on the web experience.

---

> Earlier session notes (1-35) archived to
> [doc/sessions-archive.md](doc/sessions-archive.md).
