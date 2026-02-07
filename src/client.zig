const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const protocol = @import("protocol.zig");
const keybind = @import("keybind.zig");
const sig = @import("signal.zig");

const STDIN = 0;
const STDOUT = 1;

const Client = struct {
    fd: posix.fd_t,
    keys: keybind.State,
    cols: u16,
    rows: u16,
    session_name: []const u8,
    role: protocol.Role,
    running: bool = true,
    hint_visible: bool = false,
    in_scroll_mode: bool = false,

    fn handleInput(self: *Client, buf: []const u8) !void {
        var i: usize = 0;
        while (i < buf.len) {
            const byte = buf[i];
            const is_ctrl = byte >= 1 and byte <= 26;

            if (self.in_scroll_mode) {
                self.exitScrollMode();
                i += 1;
                continue;
            }

            if (self.keys.processKey(byte, is_ctrl)) |action| {
                try self.executeAction(action);
                self.updateHint();
            } else if (self.keys.in_leader) {
                self.updateHint();
            } else if (self.role == .primary) {
                protocol.writeMsg(self.fd, @intFromEnum(protocol.ClientMsg.input), buf[i .. i + 1]) catch {
                    self.running = false;
                    return;
                };
            }
            i += 1;
        }
    }

    fn executeAction(self: *Client, action: keybind.Action) !void {
        switch (action) {
            .detach => {
                protocol.writeMsg(self.fd, @intFromEnum(protocol.ClientMsg.detach), "") catch {};
                self.running = false;
            },
            .toggle_status => {
                self.keys.show_status = !self.keys.show_status;
                if (self.keys.show_status) {
                    self.renderStatusBar();
                } else {
                    self.clearHint();
                }
            },
            .help => {
                self.showHelp();
            },
            .takeover => {
                if (self.role == .viewer) {
                    protocol.writeMsg(self.fd, @intFromEnum(protocol.ClientMsg.takeover), "") catch {};
                }
            },
            .scroll_up, .scroll_down, .scroll_page_up, .scroll_page_down, .scroll_top, .scroll_bottom => {
                self.enterScrollMode();
            },
            .cancel => {},
        }
    }

    fn enterScrollMode(self: *Client) void {
        self.in_scroll_mode = true;
        // Request scrollback from session
        protocol.writeMsg(self.fd, @intFromEnum(protocol.ClientMsg.scrollback), "") catch {};
        // Show scroll mode indicator
        self.showScrollIndicator();
    }

    fn exitScrollMode(self: *Client) void {
        self.in_scroll_mode = false;
        // Clear screen and request fresh terminal state
        _ = posix.write(STDOUT, "\x1b[2J\x1b[H") catch {};
        // Request full screen refresh
        protocol.writeMsg(self.fd, @intFromEnum(protocol.ClientMsg.scrollback), "") catch {};
    }

    fn showScrollIndicator(self: *Client) void {
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "\x1b7\x1b[{d};1H\x1b[7m SCROLL MODE - press any key to exit \x1b[0m\x1b8", .{self.rows}) catch return;
        _ = posix.write(STDOUT, msg) catch {};
    }

    fn updateHint(self: *Client) void {
        var hint_buf: [256]u8 = undefined;
        const hint = self.keys.formatHint(&hint_buf) catch "";

        if (hint.len > 0) {
            self.showHint(hint);
            self.hint_visible = true;
        } else if (self.hint_visible) {
            self.hint_visible = false;
            if (self.keys.show_status) {
                self.renderStatusBar();
            } else {
                self.clearHint();
            }
        }
    }

    fn showHint(self: *Client, hint: []const u8) void {
        var buf: [512]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "\x1b7\x1b[{d};1H{s}\x1b8", .{ self.rows, hint }) catch return;
        _ = posix.write(STDOUT, msg) catch {};
    }

    fn clearHint(self: *Client) void {
        var buf: [64]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "\x1b7\x1b[{d};1H\x1b[K\x1b8", .{self.rows}) catch return;
        _ = posix.write(STDOUT, msg) catch {};
    }

    fn showHelp(self: *Client) void {
        _ = self;
        const help =
            \\
            \\ vanish keybindings (leader: Ctrl+A)
            \\
            \\   d       detach from session
            \\   s       toggle status bar
            \\   t       takeover (viewer becomes primary)
            \\   k/j     scroll up/down
            \\   Ctrl+U  page up
            \\   Ctrl+D  page down
            \\   g/G     scroll to top/bottom
            \\   ?       show this help
            \\   Esc     cancel
            \\
        ;
        _ = posix.write(STDOUT, help) catch {};
    }

    fn renderStatusBar(self: *Client) void {
        if (!self.keys.show_status) return;
        if (self.hint_visible) return;

        var buf: [512]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buf);
        const w = fbs.writer();

        w.writeAll("\x1b7") catch return; // save cursor
        w.print("\x1b[{d};1H", .{self.rows}) catch return; // move to last line
        w.writeAll("\x1b[7m") catch return; // inverse video

        w.print(" {s} ", .{self.session_name}) catch return;
        const left_len = self.session_name.len + 2;

        const right_text = switch (self.role) {
            .primary => " primary ",
            .viewer => " viewer ",
        };
        const right_len = right_text.len;
        const total_len = left_len + right_len;
        const padding: usize = if (self.cols > total_len) self.cols - total_len else 0;

        w.writeByteNTimes(' ', padding) catch return;
        w.writeAll(right_text) catch return;
        w.writeAll("\x1b[0m\x1b8") catch return; // reset, restore cursor

        _ = posix.write(STDOUT, fbs.getWritten()) catch {};
    }
};

