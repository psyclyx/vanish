# vanish

Terminal session multiplexer built on libghostty. Like dtach with terminal
state preservation, or tmux without the complexity.

## What it does

Vanish manages persistent terminal sessions behind Unix sockets. Sessions
survive detachment and reconnection with full screen state intact. One primary
client controls input; any number of viewers can watch read-only.

A built-in HTTP server provides browser-based access with the same
primary/viewer model.

## Install

Requires Zig 0.15.

```sh
zig build
# Binary at ./zig-out/bin/vanish
```

### NixOS

```nix
# Via overlay
nixpkgs.overlays = [ (import /path/to/vanish/overlay.nix) ];
environment.systemPackages = [ pkgs.vanish ];
```

## Quick start

```sh
# Create a session and attach
vanish new work zsh

# Detach: Ctrl+A d

# Reattach
vanish attach work

# Auto-named session
vanish new -a zsh
# stderr: calm-ridge-zsh

# List sessions
vanish list
```

## Commands

| Command | Description |
|---------|-------------|
| `new [--detach] [--auto-name] [--serve] <name> <cmd>` | Create session and attach |
| `attach [--primary] <name>` | Attach to session (viewer by default) |
| `list [--json]` | List sessions |
| `send <name> <keys>` | Send input to session |
| `clients [--json] <name>` | List connected clients |
| `kick <name> <client-id>` | Disconnect a client |
| `kill <name>` | Terminate a session |
| `serve [-b addr] [-p port] [-d]` | Start HTTP server |
| `otp [--duration time] [--session name] [--read-only] [--url]` | Generate auth token |
| `revoke [--all] [--temporary] [--session name]` | Revoke auth tokens |
| `print-config` | Show effective config |

Global flags: `-c <config>`, `-v` (verbose), `-vv` (debug).

## Keybindings

Leader key: **Ctrl+A** (configurable).

| Key | Action |
|-----|--------|
| `d` | Detach |
| `t` | Take over session (viewer becomes primary) |
| `s` | Toggle status bar |
| `h` `j` `k` `l` | Pan viewport (when session is larger than terminal) |
| `Ctrl+U` `Ctrl+D` | Page up/down |
| `g` `G` | Jump to top-left / bottom-right |
| `[` | Dump scrollback |
| `?` | Help |

## Web access

```sh
# Start the HTTP server
vanish serve -d

# Generate a URL and open in browser
vanish otp --url
# http://127.0.0.1:7890?otp=...

# Or copy to clipboard
vanish otp --url | xclip -sel clip
```

The web terminal uses server-side VT-to-HTML rendering with cell-level delta
streaming over SSE. No framework dependencies.

Auto-start the server alongside a session:

```sh
vanish new --serve -a zsh
# Or set "auto_serve": true in config
```

## Configuration

`~/.config/vanish/config.json`

```json
{
  "leader": "^B",
  "socket_dir": "/tmp/vanish",
  "serve": {
    "bind": "127.0.0.1",
    "port": 7890,
    "auto_serve": false
  },
  "binds": {
    "d": "detach",
    "t": "takeover",
    "s": "toggle_status",
    "?": "help"
  }
}
```

Leader key formats: `^A`, `Ctrl+A`, `Ctrl+Space`, `^\`.

Actions: `detach`, `takeover`, `toggle_status`, `help`, `scrollback`,
`scroll_up`, `scroll_down`, `scroll_left`, `scroll_right`,
`scroll_page_up`, `scroll_page_down`, `scroll_top`, `scroll_bottom`.

All fields are optional. Unset values use defaults.

## Design

Sessions are PTY + ghostty-vt terminal emulator pairs, managed as daemon
processes. Communication uses a binary protocol over Unix sockets. Keybindings
and rendering are handled client-side. The session daemon is the single source
of truth for terminal state.

Session sockets live in `$XDG_RUNTIME_DIR/vanish/` by default.

See [DESIGN.md](DESIGN.md) for protocol details.

## License

MIT
