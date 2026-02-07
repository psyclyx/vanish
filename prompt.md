CLAUDE NOTE: you are being run in a loop. pick one thing to do, and do it. it
need not be code, but should advance the project. code, documentation, hammock
time (with notes), etc etc. just make sure you update the log every time.

# Requests:

Ongoing:

- Every 3 sessions, take some time to interrogate your abstractions. Is this
  architecture sound? Is the code maintainable? What's working? What isn't?
  What's simple, and what's complected? Think about the long term. You'll have
  to maintain this, don't make that hard on yourself.

Inbox:

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

lightweight libghostty terminal session multiplexer

- dtach is great, but the fact that it only passes bytes through limits it.
- to preserve the state of the terminal as a user would see it, and for
  scrollback, a terminal emulator is needed (tmux does this)
- most terminal emulators are bad
- libghostty is good

- supports up to 1 primary consumer per session at a time. this session
  determines the height/width, and can write to the session.
- supports any number of view-only consumers
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
- session management is like dtach - a socket.
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
- by default, closing the process exits the session, but there's a keybinding /
  command to detach. (the intent is to make this convinient to use for every
  terminal, and detach when needed.
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

## 2026-02-07: Session 8 - Session Takeover

Implemented the inbox item for session takeover:
> You may already have it, but can you please make sure we can take over
> sessions from viewers? If sizes differ, we'll send a resize to the emulated
> terminal, and switch the other session to viewer mode.

### Completed

- [x] Protocol: Added `ClientMsg.takeover` (0x06) for viewer requesting takeover
- [x] Protocol: Added `ServerMsg.role_change` (0x86) with `RoleChange` struct
- [x] Session: `handleTakeover()` demotes current primary (if any) to viewer, promotes requester
- [x] Session: Resizes terminal to new primary's size
- [x] Client: Keybind `Ctrl+A t` sends takeover request (only for viewers)
- [x] Client: Handles `role_change` message, updates role and status bar
- [x] Keybind: Added `takeover` action and default bind for 't'
- [x] Help: Updated help text to show takeover command
- [x] Test: Added keybind test for takeover

### Flow

1. Viewer presses `Ctrl+A t`
2. Client sends `ClientMsg.takeover` to session
3. Session:
   - If primary exists: sends `role_change(.viewer)` to old primary, moves to viewers list
   - Removes requester from viewers list
   - Sets requester as new primary
   - Sends `role_change(.primary)` to new primary
   - Resizes PTY and terminal to new primary's size
4. Both clients update their role and re-render status bar

### Inbox Items Status

- [x] Session takeover from viewers
- [ ] JSON config (config not implemented yet)
- [ ] Viewport panning (designed in session 7, not implemented)
- [ ] List/disconnect clients command
- [x] Background sessions on detach (already works)
- [x] XDG_RUNTIME_DIR default path (already works)
- [x] --json flag for list (already works)

---

## 2026-02-07: Session 7 - Viewport Panning Design (Hammock Session)

Re-reading the inbox item on scrolling, I now understand the actual requirement:

> However, for full-screen apps, viewers may be smaller than the primary
> session, in height and/or width. That's what the scrolling is for - to pan
> around a terminal larger than the bounds of the viewer.

This is NOT about scrollback history. It's about **viewport panning**: when a viewer's
terminal is smaller than the session's terminal, the viewer needs to be able to see
different parts of the larger screen.

### Current Implementation (Wrong)

The current scroll mode:
1. User presses Ctrl+A k/j
2. Client enters "scroll mode" and requests scrollback
3. Session dumps plaintext scrollback content
4. Any key exits scroll mode

This is scrollback navigation, which the user explicitly says they DON'T want:
> I think we explicitly don't want an additional scrollback thing in the viewer

### Correct Design: Viewport Panning

**Concept:**
- Session terminal has size (session_cols, session_rows), e.g., 120x50
- Viewer terminal has size (viewer_cols, viewer_rows), e.g., 80x24
- Viewer maintains a viewport offset (vx, vy) into the session screen
- hjkl moves the viewport, showing a different portion of the session screen

**Key insight:** This is rendering logic, not protocol logic. The session already
sends full terminal state. The viewer needs to:
1. Know the session's terminal size (need protocol change)
2. Track its own viewport offset
3. Render only the visible portion

**Protocol Change Needed:**
```
Welcome struct should include session terminal size:
  Welcome = extern struct {
      role: Role,
      session_id: [16]u8,
      session_cols: u16,  // NEW
      session_rows: u16,  // NEW
  };
```

Also need a new message when session resizes (when primary resizes):
```
ServerMsg.resize = 0x86  // Server tells viewers the new session size
```

**Client-Side Viewport Logic:**

```
Viewport = struct {
    // Session (what we're viewing into)
    session_cols: u16,
    session_rows: u16,

    // Local terminal (our window)
    local_cols: u16,
    local_rows: u16,

    // Offset into session screen (top-left corner of our view)
    offset_x: u16 = 0,
    offset_y: u16 = 0,

    fn needsPanning(self: *const Viewport) bool {
        return self.session_cols > self.local_cols or
               self.session_rows > self.local_rows;
    }

    fn moveUp(self: *Viewport) void {
        if (self.offset_y > 0) self.offset_y -= 1;
    }

    fn moveDown(self: *Viewport) void {
        const max_y = if (self.session_rows > self.local_rows)
            self.session_rows - self.local_rows else 0;
        if (self.offset_y < max_y) self.offset_y += 1;
    }

    // Similar for left/right
};
```

**Rendering Approach:**

Two options:

1. **Server-side clipping**: Viewer tells server its size + offset, server sends
   only the visible portion. More efficient network-wise, but complicates server.

2. **Client-side clipping**: Server sends full VT output, client parses and renders
   only the visible portion. Simpler protocol, requires VT parsing on client.

I prefer option 2 because:
- Keeps server simple (no per-client viewport state)
- Viewers are already receiving all output anyway
- Client already has terminal size info

**However**, there's a problem: The server sends raw VT sequences. Clipping VT
sequences client-side is complex because cursor positions, colors, and other state
are relative to the full terminal, not our viewport.

**Better approach: Server-side rendering per-client**

Actually, let me reconsider. The session already has the ghostty-vt terminal with
the full screen state. For each viewer, instead of forwarding raw PTY output, we
could send a clipped version of the screen.

But this changes the architecture significantly:
- Currently: forward raw bytes → simple, real-time
- Proposed: render per-client → more work, slight latency

**Simplest approach: Let viewers receive full output, track state locally**

Each viewer could maintain its own ghostty-vt terminal instance, same size as the
session. When the user pans, they see a different portion of their local copy.

Pros:
- No protocol changes for output
- Viewers stay in sync automatically
- Panning is instant (local operation)

Cons:
- More memory on viewer (another terminal instance)
- Need to sync terminal size

This is actually elegant. The viewer becomes:
1. Connect, receive Welcome with session size
2. Create local VTerminal with session size
3. Feed all output to local terminal
4. Render viewport into local terminal
5. hjkl adjusts viewport offset

**Implementation Plan:**

1. Protocol: Add session_cols/rows to Welcome
2. Protocol: Add ServerMsg.session_resize when primary resizes
3. Client: Maintain local VTerminal (same size as session)
4. Client: Feed output to local terminal instead of direct stdout
5. Client: Add Viewport struct to track offset
6. Client: Render visible portion of local terminal
7. Keybinds: hjkl adjust viewport when session > local size
8. Remove current scroll mode (dump scrollback)

**What about scrollback?**

The user says they don't want an "additional scrollback thing." But maybe we keep
it simple: dump scrollback to stdout and let the user's terminal handle it. That's
what we have now for Ctrl+A k/j.

Actually, re-reading again:
> for the scrollback mode, handle it by literally just dumping n lines of
> scrollback to the terminal - we don't want to have to deal with our own
> scrolling, just use the terminals

So the current scrollback dump approach IS correct for scrollback. But the hjkl
bindings should be for **viewport panning**, not scrollback. We need both features.

**Revised Keybinds:**
- Ctrl+A hjkl: viewport panning (when session > viewer size)
- Ctrl+A g/G: jump to top-left / bottom-right of session
- Ctrl+A [ or similar: enter scrollback mode (dump scrollback, exit on key)

But this might be too many modes. Let me think...

Actually the prompt says:
> consumers typically have scrolling commands available on hjkl

So hjkl should be for panning. The scrollback dump could be a separate thing,
maybe Ctrl+A [ (like tmux copy mode entry).

### Decision

1. **Viewport panning (hjkl)**: When session is larger than viewer, hjkl pans
2. **Scrollback dump**: Separate keybind (Ctrl+A [) dumps scrollback to terminal
3. **Status indicator**: When viewport != (0,0), show "[+x,+y]" in status bar

### Not Doing This Session

This is a significant change. I've documented the design. Implementation will be
in a future session after validating this approach makes sense.

### Questions for User

- Is the "local VTerminal per viewer" approach acceptable (memory trade-off)?
- Should viewport panning work for primary too, or just viewers?
- Is Ctrl+A [ a good keybind for scrollback dump?

---

## 2026-02-07: Session 6 - Architecture Review (Hammock Session)

Per the "every 3 sessions" rule, taking time to interrogate the abstractions.

### What's Working Well

**1. Module Boundaries Are Clean**
- Each file has a single responsibility: pty.zig does PTY, terminal.zig wraps ghostty-vt,
  protocol.zig handles wire format, keybind.zig manages key state
- No circular dependencies
- Low coupling between modules

**2. Protocol Is Simple and Correct**
- 5-byte header (1 type + 4 len) is easy to parse and debug
- Message types are well-separated (0x01-0x0F client, 0x81-0x8F server)
- External structs for wire format prevent ABI issues

**3. Single Event Loop per Process**
- Session uses poll() over dynamic fd list - simple, efficient
- Client uses fixed 2-fd poll - even simpler
- No threading, no async runtime - just synchronous POSIX

**4. State Machines Are Explicit**
- Keybind state: normal → leader → action
- Client state: running, hint_visible, in_scroll_mode
- Easy to reason about

### What Could Be Better

**1. Scrolling Semantics Are Confused**
The inbox clarifies this: scrolling is for *panning* around a terminal larger than
the viewer, NOT for navigating scrollback in the traditional sense. Current
implementation treats scroll mode as "dump scrollback then exit" which misses the point.

**The actual need:**
- Viewer might be 80x24, session might be 120x50
- User needs hjkl to pan around the 120x50 viewport
- This is more like a viewport into a larger screen, not scrollback

**What we have:**
- dumpScrollback() which gives text content
- Scroll mode that dumps and exits on any key

**What we need:**
- Track viewport offset (x, y) relative to session terminal size
- Render only the visible portion
- hjkl adjusts viewport, not scrollback position
- This is fundamentally different from what we have

**2. Session Takeover Not Implemented**
The inbox mentions viewers should be able to take over as primary. This requires:
- New protocol message: "takeover" from client
- Session logic: demote current primary to viewer, promote requester
- Handle size mismatch: resize terminal to new primary's size

Currently, if primary exists, new primary is denied. Need to add takeover flow.

**3. Client Management Missing**
No way to:
- List connected clients
- Disconnect a specific client
- See client metadata (size, connection time)

This needs:
- Protocol messages for client list query/response
- Protocol message for disconnect command
- CLI commands: `vanish clients <session>`, `vanish kick <session> <client-id>`

**4. Config Not Implemented Yet**
User wants JSON instead of TOML. That's fine - JSON is simpler anyway.
But config isn't implemented at all yet. Need:
- ~/.config/vanish/config.json
- Leader key override
- Default keybinds
- Socket directory override

**5. Minor Code Smells**

a) **Client struct in client.zig is doing too much** - it handles input, rendering,
   scroll mode, status bar. Could split into smaller pieces, but not critical.

b) **signal.zig uses global mutable state** - This works but makes testing harder.
   Could pass signal state as parameter, but overhead may not be worth it.

c) **handleClientInput in session.zig has a large switch** - Could use a dispatch
   table, but current approach is explicit and readable.

### Simplicity Analysis (Simple vs Easy)

**Simple (good):**
- Protocol: one-way data flow, no RPC semantics, no acks
- PTY: thin wrapper around system calls
- Session: single loop, no threads
- Keybind: pure state machine, no side effects in processKey

**Potentially Complected:**
- Scroll mode: conflating scrollback navigation with viewport panning
- Client state: hint_visible, in_scroll_mode, show_status are separate booleans;
  could be a single enum Mode { normal, leader, scroll, help }

### Priority Actions for Future Sessions

1. **Fix scroll semantics** - This is a design issue. Viewport panning, not scrollback.
2. **Add session takeover** - Protocol + session logic
3. **Add client management** - List/disconnect
4. **Add config file** - JSON format

### Not Urgent

- Refactoring signal.zig (works fine)
- Splitting Client struct (it's not that big)
- Test coverage (we have basics, can add more incrementally)

---

## 2026-02-07: Session 5 - JSON Output for Scripting

### Completed

- [x] `--json` flag for `vanish list` command
  - Machine-readable output: `{"sessions":[{"name":"foo","path":"/run/user/1000/vanish/foo"}]}`
  - Proper JSON escaping for special characters
  - Error case returns `{"error":"..."}` format
  - Empty case returns `{"sessions":[]}`

### Inbox Review

Items remaining:
- JSON vs TOML for config file (config not yet implemented)
- Session takeover from viewers (allow viewer to become primary)
- List/disconnect users command
- Scrolling clarification addressed in previous sessions

Already implemented:
- Background sessions on detach (session keeps running when primary detaches)
- XDG_RUNTIME_DIR default socket path
- --json flag (done this session)

---

## 2026-02-07: Session 4 - Documentation and Testing

### Completed

- [x] Send command (`vanish send <name> <keys>`) for scripting
- [x] README.md with usage, keybindings, installation
- [x] Updated DESIGN.md to reflect current implementation
- [x] Comprehensive tests for keybind, protocol, pty, terminal
  - keybind: escape cancel, scroll actions, hint formatting
  - protocol: term truncation, header size, message type values
  - pty: resize operation
  - terminal: resize, scrollback dump

### Test Coverage

All modules now have meaningful tests:

- keybind.zig: 5 tests
- protocol.zig: 4 tests
- pty.zig: 2 tests
- terminal.zig: 4 tests

---

## 2026-02-07: Session 3 - UX Polish and Features

### Completed

- [x] Status bar (src/client.zig)
  - Toggleable with Ctrl+A s
  - Shows session name (left) and role (right)
  - Rendered on bottom line with inverse video
  - Hint display takes precedence over status bar
  - Re-renders after output when visible
- [x] Scroll mode (src/client.zig, src/terminal.zig, src/protocol.zig)
  - Scroll actions (k/j/g/G/Ctrl+U/Ctrl+D) enter scroll mode
  - Client requests scrollback via new `scrollback` protocol message
  - Session dumps scrollback content using ghostty-vt
  - User scrolls with their terminal's native scrollback
  - Any key exits scroll mode and refreshes screen
- [x] Session signal handling (src/session.zig)
  - Session now handles SIGTERM/SIGINT via sig.setup()
  - Graceful shutdown with client notification
  - Socket cleanup on exit
- [x] Viewer mode (src/client.zig, src/main.zig)
  - --viewer flag for attach command
  - Viewers don't send input (blocked client-side)
  - Status bar shows "viewer" role
- [x] Automatic socket path resolution (src/main.zig)
  - Session names without '/' stored in $XDG_RUNTIME_DIR/vanish/
  - Simpler usage: `vanish new myshell -- bash`
  - List command shows session names only in default dir

### Current Feature Set (MVP Complete)

- Create sessions: `vanish new <name> -- <command>`
- Attach to sessions: `vanish attach <name>`
- Viewer mode: `vanish attach --viewer <name>`
- List sessions: `vanish list`
- Keybindings (Ctrl+A as leader):
  - d: detach
  - s: toggle status bar
  - k/j: scroll up/down (enters scroll mode)
  - ?: show help
  - Esc: cancel leader mode
- Terminal state preservation via ghostty-vt
- Graceful signal handling

### Architecture Decisions

- Status bar is purely client-side rendering
- Scroll mode dumps entire screen content
- Session names use $XDG_RUNTIME_DIR/vanish/ by default

### Next Steps

1. **Configuration file** - TOML or similar for keybinds, leader key
2. **Tests** - More comprehensive unit tests

### Completed This Session

- [x] Send command - `vanish send <name> <keys>` for scripting
- [x] README.md - User documentation
- [x] Updated DESIGN.md - Reflects current state

### Open Questions Resolved

- Status bar content: session name + role (simple, useful)
- Scroll mode UX: any key exits, visual indicator shown
- Socket paths: names without / use default dir

---

## 2026-02-07: Session 2 - Core UX Features

### Completed

- [x] ghostty-vt integration (src/terminal.zig)
  - VTerminal wrapper around ghostty's Terminal
  - dumpScreen() uses TerminalFormatter with VT emit for screen sync
  - Session feeds PTY output through terminal emulator
  - New clients receive full terminal state as VT sequences
- [x] Leader key handling (src/keybind.zig)
  - Configurable leader key (default Ctrl+A)
  - Keybind state machine: normal -> leader mode -> action
  - Default bindings: d=detach, s=status, k/j=scroll, ?=help
- [x] Signal handling (src/signal.zig)
  - SIGWINCH for terminal resize
  - SIGTERM/SIGINT for graceful shutdown
  - Client forwards resize to session via protocol
- [x] Client keybind integration
  - Input interception for leader key
  - Keybind hint display on bottom line
  - Help overlay (Ctrl+A ?)

### Architecture Refinements

- Keybinds handled client-side (not session) - this is correct because:
  - Client controls its own terminal (raw mode)
  - Actions like detach are client-side
  - Overlays (hint, help) are client-side rendering
- VT screen dump preserves terminal state across client reconnect

### Next Steps

1. **Status bar** - Persistent status line (toggle with Ctrl+A s)
2. **Scroll mode** - Navigate scrollback with hjkl
3. **Viewer mode** - Read-only clients (input blocked)
4. **Configuration file** - TOML or similar for keybinds, leader key
5. **Session signal handling** - Cleanup on SIGTERM
6. **Tests** - More comprehensive unit tests

### Open Questions

- Status bar content: session name? client count? time?
- Scroll mode UX: how to exit? visual indicator?
- Configuration format and location (~/.config/vanish/?)

---

## 2026-02-07: Session 1 - Initial Implementation

### Completed

- [x] Nix infrastructure (shell.nix, default.nix, overlay.nix, .envrc)
- [x] Zig 0.15 build system (build.zig, build.zig.zon)
- [x] PTY management (src/pty.zig) - open, close, resize, spawn, wait
- [x] Binary protocol (src/protocol.zig) - Hello, Welcome, Input, Output, etc.
- [x] Session daemon (src/session.zig) - socket, poll loop, client management
- [x] Client attach (src/client.zig) - connect, raw mode, I/O forwarding
- [x] CLI (src/main.zig) - new, attach, list commands
- [x] Basic testing - session creation, attach, input/output working

### Architecture Decisions

- Using direct posix syscalls rather than Zig 0.15's new Io API (simpler, more
  control)
- Binary protocol with 5-byte header (1 type + 4 len) + payload
- Single poll loop for all I/O in session daemon
- PTY master/slave for child process

### Code Quality Notes

- Zig 0.15 has significant API changes from 0.13/0.14
- ArrayList is now "unmanaged" - allocator passed to each function
- Stream.writer() now requires a buffer parameter
- CallingConvention is `.c` not `.C`
- sigaction doesn't return error union
- Need to handle NixOS paths (no /bin/echo, etc.)