pub fn send(socket_path: []const u8, keys: []const u8) !void {
    const fd = try connectSocket(socket_path);
    defer posix.close(fd);

    const hello = protocol.Hello{
        .role = .primary,
        .cols = 80,
        .rows = 24,
    };

    try protocol.writeStruct(fd, @intFromEnum(protocol.ClientMsg.hello), hello);

    const resp_header = try protocol.readHeader(fd);

    switch (@as(protocol.ServerMsg, @enumFromInt(resp_header.msg_type))) {
        .welcome => {
            var buf: [@sizeOf(protocol.Welcome)]u8 = undefined;
            try protocol.readExact(fd, &buf);
        },
        .denied => {
            var buf: [@sizeOf(protocol.Denied)]u8 = undefined;
            try protocol.readExact(fd, &buf);
            const denied = std.mem.bytesToValue(protocol.Denied, &buf);
            switch (denied.reason) {
                .primary_exists => {
                    _ = posix.write(posix.STDERR_FILENO, "Session already has a primary client\n") catch {};
                },
                .invalid_hello => {
                    _ = posix.write(posix.STDERR_FILENO, "Invalid handshake\n") catch {};
                },
            }
            return;
        },
        else => return error.UnexpectedMessage,
    }

    try protocol.writeMsg(fd, @intFromEnum(protocol.ClientMsg.input), keys);
    protocol.writeMsg(fd, @intFromEnum(protocol.ClientMsg.detach), "") catch {};
}

pub fn attach(alloc: std.mem.Allocator, socket_path: []const u8, as_viewer: bool) !void {
    _ = alloc;

    const fd = try connectSocket(socket_path);
    defer posix.close(fd);

    const size = try getTerminalSize();
    const role: protocol.Role = if (as_viewer) .viewer else .primary;

    var hello = protocol.Hello{
        .role = role,
        .cols = size.cols,
        .rows = size.rows,
    };
    if (std.posix.getenv("TERM")) |term| {
        hello.setTerm(term);
    }

    try protocol.writeStruct(fd, @intFromEnum(protocol.ClientMsg.hello), hello);

    const resp_header = try protocol.readHeader(fd);

    switch (@as(protocol.ServerMsg, @enumFromInt(resp_header.msg_type))) {
        .welcome => {
            var buf: [@sizeOf(protocol.Welcome)]u8 = undefined;
            try protocol.readExact(fd, &buf);
        },
        .denied => {
            var buf: [@sizeOf(protocol.Denied)]u8 = undefined;
            try protocol.readExact(fd, &buf);
            const denied = std.mem.bytesToValue(protocol.Denied, &buf);
            switch (denied.reason) {
                .primary_exists => {
                    _ = posix.write(posix.STDERR_FILENO, "Session already has a primary client\n") catch {};
                },
                .invalid_hello => {
                    _ = posix.write(posix.STDERR_FILENO, "Invalid handshake\n") catch {};
                },
            }
            return;
        },
        else => return error.UnexpectedMessage,
    }

    var old_termios: ?posix.termios = null;
    if (posix.isatty(STDIN)) {
        old_termios = setRawMode() catch null;
    }
    defer {
        if (old_termios) |t| restoreTermios(t);
    }

    const session_name = std.fs.path.basename(socket_path);

    var client = Client{
        .fd = fd,
        .keys = keybind.State.init(.{}),
        .cols = size.cols,
        .rows = size.rows,
        .session_name = session_name,
        .role = role,
    };

    try runClientLoop(&client);
}

