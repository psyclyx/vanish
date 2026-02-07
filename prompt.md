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

## 2026-02-07: Initial Implementation

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
- Using direct posix syscalls rather than Zig 0.15's new Io API (simpler, more control)
- Binary protocol with 5-byte header (1 type + 4 len) + payload
- Single poll loop for all I/O in session daemon
- PTY master/slave for child process

### Next Steps
1. **ghostty-vt integration** - Add terminal emulation for state preservation
2. **Leader key handling** - Intercept input for keybindings
3. **Status bar** - Render at bottom of terminal
4. **Keybinding help overlay** - Show available bindings
5. **Viewer mode** - Read-only clients
6. **Scroll mode** - Navigate scrollback
7. **Configuration** - Leader key, scrollback size, etc.
8. **Signal handling** - SIGWINCH for resize, SIGTERM for cleanup

### Open Questions
- ghostty-vt API stability - need to track upstream changes
- Viewer resize handling - adapt rendering or use primary's size?
- Scrollback sync between clients

### Code Quality Notes
- Zig 0.15 has significant API changes from 0.13/0.14
- ArrayList is now "unmanaged" - allocator passed to each function
- Stream.writer() now requires a buffer parameter
- Need to handle NixOS paths (no /bin/echo, etc.)
