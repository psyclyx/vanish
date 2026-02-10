const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const Pty = @import("pty.zig").Pty;
const protocol = @import("protocol.zig");
const VTerminal = @import("terminal.zig");
const sig = @import("signal.zig");

const Client = struct {
    fd: posix.fd_t,
    id: u32,
    role: protocol.Role,
    cols: u16 = 80,
    rows: u16 = 24,
};

const Session = @This();

alloc: std.mem.Allocator,
pty: Pty,
socket: posix.socket_t,
socket_path: []const u8,
terminal: ?VTerminal = null,
primary: ?Client = null,
viewers: std.ArrayList(Client) = .empty,
running: bool = true,
cols: u16 = 80,
rows: u16 = 24,
next_client_id: u32 = 1,

pub fn run(alloc: std.mem.Allocator, socket_path: []const u8, session_name: []const u8, argv: []const []const u8) !void {
    return runWithNotify(alloc, socket_path, session_name, argv, null);
}

pub fn runWithNotify(alloc: std.mem.Allocator, socket_path: []const u8, session_name: []const u8, argv: []const []const u8, notify_fd: ?posix.fd_t) !void {
    var pty = try Pty.open();
    errdefer pty.close();

    setSessionEnv(session_name, socket_path);
    try pty.resize(.{ .rows = 24, .cols = 80 });
    try pty.spawn(argv, null);

    const socket = try createSocket(socket_path);
    errdefer {
        posix.close(socket);
        std.fs.deleteFileAbsolute(socket_path) catch {};
    }

    var terminal = try VTerminal.init(alloc, 80, 24);
    errdefer terminal.deinit();

    sig.setup();

    // Notify parent that socket is ready
    if (notify_fd) |fd| {
        _ = posix.write(fd, "R") catch {};
        posix.close(fd);
    }

    var session = Session{
        .alloc = alloc,
        .pty = pty,
        .socket = socket,
        .socket_path = socket_path,
        .terminal = terminal,
    };
    defer session.deinit();

    try session.eventLoop();
}

fn deinit(self: *Session) void {
    if (self.terminal) |*t| t.deinit();
    if (self.primary) |c| posix.close(c.fd);
    for (self.viewers.items) |c| posix.close(c.fd);
    self.viewers.deinit(self.alloc);
    posix.close(self.socket);
    std.fs.deleteFileAbsolute(self.socket_path) catch {};
    self.pty.close();
}

fn eventLoop(self: *Session) !void {
    var poll_fds: std.ArrayList(posix.pollfd) = .empty;
    defer poll_fds.deinit(self.alloc);

    while (self.running) {
        if (sig.checkTerm()) {
            self.running = false;
            break;
        }

        poll_fds.clearRetainingCapacity();

        try poll_fds.append(self.alloc, .{
            .fd = self.pty.master,
            .events = posix.POLL.IN,
            .revents = 0,
        });

        try poll_fds.append(self.alloc, .{
            .fd = self.socket,
            .events = posix.POLL.IN,
            .revents = 0,
        });

        if (self.primary) |c| {
            try poll_fds.append(self.alloc, .{
                .fd = c.fd,
                .events = posix.POLL.IN,
                .revents = 0,
            });
        }

        for (self.viewers.items) |c| {
            try poll_fds.append(self.alloc, .{
                .fd = c.fd,
                .events = posix.POLL.IN,
                .revents = 0,
            });
        }

        const ready = posix.poll(poll_fds.items, -1) catch |err| {
            if (err == error.Interrupted) continue;
            return err;
        };

        if (ready == 0) continue;

        var idx: usize = 0;

        if (poll_fds.items[idx].revents & posix.POLL.IN != 0) {
            try self.handlePtyOutput();
        }
        if (poll_fds.items[idx].revents & posix.POLL.HUP != 0) {
            self.running = false;
            continue;
        }
        idx += 1;

        if (poll_fds.items[idx].revents & posix.POLL.IN != 0) {
            try self.handleNewConnection();
        }
        idx += 1;

        if (self.primary != null and idx < poll_fds.items.len) {
            if (poll_fds.items[idx].revents & posix.POLL.IN != 0) {
                try self.handleClientInput(true, 0);
            }
            if (poll_fds.items[idx].revents & (posix.POLL.HUP | posix.POLL.ERR) != 0) {
                self.removePrimary();
            }
            idx += 1;
        }

        var viewer_idx: usize = 0;
        while (viewer_idx < self.viewers.items.len) {
            const fd_idx = idx + viewer_idx;
            if (fd_idx < poll_fds.items.len) {
                // Process input before checking HUP so we don't lose messages
                if (poll_fds.items[fd_idx].revents & posix.POLL.IN != 0) {
                    try self.handleClientInput(false, viewer_idx);
                }
                if (poll_fds.items[fd_idx].revents & (posix.POLL.HUP | posix.POLL.ERR) != 0) {
                    self.removeViewer(viewer_idx);
                    continue;
                }
            }
            viewer_idx += 1;
        }
    }

    // If session was killed (not just child exiting), signal the child first
    self.pty.killChild();
    const status = self.pty.wait() catch 0;
    const exit_msg = protocol.Exit{ .code = @intCast(status) };
    if (self.primary) |c| {
        protocol.writeStruct(c.fd, @intFromEnum(protocol.ServerMsg.exit), exit_msg) catch {};
    }
    for (self.viewers.items) |c| {
        protocol.writeStruct(c.fd, @intFromEnum(protocol.ServerMsg.exit), exit_msg) catch {};
    }
}

