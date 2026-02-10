# Vanish Specification

Behavioral contracts and edge cases. For architecture, see [../DESIGN.md](../DESIGN.md).
For user-facing docs, see the man page (`doc/vanish.1`).

## Protocol

Binary protocol over Unix domain sockets. 5-byte logical header (1 type + 4
length), padded to 8 bytes by extern struct alignment.

### Assumptions

- Same-host communication only (UDS guarantees this).
- Native byte order. No endian conversion.
- Client and server are the same binary. No version negotiation.
- Unknown message types: receiver skips `header.len` bytes.
- Client types: 0x01-0x09. Server types: 0x81-0x88 (high bit set).

### Wire Struct Sizes

Pinned by comptime tests. Changing field order or types breaks the build.

| Struct | Size | Fields |
|--------|------|--------|
| Header | 8 | type:u8, _pad:3, len:u32 |
| Hello | 70 | role:u8, _pad:1, cols:u16, rows:u16, term:[64]u8 |
| Welcome | 22 | role:u8, _pad:3, session_id:[16]u8, cols:u16, rows:u16 |
| Resize | 4 | cols:u16, rows:u16 |
| Exit | 4 | code:i32 |
| Denied | 1 | reason:u8 |
| RoleChange | 1 | new_role:u8 |
| SessionResize | 4 | cols:u16, rows:u16 |
| ClientInfo | 12 | id:u32, role:u8, _pad:1, cols:u16, rows:u16 |
| KickClient | 4 | id:u32 |

### Client Messages (client -> session)

| Type | Name | Payload | Behavior |
|------|------|---------|----------|
| 0x01 | hello | Hello struct | Handshake. Must be first message. |
| 0x02 | input | raw bytes | Written to PTY. Primary only; viewer input silently skipped. |
| 0x03 | resize | Resize struct | Resizes PTY + terminal. Primary only; viewer resize ignored. |
| 0x04 | detach | (empty) | Clean disconnect. Session removes client. |
| 0x05 | scrollback | (empty) | Session sends scrollback as `full` message. |
| 0x06 | takeover | (empty) | Viewer promotes to primary. Ignored if already primary. |
| 0x07 | list_clients | (empty) | Session responds with `client_list`. |
| 0x08 | kick_client | KickClient struct | Session disconnects target client by ID. |
| 0x09 | kill_session | (empty) | Session sets running=false, exits gracefully. |

### Server Messages (session -> client)

| Type | Name | Payload | Behavior |
|------|------|---------|----------|
| 0x81 | welcome | Welcome struct | Handshake response. Contains session dimensions and assigned role. |
| 0x82 | output | raw VT bytes | Incremental terminal output from PTY. |
| 0x83 | full | raw VT bytes | Complete screen state. Sent on connect and on scrollback request. |
| 0x84 | exit | Exit struct | Child process exited. Contains exit code. |
| 0x85 | denied | Denied struct | Connection rejected: 0=primary_exists, 1=invalid_hello. |
| 0x86 | role_change | RoleChange struct | Client's role changed (takeover). |
| 0x87 | session_resize | SessionResize struct | Session dimensions changed (notifies viewers). |
| 0x88 | client_list | ClientInfo[] | Response to list_clients. Array of packed ClientInfo structs. |

### Connection Handshake

```
Client                    Session
  │                          │
  ├── Hello{role,cols,rows} ──▶
  │                          ├── validate msg_type == 0x01
  │                          ├── validate header.len == @sizeOf(Hello)
  │                          ├── if role==primary && primary!=null: Denied{primary_exists}
  │                          ├── Welcome{role, session_id, cols, rows}
  │                          └── Full{screen state} (if terminal has content)
  ◀──────────────────────────┤
```

If role is primary: session resizes PTY and terminal to client's dimensions.
If role is viewer: session dimensions unchanged; client adapts via viewport.

## Session Lifecycle

### Creation (`vanish new`)

