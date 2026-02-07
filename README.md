# vanish

A lightweight terminal session multiplexer built on libghostty.

Like dtach, but with terminal state preservation. Like tmux, but minimal.

## Features

- **Terminal state preservation**: Uses ghostty-vt to track terminal state, so reconnecting shows the current screen
- **Invisible by default**: No visible UI until you need it
- **Primary/viewer model**: One writer per session, unlimited read-only viewers
- **Session takeover**: Viewers can become primary (existing primary becomes viewer)
- **Simple socket-based sessions**: Just a unix socket per session
- **Scroll mode**: Navigate scrollback with vim-like keys

## Usage

```sh
# Create a session
vanish new myshell -- bash

# Attach to a session
vanish attach myshell

# Attach as viewer (read-only)
vanish attach --viewer myshell

# Send keys to a session (for scripting)
vanish send myshell "ls -la\n"

# List sessions
vanish list
```

## Keybindings

Leader key: `Ctrl+A`

| Key | Action |
|-----|--------|
| `d` | Detach from session |
| `s` | Toggle status bar |
| `t` | Takeover session (viewer becomes primary) |
| `k` / `j` | Scroll up/down |
| `Ctrl+U` / `Ctrl+D` | Page up/down |
| `g` / `G` | Scroll to top/bottom |
| `?` | Show help |
| `Esc` | Cancel |

In scroll mode, any key exits and refreshes the screen.

## Installation

### NixOS

```nix
{ pkgs, ... }:
let
  vanish = pkgs.callPackage /path/to/vanish {};
in {
  environment.systemPackages = [ vanish ];
}
```

Or use the overlay:

```nix
{ pkgs, ... }:
{
  nixpkgs.overlays = [ (import /path/to/vanish/overlay.nix) ];
  environment.systemPackages = [ pkgs.vanish ];
}
```

### From source

Requires Zig 0.15.

```sh
zig build
./zig-out/bin/vanish
```

## Design

- Sessions are pty + ghostty-vt terminal emulator pairs, managed by daemon processes
- Communication via binary protocol over unix sockets
- One primary client controls terminal size and can send input
- Multiple viewer clients can watch (read-only)
- Keybindings handled client-side for responsiveness
- Status bar and hints rendered client-side

See [DESIGN.md](DESIGN.md) for architecture details.

## License

MIT
