# Vanish Architecture

## Overview

Vanish is a terminal session multiplexer using libghostty-vt for terminal
emulation. It provides dtach-like socket-based session management with proper
terminal state preservation.

## Core Concepts

### Session

A session is a pty + terminal emulator pair managed by a daemon process,
accessible via a Unix socket.

```
┌────────────────────────────────────────────────┐
│                    Session                     │
│  ┌─────────┐    ┌─────────────┐    ┌───────┐  │
│  │  PTY    │───▶│ ghostty-vt  │───▶│ State │  │
│  │ master  │    │  Terminal   │    │       │  │
│  └─────────┘    └─────────────┘    └───────┘  │
│       │                                  │     │
│       │              Unix Socket         │     │
│       ▼                  │               ▼     │
│  ┌─────────┐             │          ┌───────┐  │
│  │  Child  │             │          │Render │  │
│  │ Process │             │          │ Cache │  │
│  └─────────┘             │          └───────┘  │
└──────────────────────────┼─────────────────────┘
                           │
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
     ┌─────────┐     ┌──────────┐     ┌──────────┐
     │ Primary │     │ Viewer 1 │     │ Viewer N │
     │ Client  │     │ (r/o)    │     │ (r/o)    │
     └─────────┘     └──────────┘     └──────────┘
```

### Client Types

1. **Primary**: One per session. Can write input. Controls terminal size.
2. **Viewer**: Read-only. Sees rendered output. Can scroll in scrollback mode.

### Modes

1. **Passthrough**: Default. All input goes to child process.
2. **Leader**: Activated by leader key. Shows keybinding help. Bindings active.
3. **Scroll**: Navigate scrollback. hjkl movement (or configured keys).

## Protocol

Binary protocol over Unix socket. All multi-byte integers are little-endian.

### Message Format

```
┌─────────┬─────────┬──────────────────┐
│  Type   │  Len    │     Payload      │
│ (1 byte)│(4 bytes)│   (Len bytes)    │
└─────────┴─────────┴──────────────────┘
```

### Message Types

**Client → Session:**
- `0x01` Hello: `{ role: u8, term: [64]u8, cols: u16, rows: u16 }`
- `0x02` Input: raw bytes for pty
- `0x03` Resize: `{ cols: u16, rows: u16 }`
- `0x04` Detach: no payload

**Session → Client:**
- `0x81` Welcome: `{ role: u8, session_id: [16]u8 }`
- `0x82` Output: VT-encoded terminal state (differential)
- `0x83` Full: VT-encoded full terminal state (on connect/resize)
- `0x84` Exit: `{ code: i32 }`
- `0x85` Denied: `{ reason: u8 }` (e.g., primary already exists)

## Rendering Strategy

### For Scrolling Content

When the terminal is primarily scrolling text (e.g., compilation output, logs):

1. Maintain scrollback in ghostty-vt
2. On client connect: dump last N lines of scrollback as VT sequences
3. On new output: forward VT sequences to clients
4. Client uses their terminal's native scrollback

### For Full-Screen Apps

When running apps like vim/nvim that use the alternate screen:

1. On client connect: render full screen as VT sequences
2. On screen updates: send differential VT updates
3. Clients can enter scroll mode to pan around if their terminal is smaller

## Keybinding System

### Default Bindings (under leader)

- `d` - Detach
- `hjkl` - Scroll mode navigation (if in alternate screen mode)
- `q` - Quit scroll mode / Return to passthrough
- `?` - Show full keybinding help
- `s` - Toggle status bar

### Leader Key

Default: `Ctrl-\` (configurable)

When pressed:
1. Enter leader mode
2. Show unobtrusive keybinding hints (bottom right)
3. Wait for next key
4. Execute binding or return to passthrough if unbound

### Keybinding Help Overlay

Minimal: appears in corner, semi-transparent conceptually (rendered with dim attrs)

```
┌──────────────┐
│ d:detach     │
│ ?:help       │
│ q:quit       │
└──────────────┘
```

## Status Bar

Optional (toggled). Shows:
- Session name
- Mode (passthrough/scroll/leader)
- Viewer count
- Scroll position (if in scroll mode)

## File Structure

```
vanish/
├── src/
│   ├── main.zig           # Entry point, CLI parsing
│   ├── session.zig        # Session daemon logic
│   ├── client.zig         # Client connection logic
│   ├── protocol.zig       # Wire protocol
│   ├── terminal.zig       # ghostty-vt wrapper
│   ├── input.zig          # Input handling, leader key
│   ├── render.zig         # Output rendering
│   └── config.zig         # Configuration
├── build.zig
├── build.zig.zon
├── default.nix
├── shell.nix
├── overlay.nix
└── .envrc
```

## Configuration

TOML or simple key=value in `~/.config/vanish/config`

```
leader = "C-\\"
socket_dir = "/run/user/$UID/vanish"
scrollback_lines = 10000
status_bar = false
```

## CLI Interface

```
# Create new session
vanish new [socket-path] [--] command [args...]

# Attach to session
vanish attach <socket-path>

# List sessions
vanish list

# Send command to session
vanish send <socket-path> <input>
```

## Implementation Phases

### Phase 1: Core (MVP)

- [ ] Nix build infrastructure
- [ ] Basic session daemon (pty + ghostty-vt)
- [ ] Socket communication
- [ ] Single client (primary only)
- [ ] Basic output forwarding
- [ ] Detach/attach

### Phase 2: Multi-Client

- [ ] Viewer support
- [ ] Full screen rendering on connect
- [ ] Differential updates

### Phase 3: UI

- [ ] Leader key handling
- [ ] Keybinding system
- [ ] Status bar
- [ ] Keybinding help overlay

### Phase 4: Polish

- [ ] Scroll mode
- [ ] Configuration file
- [ ] Session listing
- [ ] Error handling refinement
- [ ] Tests

## Open Questions

1. **Resize handling for viewers**: When primary resizes, what happens to viewers
   with different sizes? Options:
   - Viewers see primary's size (may be cut off or have extra space)
   - Viewers see adapted rendering (complex)

2. **Scrollback sync**: How to keep viewers in sync with scrollback position?
   - Each viewer has independent scroll position
   - Or lock to primary's scroll position

3. **Graceful degradation**: What if ghostty-vt is unavailable?
   - Fall back to raw byte forwarding (like dtach)
   - Or hard dependency

## Design Principles

1. **Invisible by default**: No UI until you need it
2. **Simple protocol**: Easy to debug and reason about
3. **Trust the terminal**: Use client's terminal for scrollback when possible
4. **Minimal state**: Session is the source of truth
5. **Fail gracefully**: Connection issues shouldn't crash the session