fn handlePtyOutput(self: *Session) !void {
    var buf: [4096]u8 = undefined;
    const n = posix.read(self.pty.master, &buf) catch |err| {
        if (err == error.WouldBlock) return;
        return err;
    };
    if (n == 0) {
        self.running = false;
        return;
    }

    const data = buf[0..n];

    // Feed data through terminal emulator for state tracking
    if (self.terminal) |*term| {
        term.feed(data);
    }

    // Forward to all clients
    if (self.primary) |c| {
        protocol.writeMsg(c.fd, @intFromEnum(protocol.ServerMsg.output), data) catch {
            self.removePrimary();
        };
    }
    var i = self.viewers.items.len;
    while (i > 0) {
        i -= 1;
        protocol.writeMsg(self.viewers.items[i].fd, @intFromEnum(protocol.ServerMsg.output), data) catch {
            self.removeViewer(i);
        };
    }
}

fn handleNewConnection(self: *Session) !void {
    const conn = posix.accept(self.socket, null, null, posix.SOCK.CLOEXEC) catch return;

    const header = protocol.readHeader(conn) catch {
        posix.close(conn);
        return;
    };

    if (header.msg_type != @intFromEnum(protocol.ClientMsg.hello)) {
        posix.close(conn);
        return;
    }

    if (header.len != @sizeOf(protocol.Hello)) {
        const denied = protocol.Denied{ .reason = .invalid_hello };
        protocol.writeStruct(conn, @intFromEnum(protocol.ServerMsg.denied), denied) catch {};
        posix.close(conn);
        return;
    }

    var hello_buf: [@sizeOf(protocol.Hello)]u8 = undefined;
    protocol.readExact(conn, &hello_buf) catch {
        posix.close(conn);
        return;
    };
    const hello = std.mem.bytesToValue(protocol.Hello, &hello_buf);

    if (hello.role == .primary and self.primary != null) {
        const denied = protocol.Denied{ .reason = .primary_exists };
        protocol.writeStruct(conn, @intFromEnum(protocol.ServerMsg.denied), denied) catch {};
        posix.close(conn);
        return;
    }

    const welcome = protocol.Welcome{
        .role = hello.role,
        .session_id = std.mem.zeroes([16]u8),
        .session_cols = self.cols,
        .session_rows = self.rows,
    };
    protocol.writeStruct(conn, @intFromEnum(protocol.ServerMsg.welcome), welcome) catch {
        posix.close(conn);
        return;
    };

    // Send current terminal state to new client
    self.sendTerminalState(conn) catch {};

    const client_id = self.next_client_id;
    self.next_client_id += 1;

    const client = Client{
        .fd = conn,
        .id = client_id,
        .role = hello.role,
        .cols = hello.cols,
        .rows = hello.rows,
    };

    if (hello.role == .primary) {
        self.primary = client;
        self.cols = hello.cols;
        self.rows = hello.rows;
        self.pty.resize(.{ .rows = hello.rows, .cols = hello.cols }) catch {};
        if (self.terminal) |*term| {
            term.resize(hello.cols, hello.rows) catch {};
        }
    } else {
        self.viewers.append(self.alloc, client) catch {
            posix.close(conn);
            return;
        };
    }
}

