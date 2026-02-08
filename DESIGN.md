# Vanish Architecture

## Overview

Vanish is a terminal session multiplexer using libghostty-vt for terminal
emulation. Sessions are persistent daemon processes accessible via Unix sockets.
An HTTP server provides browser-based access with server-side VT-to-HTML
rendering.

## Session Model

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

**Primary**: One per session. Controls input and terminal size.

**Viewer**: Read-only. Can pan viewport when their terminal is smaller than the
session. Can take over as primary.

## Protocol

Binary protocol over Unix sockets. Little-endian integers.

### Message format

```
┌─────────┬─────────┬──────────────────┐
│  Type   │  Len    │     Payload      │
│ (1 byte)│(4 bytes)│   (Len bytes)    │
└─────────┴─────────┴──────────────────┘
```

### Client → Session

| Type | Name | Payload |
|------|------|---------|
| 0x01 | Hello | `{ role: u8, cols: u16, rows: u16, term: [64]u8 }` |
| 0x02 | Input | Raw bytes for PTY |
| 0x03 | Resize | `{ cols: u16, rows: u16 }` |
| 0x04 | Detach | (none) |
| 0x05 | Scrollback | (none) |
| 0x06 | Takeover | (none) |
| 0x07 | ListClients | (none) |
| 0x08 | KickClient | `{ id: u32 }` |
| 0x09 | KillSession | (none) |

### Session → Client

| Type | Name | Payload |
|------|------|---------|
| 0x81 | Welcome | `{ role: u8, session_id: [16]u8, session_cols: u16, session_rows: u16 }` |
| 0x82 | Output | VT-encoded terminal output |
| 0x83 | Full | Full terminal state (on connect) |
| 0x84 | Exit | `{ code: i32 }` |
| 0x85 | Denied | `{ reason: u8 }` (0=primary_exists, 1=invalid_hello) |
| 0x86 | RoleChange | `{ new_role: u8 }` |
| 0x87 | SessionResize | `{ cols: u16, rows: u16 }` |
| 0x88 | ClientList | Array of `{ id: u32, role: u8, cols: u16, rows: u16 }` |

## Web Terminal

The HTTP server (`vanish serve`) provides browser access via:

- **SSE streaming**: Each browser client gets a Server-Sent Events connection.
  The server maintains a per-client ScreenBuffer and sends cell-level deltas.
- **VT-to-HTML**: vthtml.zig converts ghostty-vt terminal state to positioned
  HTML spans with inline CSS for colors and styles.
- **Authentication**: OTP exchange for JWT tokens. HMAC-SHA256 signed. Scoped
  by session, duration, or indefinite.
- **Input routing**: Browser input is sent through the SSE client's persistent
  session socket, not ephemeral connections.

## Viewport Panning

When a viewer's terminal is smaller than the session, panning is enabled.

1. Client receives session dimensions in Welcome message
2. Client maintains a local VTerminal copy of session state
3. Output is fed to the local terminal and rendered through a viewport offset
4. hjkl keys adjust the viewport offset
5. Status bar shows `[+x,+y]` when panned

## Source Files

```
src/
├── main.zig        CLI entry, argument parsing, 11 commands
├── session.zig     Session daemon, poll loop, client management
├── client.zig      Native client, viewport rendering
├── http.zig        HTTP server, SSE, routing
├── auth.zig        JWT/HMAC, OTP exchange
├── config.zig      JSON config parsing
├── vthtml.zig      VT→HTML rendering, delta computation
├── terminal.zig    ghostty-vt wrapper
├── protocol.zig    Wire protocol definitions
├── keybind.zig     Leader key state machine
├── naming.zig      Auto-name generation (adjective-noun-command)
├── pty.zig         PTY operations
├── signal.zig      Signal handling
├── paths.zig       Shared utilities (socket paths, JSON escaping)
└── static/
    └── index.html  Web frontend (vanilla JS)
```

## Design Principles

1. **Invisible by default** — No UI until you need it.
2. **Simple protocol** — Stateless messages, no acks, easy to debug.
3. **Trust the terminal** — Use the client's terminal for scrollback.
4. **Minimal state** — Session daemon is the single source of truth.
5. **Fail gracefully** — Connection issues don't crash sessions.
6. **Viewer parity** — Viewers see exactly what primary sees.
