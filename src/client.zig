const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const protocol = @import("protocol.zig");
const keybind = @import("keybind.zig");
const sig = @import("signal.zig");
const terminal = @import("terminal.zig");
const config = @import("config.zig");

const STDIN = 0;
const STDOUT = 1;

const Viewport = struct {
    session_cols: u16,
    session_rows: u16,
    local_cols: u16,
    local_rows: u16,
    offset_x: u16 = 0,
    offset_y: u16 = 0,

    fn needsPanning(self: *const Viewport) bool {
        return self.session_cols > self.local_cols or self.session_rows > self.local_rows;
    }

    fn moveUp(self: *Viewport) void {
        if (self.offset_y > 0) self.offset_y -= 1;
    }

    fn moveDown(self: *Viewport) void {
        const max_y = if (self.session_rows > self.local_rows)
            self.session_rows - self.local_rows
        else
            0;
        if (self.offset_y < max_y) self.offset_y += 1;
    }

    fn moveLeft(self: *Viewport) void {
        if (self.offset_x > 0) self.offset_x -= 1;
    }

    fn moveRight(self: *Viewport) void {
        const max_x = if (self.session_cols > self.local_cols)
            self.session_cols - self.local_cols
        else
            0;
        if (self.offset_x < max_x) self.offset_x += 1;
    }

    fn jumpTopLeft(self: *Viewport) void {
        self.offset_x = 0;
        self.offset_y = 0;
    }

    fn jumpBottomRight(self: *Viewport) void {
        self.offset_x = if (self.session_cols > self.local_cols)
            self.session_cols - self.local_cols
        else
            0;
        self.offset_y = if (self.session_rows > self.local_rows)
            self.session_rows - self.local_rows
        else
            0;
    }

    fn pageUp(self: *Viewport) void {
        const step = self.local_rows / 2;
        if (self.offset_y >= step) {
            self.offset_y -= step;
        } else {
            self.offset_y = 0;
        }
    }

    fn pageDown(self: *Viewport) void {
        const step = self.local_rows / 2;
        const max_y = if (self.session_rows > self.local_rows)
            self.session_rows - self.local_rows
        else
            0;
        if (self.offset_y + step <= max_y) {
            self.offset_y += step;
        } else {
            self.offset_y = max_y;
        }
    }

    fn updateLocal(self: *Viewport, cols: u16, rows: u16) void {
        self.local_cols = cols;
        self.local_rows = rows;
        self.clampOffset();
    }

    fn updateSession(self: *Viewport, cols: u16, rows: u16) void {
        self.session_cols = cols;
        self.session_rows = rows;
        self.clampOffset();
    }

    fn applyScroll(self: *Viewport, action: keybind.Action) void {
        switch (action) {
            .scroll_up => self.moveUp(),
            .scroll_down => self.moveDown(),
            .scroll_left => self.moveLeft(),
            .scroll_right => self.moveRight(),
            .scroll_page_up => self.pageUp(),
            .scroll_page_down => self.pageDown(),
            .scroll_top => self.jumpTopLeft(),
            .scroll_bottom => self.jumpBottomRight(),
            else => {},
        }
    }

    fn clampOffset(self: *Viewport) void {
        const max_x = if (self.session_cols > self.local_cols)
            self.session_cols - self.local_cols
        else
            0;
        const max_y = if (self.session_rows > self.local_rows)
            self.session_rows - self.local_rows
        else
            0;
        if (self.offset_x > max_x) self.offset_x = max_x;
        if (self.offset_y > max_y) self.offset_y = max_y;
    }
};

