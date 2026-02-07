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
    running: bool = true,
    hint_visible: bool = false,

    fn handleInput(self: *Client, buf: []const u8) !void {
        var i: usize = 0;
        while (i < buf.len) {
            const byte = buf[i];
            const is_ctrl = byte >= 1 and byte <= 26;

            if (self.keys.processKey(byte, is_ctrl)) |action| {
                try self.executeAction(action);
                self.updateHint();
            } else if (self.keys.in_leader) {
                self.updateHint();
            } else {
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
            },
            .help => {
                self.showHelp();
            },
            .cancel => {},
            else => {},
        }
    }

    fn updateHint(self: *Client) void {
        var hint_buf: [256]u8 = undefined;
        const hint = self.keys.formatHint(&hint_buf) catch "";

        if (hint.len > 0) {
            self.showHint(hint);
            self.hint_visible = true;
        } else if (self.hint_visible) {
            self.clearHint();
            self.hint_visible = false;
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
};

pub fn attach(alloc: std.mem.Allocator, socket_path: []const u8) !void {
    _ = alloc;

    const fd = try connectSocket(socket_path);
    defer posix.close(fd);

    const size = try getTerminalSize();

    var hello = protocol.Hello{
        .role = .primary,
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

    var client = Client{
        .fd = fd,
        .keys = keybind.State.init(.{}),
        .cols = size.cols,
        .rows = size.rows,
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
                },
                .exit => {
                    var buf: [@sizeOf(protocol.Exit)]u8 = undefined;
                    _ = protocol.readExact(client.fd, &buf) catch {};
                    return;
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