fn sendTerminalState(self: *Session, fd: posix.fd_t) !void {
    if (self.terminal) |*term| {
        const screen = term.dumpScreen(self.alloc) catch return;
        defer self.alloc.free(screen);

        if (screen.len > 0) {
            try protocol.writeMsg(fd, @intFromEnum(protocol.ServerMsg.full), screen);
        }
    }
}

fn handleClientInput(self: *Session, is_primary: bool, viewer_idx: usize) !void {
    const client = if (is_primary) &self.primary.? else &self.viewers.items[viewer_idx];

    const header = protocol.readHeader(client.fd) catch {
        if (is_primary) self.removePrimary() else self.removeViewer(viewer_idx);
        return;
    };

    switch (@as(protocol.ClientMsg, @enumFromInt(header.msg_type))) {
        .input => {
            if (is_primary and header.len > 0) {
                var buf: [4096]u8 = undefined;
                const to_read = @min(header.len, buf.len);
                protocol.readExact(client.fd, buf[0..to_read]) catch {
                    self.removePrimary();
                    return;
                };
                _ = posix.write(self.pty.master, buf[0..to_read]) catch {};
            } else {
                protocol.skipBytes(client.fd, header.len);
            }
        },
        .resize => {
            const resize = protocol.readStruct(protocol.Resize, client.fd, header.len) catch return orelse return;
            if (is_primary) {
                client.cols = resize.cols;
                client.rows = resize.rows;
                self.cols = resize.cols;
                self.rows = resize.rows;
                self.pty.resize(.{ .rows = resize.rows, .cols = resize.cols }) catch {};
                if (self.terminal) |*term| {
                    term.resize(resize.cols, resize.rows) catch {};
                }
                self.notifyViewersResize();
            }
        },
        .detach => {
            if (is_primary) self.removePrimary() else self.removeViewer(viewer_idx);
        },
        .scrollback => {
            self.sendScrollback(client.fd) catch {};
        },
        .takeover => {
            if (!is_primary) {
                self.handleTakeover(viewer_idx) catch {};
            }
        },
        .list_clients => {
            self.sendClientList(client.fd) catch {};
        },
        .kick_client => {
            const kick = protocol.readStruct(protocol.KickClient, client.fd, header.len) catch return orelse return;
            self.kickClient(kick.id);
        },
        .kill_session => {
            self.running = false;
        },
        else => {
            protocol.skipBytes(client.fd, header.len);
        },
    }
}

fn sendScrollback(self: *Session, fd: posix.fd_t) !void {
    if (self.terminal) |*term| {
        // Don't send pre-clear scrollback to avoid terminal divergence
        if (term.screen_cleared) {
            return;
        }

        const scrollback = term.dumpScrollback(self.alloc) catch return;
        defer self.alloc.free(scrollback);

        if (scrollback.len > 0) {
            try protocol.writeMsg(fd, @intFromEnum(protocol.ServerMsg.full), scrollback);
        }
    }
}

fn handleTakeover(self: *Session, viewer_idx: usize) !void {
    if (viewer_idx >= self.viewers.items.len) return;

    const new_primary = self.viewers.items[viewer_idx];

    // Demote current primary to viewer if exists
    if (self.primary) |old_primary| {
        const demote = protocol.RoleChange{ .new_role = .viewer };
        protocol.writeStruct(old_primary.fd, @intFromEnum(protocol.ServerMsg.role_change), demote) catch {
            posix.close(old_primary.fd);
            self.primary = null;
        };
        if (self.primary != null) {
            self.viewers.append(self.alloc, old_primary) catch {
                posix.close(old_primary.fd);
            };
        }
    }

    // Remove new primary from viewers list
    _ = self.viewers.swapRemove(viewer_idx);

    // Promote viewer to primary
    self.primary = Client{
        .fd = new_primary.fd,
        .id = new_primary.id,
        .role = .primary,
        .cols = new_primary.cols,
        .rows = new_primary.rows,
    };

    // Notify new primary of role change
    const promote = protocol.RoleChange{ .new_role = .primary };
    try protocol.writeStruct(new_primary.fd, @intFromEnum(protocol.ServerMsg.role_change), promote);

    // Resize terminal to new primary's size
    self.cols = new_primary.cols;
    self.rows = new_primary.rows;
    self.pty.resize(.{ .rows = new_primary.rows, .cols = new_primary.cols }) catch {};
    if (self.terminal) |*term| {
        term.resize(new_primary.cols, new_primary.rows) catch {};
    }
}