const Client = struct {
    fd: posix.fd_t,
    keys: keybind.State,
    cols: u16,
    rows: u16,
    session_name: []const u8,
    role: protocol.Role,
    viewport: Viewport,
    alloc: std.mem.Allocator,
    vterm: ?*terminal.VTerminal = null,
    running: bool = true,
    hint_visible: bool = false,

    fn handleInput(self: *Client, buf: []const u8) !void {
        var i: usize = 0;
        while (i < buf.len) {
            const byte = buf[i];
            const is_ctrl = byte == 0 or (byte >= 1 and byte <= 26) or (byte >= 0x1C and byte <= 0x1F);

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
            } else if (self.role == .viewer) {
                if (viewerNav(byte, is_ctrl)) |action| {
                    if (self.hint_visible) {
                        self.hint_visible = false;
                        self.clearHint();
                    }
                    try self.executeAction(action);
                } else {
                    self.flashViewerHint();
                }
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
            .scrollback => {
                protocol.writeMsg(self.fd, @intFromEnum(protocol.ClientMsg.scrollback), "") catch {};
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
            .scroll_up, .scroll_down, .scroll_left, .scroll_right, .scroll_page_up, .scroll_page_down, .scroll_top, .scroll_bottom => {
                self.viewport.applyScroll(action);
                self.renderViewport();
                self.renderStatusBar();
            },
            .cancel => {},
        }
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
        const msg = std.fmt.bufPrint(&buf, "\x1b7\x1b[{d};1H\x1b[K{s}\x1b8", .{ self.rows, hint }) catch return;
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
            \\   [       dump scrollback to terminal
            \\   s       toggle status bar
            \\   t       takeover (viewer becomes primary)
            \\   hjkl    pan viewport (when session > local size)
            \\   Ctrl+U  page up
            \\   Ctrl+D  page down
            \\   g/G     jump to top-left/bottom-right
            \\   ?       show this help
            \\   Esc     cancel
            \\
            \\ viewers: hjkl/u/d/g/G navigate without leader key
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
        w.print("\x1b[{d};1H\x1b[K", .{self.rows}) catch return; // move to last line, clear it

        // Left: session name in dim context
        w.writeAll("\x1b[2m \xe2\x94\x80 \x1b[0m") catch return; // dim " ─ "
        w.writeAll(self.session_name) catch return;

        // Right side: build info string, then pad
        var right_buf: [64]u8 = undefined;
        var right_fbs = std.io.fixedBufferStream(&right_buf);
        const rw = right_fbs.writer();
        var right_cols: usize = 0;

        if (self.viewport.needsPanning() and (self.viewport.offset_x > 0 or self.viewport.offset_y > 0)) {
            const n = std.fmt.count("+{d},+{d}  ", .{ self.viewport.offset_x, self.viewport.offset_y });
            rw.print("+{d},+{d}  ", .{ self.viewport.offset_x, self.viewport.offset_y }) catch {};
            right_cols += n;
        }

        if (self.role == .viewer) {
            rw.writeAll("viewer  ") catch {};
            right_cols += 8;
        }

        if (self.viewport.needsPanning()) {
            // "NNNxNNN " - use ascii x to keep byte/col count equal
            const n = std.fmt.count("{d}x{d} ", .{ self.viewport.session_cols, self.viewport.session_rows });
            rw.print("{d}x{d} ", .{ self.viewport.session_cols, self.viewport.session_rows }) catch {};
            right_cols += n;
        }

        const right = right_fbs.getWritten();
        // left visible len: 3 (" ─ ") + session_name.len
        const left_len = 3 + self.session_name.len;
        const total = left_len + right_cols;
        const padding: usize = if (self.cols > total) self.cols - total else 1;

        w.writeByteNTimes(' ', padding) catch return;
        w.writeAll("\x1b[2m") catch return; // dim for right side
        w.writeAll(right) catch return;
        w.writeAll("\x1b[0m\x1b8") catch return; // reset, restore cursor

        _ = posix.write(STDOUT, fbs.getWritten()) catch {};
    }

    fn flashViewerHint(self: *Client) void {
        const leader_name = self.keys.leaderName();
        var buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "\x1b7\x1b[{d};1H\x1b[K\x1b[2m viewer \xe2\x94\x82 {s}t takeover\x1b[0m\x1b8", .{ self.rows, leader_name }) catch return;
        _ = posix.write(STDOUT, msg) catch {};
        self.hint_visible = true;
    }

    fn ensureVTerm(self: *Client) !void {
        if (self.vterm != null) return;
        if (!self.viewport.needsPanning()) return;

        const vt = try self.alloc.create(terminal.VTerminal);
        vt.* = try terminal.VTerminal.init(
            self.alloc,
            self.viewport.session_cols,
            self.viewport.session_rows,
        );
        self.vterm = vt;
    }

    fn handleOutput(self: *Client, data: []const u8) void {
        if (self.viewport.needsPanning()) {
            self.ensureVTerm() catch {
                // Fallback: write directly
                _ = posix.write(STDOUT, data) catch {};
                return;
            };
            if (self.vterm) |vt| {
                vt.feed(data);
                self.renderViewport();
            }
        } else {
            _ = posix.write(STDOUT, data) catch {};
        }
    }

    fn renderViewport(self: *Client) void {
        const vt = self.vterm orelse return;
        const dump = vt.dumpViewport(
            self.alloc,
            self.viewport.offset_x,
            self.viewport.offset_y,
            self.viewport.local_cols,
            self.viewport.local_rows,
        ) catch return;
        defer self.alloc.free(dump);
        _ = posix.write(STDOUT, dump) catch {};
    }

    fn deinit(self: *Client) void {
        if (self.vterm) |vt| {
            vt.deinit();
            self.alloc.destroy(vt);
        }
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

pub fn attach(alloc: std.mem.Allocator, socket_path: []const u8, as_viewer: bool, cfg: *const config.Config) !void {
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

    var session_cols: u16 = size.cols;
    var session_rows: u16 = size.rows;

    switch (@as(protocol.ServerMsg, @enumFromInt(resp_header.msg_type))) {
        .welcome => {
            var buf: [@sizeOf(protocol.Welcome)]u8 = undefined;
            try protocol.readExact(fd, &buf);
            const welcome = std.mem.bytesToValue(protocol.Welcome, &buf);
            session_cols = welcome.session_cols;
            session_rows = welcome.session_rows;
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
        _ = posix.write(STDOUT, "\x1b[?1049h") catch {}; // enter alternate screen
    }
    defer {
        if (old_termios) |t| {
            _ = posix.write(STDOUT, "\x1b[?1049l") catch {}; // leave alternate screen
            restoreTermios(t);
        }
    }

    const session_name = std.fs.path.basename(socket_path);

    var client = Client{
        .fd = fd,
        .keys = keybind.State.init(cfg.toKeybindConfig()),
        .cols = size.cols,
        .rows = size.rows,
        .session_name = session_name,
        .role = role,
        .viewport = .{
            .session_cols = session_cols,
            .session_rows = session_rows,
            .local_cols = size.cols,
            .local_rows = size.rows,
        },
        .alloc = alloc,
    };
    defer client.deinit();

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
            client.viewport.updateLocal(size.cols, size.rows);
            if (client.viewport.needsPanning()) {
                client.renderViewport();
            }
            client.renderStatusBar();
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
                            client.handleOutput(buf[0..to_read]);
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
                .session_resize => {
                    var buf: [@sizeOf(protocol.SessionResize)]u8 = undefined;
                    protocol.readExact(client.fd, &buf) catch break;
                    const session_resize = std.mem.bytesToValue(protocol.SessionResize, &buf);
                    client.viewport.updateSession(session_resize.cols, session_resize.rows);
                    if (client.vterm) |vt| {
                        vt.resize(session_resize.cols, session_resize.rows) catch {};
                    }
                    if (client.viewport.needsPanning()) {
                        client.renderViewport();
                    } else {
                        _ = posix.write(STDOUT, "\x1b[2J\x1b[H") catch {};
                    }
                    client.renderStatusBar();
                },
                else => {
                    protocol.skipBytes(client.fd, header.len);
                },
            }
        }

        if (poll_fds[1].revents & (posix.POLL.HUP | posix.POLL.ERR) != 0) {
            break;
        }
    }
}

fn viewerNav(byte: u8, is_ctrl: bool) ?keybind.Action {
    if (is_ctrl) return switch (byte) {
        0x15 => .scroll_page_up, // Ctrl+U
        0x04 => .scroll_page_down, // Ctrl+D
        else => null,
    };
    return switch (byte) {
        'h' => .scroll_left,
        'j' => .scroll_down,
        'k' => .scroll_up,
        'l' => .scroll_right,
        'u' => .scroll_page_up,
        'd' => .scroll_page_down,
        'g' => .scroll_top,
        'G' => .scroll_bottom,
        else => null,
    };
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

test "viewport applyScroll" {
    var vp = Viewport{
        .session_cols = 120,
        .session_rows = 40,
        .local_cols = 80,
        .local_rows = 24,
    };
    vp.applyScroll(.scroll_down);
    try std.testing.expectEqual(@as(u16, 1), vp.offset_y);
    vp.applyScroll(.scroll_right);
    try std.testing.expectEqual(@as(u16, 1), vp.offset_x);
    vp.applyScroll(.scroll_bottom);
    try std.testing.expectEqual(@as(u16, 40 - 24), vp.offset_y);
    try std.testing.expectEqual(@as(u16, 120 - 80), vp.offset_x);
    vp.applyScroll(.scroll_top);
    try std.testing.expectEqual(@as(u16, 0), vp.offset_y);
    try std.testing.expectEqual(@as(u16, 0), vp.offset_x);
}

test "viewerNav basic mappings" {
    try std.testing.expectEqual(keybind.Action.scroll_left, viewerNav('h', false).?);
    try std.testing.expectEqual(keybind.Action.scroll_down, viewerNav('j', false).?);
    try std.testing.expectEqual(keybind.Action.scroll_up, viewerNav('k', false).?);
    try std.testing.expectEqual(keybind.Action.scroll_right, viewerNav('l', false).?);
    try std.testing.expectEqual(keybind.Action.scroll_page_up, viewerNav('u', false).?);
    try std.testing.expectEqual(keybind.Action.scroll_page_down, viewerNav('d', false).?);
    try std.testing.expectEqual(keybind.Action.scroll_top, viewerNav('g', false).?);
    try std.testing.expectEqual(keybind.Action.scroll_bottom, viewerNav('G', false).?);
}

test "viewerNav ctrl mappings" {
    try std.testing.expectEqual(keybind.Action.scroll_page_up, viewerNav(0x15, true).?);
    try std.testing.expectEqual(keybind.Action.scroll_page_down, viewerNav(0x04, true).?);
}

test "viewerNav unmapped keys return null" {
    try std.testing.expectEqual(@as(?keybind.Action, null), viewerNav('a', false));
    try std.testing.expectEqual(@as(?keybind.Action, null), viewerNav('z', false));
    try std.testing.expectEqual(@as(?keybind.Action, null), viewerNav(0x01, true));
}