fn runClientLoop(client: *Client) !void {
    sig.setup();

    var poll_fds = [_]posix.pollfd{
        .{ .fd = STDIN, .events = posix.POLL.IN, .revents = 0 },
        .{ .fd = client.fd, .events = posix.POLL.IN, .revents = 0 },
    };

    while (client.running) {
        if (sig.checkTerm()) break;

        if (sig.checkWinch()) {
            const size = getTerminalSize() catch continue;
            client.cols = size.cols;
            client.rows = size.rows;
            const resize = protocol.Resize{ .cols = size.cols, .rows = size.rows };
            protocol.writeStruct(client.fd, @intFromEnum(protocol.ClientMsg.resize), resize) catch {};
        }

        const ready = posix.poll(&poll_fds, 100) catch |err| {
            if (err == error.Interrupted) continue;
            return err;
        };

        if (ready == 0) continue;

        if (poll_fds[0].revents & posix.POLL.IN != 0) {
            var buf: [1024]u8 = undefined;
            const n = posix.read(STDIN, &buf) catch break;
            if (n == 0) break;
            try client.handleInput(buf[0..n]);
        }

        if (poll_fds[1].revents & posix.POLL.IN != 0) {
            const header = protocol.readHeader(client.fd) catch break;

            switch (@as(protocol.ServerMsg, @enumFromInt(header.msg_type))) {
                .output, .full => {
                    if (header.len > 0) {
                        var remaining: u32 = header.len;
                        var buf: [4096]u8 = undefined;
                        while (remaining > 0) {
                            const to_read: usize = @min(remaining, buf.len);
                            protocol.readExact(client.fd, buf[0..to_read]) catch break;
                            _ = posix.write(STDOUT, buf[0..to_read]) catch {};
                            remaining -= @intCast(to_read);
                        }
                    }
                    client.renderStatusBar();
                },
                .exit => {
                    var buf: [@sizeOf(protocol.Exit)]u8 = undefined;
                    _ = protocol.readExact(client.fd, &buf) catch {};
                    return;
                },
                .role_change => {
                    var buf: [@sizeOf(protocol.RoleChange)]u8 = undefined;
                    protocol.readExact(client.fd, &buf) catch break;
                    const role_change = std.mem.bytesToValue(protocol.RoleChange, &buf);
                    client.role = role_change.new_role;
                    client.renderStatusBar();
                },
                else => {
                    var remaining = header.len;
                    var skip_buf: [1024]u8 = undefined;
                    while (remaining > 0) {
                        const chunk: usize = @min(remaining, skip_buf.len);
                        protocol.readExact(client.fd, skip_buf[0..chunk]) catch break;
                        remaining -= @intCast(chunk);
                    }
                },
            }
        }

        if (poll_fds[1].revents & (posix.POLL.HUP | posix.POLL.ERR) != 0) {
            break;
        }
    }
}

fn connectSocket(path: []const u8) !posix.fd_t {
    var addr = std.net.Address.initUnix(path) catch return error.PathTooLong;
    const sock = try posix.socket(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0);
    errdefer posix.close(sock);

    try posix.connect(sock, &addr.any, addr.getOsSockLen());

    return sock;
}

const TermSize = struct {
    rows: u16,
    cols: u16,
};

fn getTerminalSize() !TermSize {
    const TIOCGWINSZ = 0x5413;

    const Winsize = extern struct {
        ws_row: u16,
        ws_col: u16,
        ws_xpixel: u16,
        ws_ypixel: u16,
    };

    var ws: Winsize = undefined;
    const result = linux.ioctl(@intCast(STDOUT), TIOCGWINSZ, @intFromPtr(&ws));
    if (@as(isize, @bitCast(result)) < 0) {
        return .{ .rows = 24, .cols = 80 };
    }
    return .{ .rows = ws.ws_row, .cols = ws.ws_col };
}

fn setRawMode() !posix.termios {
    var termios = try posix.tcgetattr(STDIN);
    const old = termios;

    termios.lflag.ECHO = false;
    termios.lflag.ICANON = false;
    termios.lflag.ISIG = false;
    termios.lflag.IEXTEN = false;

    termios.iflag.IXON = false;
    termios.iflag.ICRNL = false;
    termios.iflag.BRKINT = false;
    termios.iflag.INPCK = false;
    termios.iflag.ISTRIP = false;

    termios.oflag.OPOST = false;

    termios.cc[@intFromEnum(posix.V.MIN)] = 1;
    termios.cc[@intFromEnum(posix.V.TIME)] = 0;

    try posix.tcsetattr(STDIN, .FLUSH, termios);

    return old;
}

fn restoreTermios(termios: posix.termios) void {
    posix.tcsetattr(STDIN, .FLUSH, termios) catch {};
}