1. Parse args: `parseCmdNewArgs` extracts flags, session name, command.
2. Resolve socket path: `$socket_dir/$name`.
3. Liveness check: probe socket with connect attempt (`isSocketLive`). If live, error: "Session '$name' already exists". This prevents silently clobbering a running session's socket.
4. `forkSession`: create pipe, fork. Child daemonizes (setsid, close stdin/stdout/stderr), sets `VANISH_SESSION` and `VANISH_SOCKET` environment variables, calls `Session.runWithNotify`. Parent waits for ready byte on pipe.
5. `createSocket` (in child): secondary liveness guard — if socket became live between step 3 and the child's bind attempt, returns `error.SessionAlreadyExists`. TOCTOU race is acceptable; worst case falls back to "Session failed to start" error.
6. If `--auto-name`: print generated name to stdout.
7. If `--serve` or `config.serve.auto_serve`: start HTTP server (idempotent).
8. If not `--detach`: attach as primary.

### Auto-naming

Format: `adjective-noun-command` (e.g., `calm-ridge-zsh`).

- Entropy source: `std.time.nanoTimestamp()` (not crypto-random; names are not security-sensitive).
- Collision check: retries up to 10 times if socket path already exists.
- Command component: basename of first argv element (e.g., `/usr/bin/zsh` -> `zsh`).

### Socket Liveness Probing

`isSocketLive(path)` determines if a session daemon is listening at a Unix
socket path. Mechanism: open a `SOCK_STREAM` socket, attempt `connect()`. If
connect succeeds, the session is live (socket closed immediately after). If
connect fails (ECONNREFUSED, ENOENT, or any other error), the socket is stale.

Used by:
- `createSocket`: prevents clobbering a live session's socket. Returns
  `error.SessionAlreadyExists` if live.
- `cmdNew`: pre-fork check with user-facing error message.
- `cmdList` / `writeJsonList`: annotates sessions as live or stale.
- `buildSessionListJson` (HTTP): includes `live` field in API responses.

### Session Daemon Event Loop

Poll-based: PTY master fd + listening socket + all client fds.

- PTY readable: `handlePtyOutput` — read bytes, feed to terminal, broadcast `output` to all clients. Viewers iterated backward (while loop decrementing index) so that `swapRemove` on write failure doesn't skip or double-process viewers.
- Socket readable: `handleNewConnection` — accept, validate hello, send welcome + full state.
- Client readable: `handleClientInput` — read header, dispatch by message type.
- Client HUP/error: remove client (removePrimary or removeViewer).

Loop exits when `running == false` (child process exited or kill_session received).

### Destruction

1. PTY read returns 0 (child exited) or `kill_session` received.
2. Session reads exit status via `waitpid`.
3. Sends `exit{code}` to primary and all viewers.
4. Closes all client sockets.
5. Closes listening socket.
6. Deletes socket file.
7. Session daemon process exits.

## Roles

### Primary (max 1 per session)

- Input forwarded to PTY.
- Resize changes session dimensions, PTY, terminal, and notifies viewers.
- Can be demoted to viewer via takeover.
- Disconnecting does NOT destroy the session.

### Viewer (unlimited)

- Input silently dropped (not rejected — payload is read and discarded).
- Resize from viewer ignored (session dimensions unchanged).
- Can request takeover to become primary.
- Viewport panning when local terminal smaller than session.

### Takeover Sequence

1. Viewer sends `takeover`.
2. Session sends `role_change{viewer}` to old primary.
3. Old primary moved to viewers list (stays connected as viewer).
4. If sending role_change to old primary fails (write error): old primary's fd closed, primary set to null.
5. Viewer removed from viewers list.
6. Viewer promoted to primary.
7. Session sends `role_change{primary}` to new primary.
8. Session resizes PTY + terminal to new primary's dimensions.

Edge case: if no primary exists, viewer still goes through the takeover flow (steps 2-3 are skipped).

## Native Client

### Keybinding State Machine

Two states: normal and leader.

**Normal state**: All input forwarded to session as `input` messages (primary) or silently dropped by session (viewer). If byte matches leader key: enter leader state, consume the byte.

**Leader state**: Next byte looked up in binds table. If match: execute action, return to normal. If no match: return `cancel` action, return to normal. Escape always cancels.

Default leader: Ctrl+A (0x01). Configurable.

