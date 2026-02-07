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
2. **Viewer**: Read-only. Sees rendered output. Can pan viewport if their
   terminal is smaller than the session.

### Modes

1. **Passthrough**: Default. All input goes to child process.
2. **Leader**: Activated by leader key. Shows keybinding help. Bindings active.

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
- `0x01` Hello: `{ role: u8, cols: u16, rows: u16, term: [64]u8 }`
- `0x02` Input: raw bytes for pty
- `0x03` Resize: `{ cols: u16, rows: u16 }`
- `0x04` Detach: no payload
- `0x05` Scrollback: request scrollback dump (no payload)
- `0x06` Takeover: viewer requests to become primary (no payload)
- `0x07` ListClients: request list of connected clients (no payload)
- `0x08` KickClient: `{ id: u32 }` disconnect a client by ID

**Session → Client:**
- `0x81` Welcome: `{ role: u8, session_id: [16]u8, session_cols: u16, session_rows: u16 }`
- `0x82` Output: VT-encoded terminal output (forwarded from pty)
- `0x83` Full: VT-encoded full terminal state (on connect)
- `0x84` Exit: `{ code: i32 }` child process exited
- `0x85` Denied: `{ reason: u8 }` (0=primary_exists, 1=invalid_hello)
- `0x86` RoleChange: `{ new_role: u8 }` sent after takeover
- `0x87` SessionResize: `{ cols: u16, rows: u16 }` session size changed
- `0x88` ClientList: array of `{ id: u32, role: u8, cols: u16, rows: u16 }`

## Viewport Panning

When a viewer's terminal is smaller than the session terminal, the viewer can
pan around to see different portions of the larger screen.

### How It Works

1. Client receives session size in Welcome message
2. If session > local terminal, panning is enabled
3. Client maintains a local VTerminal copy of session state
4. Output is fed to local terminal and rendered through viewport
5. hjkl keys adjust viewport offset
6. Status bar shows `[+x,+y]` when offset is non-zero

### Panning Keys (for viewers)

- `h/l` - Pan left/right
- `j/k` - Pan down/up
- `Ctrl+U/Ctrl+D` - Page up/down
- `g/G` - Jump to top-left / bottom-right

## Keybinding System

### Default Bindings (under leader)

- `d` - Detach from session
- `t` - Takeover (viewer becomes primary)
- `s` - Toggle status bar
- `?` - Show full keybinding help
- `Esc` - Cancel leader mode
- `h/j/k/l` - Viewport panning (when applicable)
- `g/G` - Jump to viewport edges
- `Ctrl+U/Ctrl+D` - Page up/down

### Leader Key

Default: `Ctrl-A` (configurable when config is implemented)

When pressed:
1. Enter leader mode
2. Show unobtrusive keybinding hints (bottom right)
3. Wait for next key
4. Execute binding or return to passthrough if unbound

## Status Bar

Optional (toggled with `Ctrl+A s`). Shows:
- Left: session name
- Right: role (primary/viewer) and viewport offset if panning

## File Structure

```
vanish/
├── src/
│   ├── main.zig           # CLI entry point, argument parsing
│   ├── session.zig        # Session daemon, poll loop, client management
│   ├── client.zig         # Client attach logic, viewport rendering
│   ├── protocol.zig       # Wire protocol definitions
│   ├── terminal.zig       # ghostty-vt wrapper
│   ├── keybind.zig        # Leader key state machine
│   ├── pty.zig            # PTY operations
│   └── signal.zig         # Signal handling
├── build.zig
├── build.zig.zon
├── default.nix
├── shell.nix
├── overlay.nix
└── .envrc
```

## CLI Interface

```sh
# Create new session
vanish new <name> -- <command> [args...]

# Attach to session
vanish attach [--viewer] <name>

# Send keys to session (for scripting)
vanish send <name> <keys>

# List sessions
vanish list [--json]

# List connected clients
vanish clients [--json] <name>

# Disconnect a client
vanish kick <name> <client-id>
```

Session names without `/` are stored in `$XDG_RUNTIME_DIR/vanish/`.

### JSON Output

The `--json` flag provides machine-readable output for scripting:

```sh
vanish list --json
# {"sessions":[{"name":"foo","path":"/run/user/1000/vanish/foo"}]}

vanish clients --json mysession
# {"clients":[{"id":1,"role":"primary","cols":120,"rows":40}]}
```

## Implementation Status

### Complete

- [x] Nix build infrastructure
- [x] Session daemon (pty + ghostty-vt)
- [x] Socket communication with binary protocol
- [x] Primary and viewer clients
- [x] Terminal state preservation on connect
- [x] Detach/attach
- [x] Leader key handling
- [x] Keybinding system with hints
- [x] Status bar (toggleable)
- [x] Session listing with JSON output
- [x] Send command for scripting
- [x] Signal handling (SIGWINCH, SIGTERM)
- [x] Session takeover (viewer → primary)
- [x] Viewport panning for smaller viewers
- [x] Client list/disconnect commands

### Future

- [ ] Configuration file (JSON format)

## Design Principles

1. **Invisible by default**: No UI until you need it
2. **Simple protocol**: Easy to debug and reason about
3. **Trust the terminal**: Use client's terminal for scrollback when possible
4. **Minimal state**: Session is the source of truth
5. **Fail gracefully**: Connection issues shouldn't crash the session
6. **Viewer parity**: Viewers see exactly what primary sees (panned if needed)