fn sendClientList(self: *Session, fd: posix.fd_t) !void {
    const count: usize = (if (self.primary != null) @as(usize, 1) else 0) + self.viewers.items.len;
    const payload_size = count * @sizeOf(protocol.ClientInfo);

    var payload = try self.alloc.alloc(u8, payload_size);
    defer self.alloc.free(payload);

    var offset: usize = 0;
    if (self.primary) |p| {
        const info = protocol.ClientInfo{
            .id = p.id,
            .role = p.role,
            .cols = p.cols,
            .rows = p.rows,
        };
        @memcpy(payload[offset..][0..@sizeOf(protocol.ClientInfo)], std.mem.asBytes(&info));
        offset += @sizeOf(protocol.ClientInfo);
    }
    for (self.viewers.items) |v| {
        const info = protocol.ClientInfo{
            .id = v.id,
            .role = v.role,
            .cols = v.cols,
            .rows = v.rows,
        };
        @memcpy(payload[offset..][0..@sizeOf(protocol.ClientInfo)], std.mem.asBytes(&info));
        offset += @sizeOf(protocol.ClientInfo);
    }

    try protocol.writeMsg(fd, @intFromEnum(protocol.ServerMsg.client_list), payload);
}

fn kickClient(self: *Session, target_id: u32) void {
    if (self.primary) |p| {
        if (p.id == target_id) {
            self.removePrimary();
            return;
        }
    }
    for (self.viewers.items, 0..) |v, i| {
        if (v.id == target_id) {
            self.removeViewer(i);
            return;
        }
    }
}

fn notifyViewersResize(self: *Session) void {
    const resize_msg = protocol.SessionResize{
        .cols = self.cols,
        .rows = self.rows,
    };
    for (self.viewers.items) |c| {
        protocol.writeStruct(c.fd, @intFromEnum(protocol.ServerMsg.session_resize), resize_msg) catch {};
    }
}

fn removePrimary(self: *Session) void {
    if (self.primary) |c| {
        posix.close(c.fd);
        self.primary = null;
    }
}

fn removeViewer(self: *Session, idx: usize) void {
    if (idx < self.viewers.items.len) {
        posix.close(self.viewers.items[idx].fd);
        _ = self.viewers.swapRemove(idx);
    }
}

fn createSocket(path: []const u8) !posix.socket_t {
    if (std.fs.path.dirname(path)) |dir| {
        std.fs.makeDirAbsolute(dir) catch |err| {
            if (err != error.PathAlreadyExists) return err;
        };
    }

    if (isSocketLive(path)) return error.SessionAlreadyExists;
    std.fs.deleteFileAbsolute(path) catch {};

    const sock = try posix.socket(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0);
    errdefer posix.close(sock);

    var addr = std.net.Address.initUnix(path) catch return error.PathTooLong;
    try posix.bind(sock, &addr.any, addr.getOsSockLen());
    try posix.listen(sock, 5);

    return sock;
}

fn setSessionEnv(name: []const u8, socket_path: []const u8) void {
    const setenv = struct {
        extern "c" fn setenv(name: [*:0]const u8, value: [*:0]const u8, overwrite: c_int) c_int;
    }.setenv;

    var name_buf: [65]u8 = undefined;
    var sock_buf: [std.fs.max_path_bytes + 1]u8 = undefined;

    if (name.len < name_buf.len) {
        @memcpy(name_buf[0..name.len], name);
        name_buf[name.len] = 0;
        _ = setenv("VANISH_SESSION", @ptrCast(name_buf[0..name.len :0]), 1);
    }
    if (socket_path.len < sock_buf.len) {
        @memcpy(sock_buf[0..socket_path.len], socket_path);
        sock_buf[socket_path.len] = 0;
        _ = setenv("VANISH_SOCKET", @ptrCast(sock_buf[0..socket_path.len :0]), 1);
    }
}

/// Probe a Unix socket path to check if a session is listening.
pub fn isSocketLive(path: []const u8) bool {
    const probe = posix.socket(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0) catch return false;
    defer posix.close(probe);
    var addr = std.net.Address.initUnix(path) catch return false;
    posix.connect(probe, &addr.any, addr.getOsSockLen()) catch return false;
    return true;
}