### Default Binds (after leader)

| Key | Action |
|-----|--------|
| d | detach |
| Ctrl+A | detach (double-tap) |
| [ | scrollback |
| h | scroll_left (pan) |
| j | scroll_down (pan) |
| k | scroll_up (pan) |
| l | scroll_right (pan) |
| Ctrl+U | scroll_page_up |
| Ctrl+D | scroll_page_down |
| g | scroll_top (jump to 0,0) |
| G | scroll_bottom (jump to max offset) |
| s | toggle_status |
| t | takeover |
| ? | help |
| Escape | cancel |

### Viewport Panning

Applies when `session_cols > local_cols` or `session_rows > local_rows`.

- Client maintains local VTerminal copy fed with all session output.
- `dumpViewport(offset_x, offset_y, view_cols, view_rows)` renders a window into the terminal state.
- Offset bounds: `0 <= offset_x <= session_cols - local_cols`, same for y.
- Pan actions move offset by 1 (hjkl), half-screen (Ctrl+U/D), or jump to extremes (g/G).

### Scrollback

User presses leader + `[`. Client sends `scrollback` message. Session responds with `full` containing scrollback content (dumped from ghostty-vt's scrollback buffer). Client writes this directly to its own terminal, which adds it to the user's terminal scrollback. User can scroll with their terminal's native scrollback.

Exception: if `terminal.screen_cleared` is true (ED2/ED3 was detected in PTY output), scrollback request returns nothing. This prevents sending pre-clear content that would confuse the user.

### Hint Display

When in leader state, a compact hint line renders on the last terminal row:

```
 ─ d detach │s toggle status │t takeover │? help │[ scrollback
```

Only shows "important" actions (detach, toggle_status, takeover, help, scrollback). Pan binds omitted (shown in `?` help). Deduplicated by action (first bind per action wins).

### Status Bar

Toggled with leader + s. Shows session info when active. Also temporarily shown during leader state.

### Terminal State on Attach/Detach

On attach: enters alternate screen buffer (`\x1b[?1049h`) and sets raw mode. This gives a clean canvas and preserves the user's pre-attach terminal content.

On detach/exit: leaves alternate screen buffer (`\x1b[?1049l`) and restores original termios. The user's previous terminal content is restored.

This matches the behavior of tmux, screen, and other TUI applications.

## HTTP Server

### Startup

`vanish serve` (or auto-started via `--serve`/`config.serve.auto_serve`).

- Binds to IPv4 and IPv6 (127.0.0.1 + ::1 by default).
- If port already listening: skip (idempotent, logged as verbose).
- If `--daemonize`: fork, parent exits immediately.
- Warning printed if binding to non-localhost address.

### Event Loop

Single-threaded poll loop with 4 client types:

1. **Listen sockets** (IPv4 + IPv6): accept new HTTP connections.
2. **HTTP clients**: request/response cycle, then close.
3. **SSE session clients**: long-lived, streaming terminal output.
4. **SSE session-list clients**: long-lived, streaming session list changes.

### Endpoints

#### `GET /`

Returns embedded `index.html`. Requires valid JWT cookie. No JWT -> redirect-like behavior handled client-side (auth form shown).

#### `POST /auth`

Body: `otp=<32-char-hex>` (URL-encoded form).

1. Call `auth.exchangeOtp(code)`.
2. On success: set `jwt` cookie (HttpOnly, SameSite=Strict, Path=/). Set `ro=1` cookie if read-only. Redirect to `/` (302).
3. On failure: 400 (missing/malformed), 401 (invalid/expired).

#### `GET /api/sessions`

Returns JSON: `{"sessions":[{"name":"...","live":true},...]}`.

Each session socket is probed for liveness. The `live` field indicates whether
the session daemon is reachable.

Scoping: if token is session-scoped, only that session returned.

#### `GET /api/sessions/stream`

SSE stream of session list. Polls socket directory every ~1s.

Events: `data: {"sessions":[{"name":"...","live":true},...]}\n\n`

Same liveness probing as `GET /api/sessions`. Each poll re-probes all sockets.

#### `GET /api/sessions/:name/stream`

SSE stream of terminal output for a specific session.

Query params: `?cols=N&rows=N` (client viewport size).

Setup:
1. Validate JWT + scope.
2. Connect to session's Unix socket as viewer (or primary if token allows).
3. Send Hello, receive Welcome.
4. Create local VTerminal + ScreenBuffer.
5. Feed initial `full` message to local terminal.
6. Send SSE headers (`Content-Type: text/event-stream`).
7. Send initial keyframe (all cells).

Streaming:
- On session output: feed to local VTerminal, compute cell deltas via ScreenBuffer, send JSON SSE event.
- Keyframe every ~1s (full screen resend to handle lost events).

Event format:
```json
{"cols":80,"rows":24,"cx":0,"cy":0,"cells":[{"x":0,"y":0,"c":"h","s":"color:#fff"}]}
```

Where `c` is the character, `s` is inline CSS style string.

#### `POST /api/sessions/:name/input`

Send input to session. Body: raw bytes or URL-encoded.

Rejected if token is read-only.

#### `POST /api/sessions/:name/resize`

Resize session. Body: `cols=N&rows=N`.

Rejected if token is read-only. Requires primary role.

#### `POST /api/sessions/:name/takeover`

Viewer requests primary role.

Rejected if token is read-only.

## Authentication

### OTP Generation (`vanish otp`)

1. Generate 16 random bytes -> 32-char hex code.
2. SHA256(code) -> hash.
3. Store `$STATE_DIR/otps/$hash_hex.json` with metadata:
   `{"scope":"...","session":"...","exp":N,"created":N,"read_only":bool}`
4. Print code to stdout. With `--url`, print `http://<bind>:<port>?otp=<code>`
   using bind address and port from config (defaults: 127.0.0.1:7890). IPv6
   bind addresses are bracketed per RFC 3986 (e.g., `http://[::1]:7890?otp=...`).

The stored file contains the **hash**, not the code. Attacker with read access to state dir cannot recover codes.

### OTP Exchange (`POST /auth`)

1. SHA256(provided_code) -> hash.
2. Look up `$hash_hex.json` in otps dir.
3. Validate expiry.
4. Delete OTP file (single-use, deleted even on failure after reading).
5. Create JWT signed with scope's HMAC key.
6. Return JWT.

### JWT Structure

Standard `header.payload.signature` with base64url encoding.

Header: `{"alg":"HS256","typ":"JWT"}`

Payload fields:
- `scope`: "temporary" | "daemon" | "indefinite" | "session"
- `session`: string (only for session scope)
- `exp`: unix timestamp (only for temporary scope)
- `iat`: unix timestamp (always)
- `ro`: true (only if read-only)

### Scopes and HMAC Keys

| Scope | Key file | Expiry | Use case |
|-------|----------|--------|----------|
| temporary | `hmac_temporary.key` | User-specified duration | Short-lived access |
| daemon | `hmac_daemon.key` | None (valid until server restart) | Persistent dev access |
| indefinite | `hmac_indefinite.key` | None (never) | Permanent access |
| session | `hmac_session_$NAME.key` | None | Per-session access |

Keys: 32 random bytes, stored mode 0600.

### Revocation (`vanish revoke`)

Rotate HMAC key for target scope. All tokens signed with old key become invalid immediately (signature verification fails). Also deletes matching OTP files.

`--all`: rotates all scope keys.

### Access Control on HTTP Endpoints

Every request (except `POST /auth`):
1. Extract `jwt` from Cookie header.
2. `auth.validateToken(jwt)` -> verify signature (constant-time comparison via `std.crypto.timing_safe.eql`), check expiry.
3. If session-scoped: restrict to that session only.
4. If read-only: reject input, resize, takeover.

## Configuration

Location: `$XDG_CONFIG_HOME/vanish/config.json` (default: `~/.config/vanish/config.json`).

### Schema

```json
{
  "leader": "^A",
  "socket_dir": "/run/user/1000/vanish",
  "serve": {
    "bind": "127.0.0.1",
    "port": 7890,
    "auto_serve": false
  },
  "binds": {
    "d": "detach",
    "^A": "detach",
    "[": "scrollback",
    "h": "scroll_left",
    "...": "..."
  }
}
```

### Leader Key Syntax

| Syntax | Meaning |
|--------|---------|
| `^A` | Ctrl+A |
| `Ctrl+A` | Ctrl+A |
| `^ ` | Ctrl+Space |
| `Ctrl+Space` | Ctrl+Space |
| `^[` | Escape (as ctrl) |
| `^\\` | Ctrl+Backslash |

Range: Ctrl+Space (0x00) through Ctrl+_ (0x1F), plus printable chars.

### Bind Actions

Primary names: detach, scrollback, scroll_up, scroll_down, scroll_left,
scroll_right, scroll_page_up, scroll_page_down, scroll_top, scroll_bottom,
toggle_status, takeover, help, cancel.

Aliases: pan_up, pan_down, pan_left, pan_right, page_up, page_down, top, bottom, status.

### Defaults

- Leader: Ctrl+A (0x01)
- Socket dir: `$XDG_RUNTIME_DIR/vanish` or `/tmp/vanish-$UID`
- Serve port: 7890
- Serve bind: 127.0.0.1 + ::1 (dual-stack localhost)
- Auto-serve: false
- Binds: see Default Binds table above

### Error Handling

- Missing config file: silent, use defaults.
- Invalid JSON: warning to stderr, use defaults.
- Duplicate keys in JSON: warning to stderr, use defaults.
- Config file > 1MB: rejected, use defaults.
- Explicit `--config` path not found: warning, use defaults.

## State Directories

| Directory | Purpose | Default |
|-----------|---------|---------|
| Socket dir | Session Unix sockets | `$XDG_RUNTIME_DIR/vanish` |
| State dir | HMAC keys, OTP files | `$XDG_STATE_HOME/vanish` or `~/.local/state/vanish` |
| Config dir | config.json | `$XDG_CONFIG_HOME/vanish` or `~/.config/vanish` |

## Environment Variables

The child process spawned by `vanish new` inherits the parent shell's
environment. Additionally, vanish sets:

| Variable | Value | Example |
|----------|-------|---------|
| `VANISH_SESSION` | Session name | `work` |
| `VANISH_SOCKET` | Full socket path | `/run/user/1000/vanish/work` |

These are set via `setenv()` in the session daemon before spawning the PTY
child, so they're available in the shell and any processes it starts. Useful for
scripts that need to know they're running inside vanish (e.g., status bar
integration, auto-attach logic).

**Self-join protection**: `vanish attach` checks `VANISH_SOCKET` and
`VANISH_SESSION` before connecting. If the target session matches the current
session, it exits with "Cannot attach to own session". This prevents the
infinite recursion that occurs when a session's shell attaches to itself.

## Edge Cases

### Resize

**Primary resizes terminal**: resize message sent to session -> session updates PTY (TIOCSWINSZ) + terminal + self.cols/rows -> `session_resize` broadcast to all viewers -> viewers update viewport bounds and clamp offset.

**Viewer resizes terminal**: SIGWINCH caught, viewport recalculated locally. No message sent to session. Session dimensions unchanged.

**Resize to 0x0**: silently ignored (session validates non-zero).

### Disconnect

**Primary disconnects (HUP)**: `removePrimary()` closes fd, sets primary=null. Session continues running. Viewers unaffected. New primary can connect.

**Viewer disconnects (HUP)**: `removeViewer(idx)` closes fd, removes from list via swapRemove. Other viewers unaffected. All broadcast loops that call `removeViewer` on error use backward iteration to prevent swapRemove from skipping elements or corrupting the traversal.

**All clients disconnect**: Session continues running. Child process continues executing. Session accepts new connections.

**Session daemon crashes**: Socket file left behind (stale socket). `vanish new` with same name detects the stale socket via `isSocketLive` (connect fails), deletes it, and creates a new session. `vanish list` annotates stale sockets with `(stale)` in text output and `"live":false` in JSON output.

### Child Process

**Child exits normally**: PTY read returns 0 -> session sends `exit{code}` to all clients -> session shuts down.

**Child killed by signal**: Same as above, exit code reflects signal.

**PTY read error (not EOF)**: Logged, loop continues. Persistent errors eventually cause issues.

### Screen Clear Detection

Terminal.feed() scans PTY output for ED2 (`\x1b[2J`) and ED3 (`\x1b[3J`) sequences. If detected: `screen_cleared = true`. This flag prevents `sendScrollback()` from sending pre-clear content.

Rationale: if the application cleared the screen, sending old scrollback would create a confusing disconnect between what the user sees and what existed before the clear.

### Concurrent Connections

**Two primaries simultaneously**: impossible. Second `Hello{role=primary}` gets `Denied{primary_exists}`.

**Viewer + primary connect simultaneously**: session processes connections serially (single-threaded accept loop). No race condition.

**Takeover during primary write**: takeover is processed in the same event loop iteration. The old primary's in-flight writes complete normally before the role change takes effect on the next poll cycle.

### HTTP Server Edge Cases

**Port already in use**: `vanish serve` checks with a connect attempt. If port responds: skip, log "already running."

**SSE client disconnects**: detected via write error on next send. Client removed from SSE list.

**SSE keyframe timing**: approximately 1 second between keyframes. Not guaranteed. Keyframes are full-screen sends that resync state in case SSE events were lost.

**Token expiry during SSE**: token is validated once at connection time. Long-lived SSE connections are not re-validated. To force disconnect: revoke tokens (key rotation) and the SSE client will persist until next server restart or client disconnect.

## CLI Commands

### vanish new [--detach|-d] [--auto-name|-a] [--serve|-s] [--] \<name\> \<command\> [args...]

Create a new session. `--` separates flags from positional args.

With `--auto-name`: name is generated, command starts at first positional arg.
Without `--auto-name`: first positional arg is name, rest is command.

Error: "Session '$name' already exists" if a live session with that name exists.

### vanish attach [--primary|-p] \<name\>

Attach to existing session. Default role: viewer. `--primary` requests primary role (denied if primary exists).

### vanish send \<name\> \<keys\>

Connect as primary, send input, detach immediately. Fails if a primary already
exists (cannot send as viewer). Useful for scripting.

### vanish list [--json]

List sessions by scanning socket directory. Each socket is probed with a connect
attempt to determine liveness.

Text output: stale sessions annotated with `(stale)` suffix.

JSON output: `{"sessions":[{"name":"...","path":"...","live":true},...]}`.
The `live` field is `true` if the session daemon is reachable, `false` if the
socket is stale.

### vanish clients [--json] \<name\>

Connect to session, send `list_clients`, display response.

### vanish kick \<name\> \<client-id\>

Connect to session, send `kick_client{id}`.

### vanish kill \<name\>

Connect to session, send `kill_session`.

### vanish serve [-b|--bind \<addr\>] [-p|--port \<port\>] [-d|--daemonize]

Start HTTP server. Idempotent (checks if port already listening).

### vanish otp [--duration \<time\>] [--session \<name\>] [--daemon] [--indefinite] [--read-only] [--url]

Generate one-time password. Default scope: indefinite. Duration format: `Nh`, `Nm`, `Nd` (hours, minutes, days). `--url` prints a full URL using the configured bind address and port instead of the bare token.

### vanish revoke [--all] [--temporary] [--daemon] [--indefinite] [--session \<name\>]

Revoke tokens by rotating HMAC keys.

### vanish print-config

Print effective configuration as JSON.

## Allocators

- **Session daemon**: C allocator (fork-safe; GPA uses mmap which has issues with fork).
- **HTTP server**: C allocator (same reason — may be forked from main process).
- **CLI client**: GPA (normal allocation, not forked).

## Terminal Emulation

- Library: ghostty-vt (libghostty Zig bindings).
- Scrollback: limited to 1000 lines post-fork (avoids mremap issues with C allocator).
- Screen clear detection: scans for ED2/ED3 in PTY output.
- Viewport rendering: `dumpViewport()` emits VT sequences for a windowed region of the screen.
- Full screen dump: `dumpScreen()` emits complete VT sequence to restore terminal state.
