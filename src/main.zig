const std = @import("std");
const posix = std.posix;

const Pty = @import("pty.zig");
const Session = @import("session.zig");
const protocol = @import("protocol.zig");
const VTerminal = @import("terminal.zig");

const STDERR_FILENO = posix.STDERR_FILENO;
const STDOUT_FILENO = posix.STDOUT_FILENO;

const usage =
    \\vanish - terminal session multiplexer
    \\
    \\Usage:
    \\  vanish new <name> [--] <command> [args...]
    \\  vanish attach [--viewer] <name>
    \\  vanish send <name> <keys>
    \\  vanish list [--json] [directory]
    \\  vanish clients [--json] <name>
    \\  vanish kick <name> <client-id>
    \\
    \\Commands:
    \\  new      Create a new session
    \\  attach   Attach to an existing session (--viewer for read-only)
    \\  send     Send keys to a session (for scripting)
    \\  list     List available sessions (--json for machine-readable output)
    \\  clients  List connected clients (--json for machine-readable output)
    \\  kick     Disconnect a client by ID
    \\
    \\Notes:
    \\  <name> can be a session name (stored in $XDG_RUNTIME_DIR/vanish/)
    \\  or a full socket path (containing /)
    \\
;

fn writeAll(fd: posix.fd_t, data: []const u8) !void {
    var written: usize = 0;
    while (written < data.len) {
        const n = posix.write(fd, data[written..]) catch |err| {
            if (err == error.WouldBlock) continue;
            return err;
        };
        written += n;
    }
}

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len < 2) {
        try writeAll(STDERR_FILENO, usage);
        std.process.exit(1);
    }

    const cmd = args[1];

    if (std.mem.eql(u8, cmd, "new")) {
        try cmdNew(alloc, args[2..]);
    } else if (std.mem.eql(u8, cmd, "attach")) {
        try cmdAttach(alloc, args[2..]);
    } else if (std.mem.eql(u8, cmd, "send")) {
        try cmdSend(alloc, args[2..]);
    } else if (std.mem.eql(u8, cmd, "list")) {
        try cmdList(alloc, args[2..]);
    } else if (std.mem.eql(u8, cmd, "clients")) {
        try cmdClients(alloc, args[2..]);
    } else if (std.mem.eql(u8, cmd, "kick")) {
        try cmdKick(alloc, args[2..]);
    } else if (std.mem.eql(u8, cmd, "-h") or std.mem.eql(u8, cmd, "--help")) {
        try writeAll(STDOUT_FILENO, usage);
    } else {
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Unknown command: {s}\n", .{cmd}) catch "Unknown command\n";
        try writeAll(STDERR_FILENO, msg);
        try writeAll(STDERR_FILENO, usage);
        std.process.exit(1);
    }
}

fn cmdNew(alloc: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        try writeAll(STDERR_FILENO, "Usage: vanish new <socket|name> [--] <command> [args...]\n");
        std.process.exit(1);
    }

    const socket_path = try resolveSocketPath(alloc, args[0]);
    defer alloc.free(socket_path);

    var cmd_start: usize = 1;
    if (args.len > 1 and std.mem.eql(u8, args[1], "--")) {
        cmd_start = 2;
    }

    if (cmd_start >= args.len) {
        try writeAll(STDERR_FILENO, "Missing command\n");
        std.process.exit(1);
    }

    const cmd_args = args[cmd_start..];
    try Session.run(alloc, socket_path, cmd_args);
}

fn cmdAttach(alloc: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 1) {
        try writeAll(STDERR_FILENO, "Usage: vanish attach [--viewer] <socket|name>\n");
        std.process.exit(1);
    }

    var socket_arg: ?[]const u8 = null;
    var as_viewer = false;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--viewer") or std.mem.eql(u8, arg, "-v")) {
            as_viewer = true;
        } else if (socket_arg == null) {
            socket_arg = arg;
        }
    }

    if (socket_arg == null) {
        try writeAll(STDERR_FILENO, "Usage: vanish attach [--viewer] <socket|name>\n");
        std.process.exit(1);
    }

    const socket_path = try resolveSocketPath(alloc, socket_arg.?);
    defer alloc.free(socket_path);

    const Client = @import("client.zig");
    try Client.attach(alloc, socket_path, as_viewer);
}

fn cmdSend(alloc: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        try writeAll(STDERR_FILENO, "Usage: vanish send <socket|name> <keys>\n");
        std.process.exit(1);
    }

    const socket_path = try resolveSocketPath(alloc, args[0]);
    defer alloc.free(socket_path);

    const keys = args[1];
    const Client = @import("client.zig");
    try Client.send(socket_path, keys);
}

fn cmdList(alloc: std.mem.Allocator, args: []const []const u8) !void {
    var as_json = false;
    var explicit_dir: ?[]const u8 = null;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--json") or std.mem.eql(u8, arg, "-j")) {
            as_json = true;
        } else {
            explicit_dir = arg;
        }
    }

    const allocated_dir = if (explicit_dir == null) blk: {
        break :blk getDefaultSocketDir(alloc) catch {
            if (as_json) {
                try writeAll(STDOUT_FILENO, "{\"error\":\"Could not determine socket directory\"}\n");
            } else {
                try writeAll(STDERR_FILENO, "Could not determine socket directory\n");
            }
            return;
        };
    } else null;
    defer if (allocated_dir) |d| alloc.free(d);

    const dir_path = explicit_dir orelse allocated_dir.?;

    var dir = std.fs.openDirAbsolute(dir_path, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) {
            if (as_json) {
                try writeAll(STDOUT_FILENO, "{\"sessions\":[]}\n");
            } else {
                try writeAll(STDOUT_FILENO, "No sessions found\n");
            }
            return;
        }
        return err;
    };
    defer dir.close();

    var sessions: std.ArrayList([]const u8) = .empty;
    defer {
        for (sessions.items) |s| alloc.free(s);
        sessions.deinit(alloc);
    }

    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .unix_domain_socket) {
            const name = try alloc.dupe(u8, entry.name);
            try sessions.append(alloc, name);
        }
    }

    if (as_json) {
        try writeJsonList(alloc, sessions.items, dir_path);
    } else {
        if (sessions.items.len == 0) {
            try writeAll(STDOUT_FILENO, "No sessions found\n");
        } else {
            for (sessions.items) |name| {
                var buf: [std.fs.max_path_bytes]u8 = undefined;
                const msg = if (explicit_dir != null)
                    std.fmt.bufPrint(&buf, "{s}/{s}\n", .{ dir_path, name }) catch continue
                else
                    std.fmt.bufPrint(&buf, "{s}\n", .{name}) catch continue;
                try writeAll(STDOUT_FILENO, msg);
            }
        }
    }
}

fn writeJsonList(alloc: std.mem.Allocator, sessions: []const []const u8, dir_path: []const u8) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(alloc);

    try out.appendSlice(alloc, "{\"sessions\":[");

    for (sessions, 0..) |name, i| {
        if (i > 0) try out.append(alloc, ',');
        try out.appendSlice(alloc, "{\"name\":\"");
        try appendJsonString(&out, alloc, name);
        try out.appendSlice(alloc, "\",\"path\":\"");
        try appendJsonString(&out, alloc, dir_path);
        try out.append(alloc, '/');
        try appendJsonString(&out, alloc, name);
        try out.appendSlice(alloc, "\"}");
    }

    try out.appendSlice(alloc, "]}\n");
    try writeAll(STDOUT_FILENO, out.items);
}

fn cmdClients(alloc: std.mem.Allocator, args: []const []const u8) !void {
    var as_json = false;
    var socket_arg: ?[]const u8 = null;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--json") or std.mem.eql(u8, arg, "-j")) {
            as_json = true;
        } else if (socket_arg == null) {
            socket_arg = arg;
        }
    }

    if (socket_arg == null) {
        try writeAll(STDERR_FILENO, "Usage: vanish clients [--json] <socket|name>\n");
        std.process.exit(1);
    }

    const socket_path = try resolveSocketPath(alloc, socket_arg.?);
    defer alloc.free(socket_path);

    const sock = connectToSession(socket_path) catch |err| {
        if (as_json) {
            try writeAll(STDOUT_FILENO, "{\"error\":\"Could not connect to session\"}\n");
        } else {
            var buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Could not connect to session: {}\n", .{err}) catch "Could not connect\n";
            try writeAll(STDERR_FILENO, msg);
        }
        std.process.exit(1);
    };
    defer posix.close(sock);

    // Send hello as viewer (we're just querying)
    var hello = protocol.Hello{ .role = .viewer, .cols = 80, .rows = 24 };
    hello.setTerm("xterm-256color");
    try protocol.writeStruct(sock, @intFromEnum(protocol.ClientMsg.hello), hello);

    // Read welcome
    const welcome_hdr = try protocol.readHeader(sock);
    if (welcome_hdr.msg_type == @intFromEnum(protocol.ServerMsg.denied)) {
        if (as_json) {
            try writeAll(STDOUT_FILENO, "{\"error\":\"Connection denied\"}\n");
        } else {
            try writeAll(STDERR_FILENO, "Connection denied\n");
        }
        std.process.exit(1);
    }
    var welcome_buf: [@sizeOf(protocol.Welcome)]u8 = undefined;
    try protocol.readExact(sock, &welcome_buf);

    // Skip full state if sent
    const state_hdr = protocol.readHeader(sock) catch {
        if (as_json) {
            try writeAll(STDOUT_FILENO, "{\"error\":\"Protocol error\"}\n");
        } else {
            try writeAll(STDERR_FILENO, "Protocol error\n");
        }
        std.process.exit(1);
    };
    if (state_hdr.msg_type == @intFromEnum(protocol.ServerMsg.full)) {
        const skip = try alloc.alloc(u8, state_hdr.len);
        defer alloc.free(skip);
        protocol.readExact(sock, skip) catch {};
    }

    // Send list_clients request
    try protocol.writeMsg(sock, @intFromEnum(protocol.ClientMsg.list_clients), &.{});

    // Read client_list response
    const list_hdr = try protocol.readHeader(sock);
    if (list_hdr.msg_type != @intFromEnum(protocol.ServerMsg.client_list)) {
        if (as_json) {
            try writeAll(STDOUT_FILENO, "{\"error\":\"Unexpected response\"}\n");
        } else {
            try writeAll(STDERR_FILENO, "Unexpected response\n");
        }
        std.process.exit(1);
    }

    const payload = try protocol.readPayload(alloc, sock, list_hdr.len);
    defer alloc.free(payload);

    const client_count = list_hdr.len / @sizeOf(protocol.ClientInfo);

    if (as_json) {
        try writeClientsJson(alloc, payload, client_count);
    } else {
        try writeClientsText(payload, client_count);
    }
}

fn writeClientsText(payload: []const u8, count: usize) !void {
    if (count == 0) {
        try writeAll(STDOUT_FILENO, "No clients connected\n");
        return;
    }

    try writeAll(STDOUT_FILENO, "ID\tRole\tSize\n");
    var i: usize = 0;
    while (i < count) : (i += 1) {
        const offset = i * @sizeOf(protocol.ClientInfo);
        const info = std.mem.bytesToValue(protocol.ClientInfo, payload[offset..][0..@sizeOf(protocol.ClientInfo)]);
        var buf: [64]u8 = undefined;
        const role_str = if (info.role == .primary) "primary" else "viewer";
        const msg = std.fmt.bufPrint(&buf, "{d}\t{s}\t{d}x{d}\n", .{ info.id, role_str, info.cols, info.rows }) catch continue;
        try writeAll(STDOUT_FILENO, msg);
    }
}

fn writeClientsJson(alloc: std.mem.Allocator, payload: []const u8, count: usize) !void {
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(alloc);

    try out.appendSlice(alloc, "{\"clients\":[");

    var i: usize = 0;
    while (i < count) : (i += 1) {
        if (i > 0) try out.append(alloc, ',');
        const offset = i * @sizeOf(protocol.ClientInfo);
        const info = std.mem.bytesToValue(protocol.ClientInfo, payload[offset..][0..@sizeOf(protocol.ClientInfo)]);
        var buf: [128]u8 = undefined;
        const role_str = if (info.role == .primary) "primary" else "viewer";
        const entry = std.fmt.bufPrint(&buf, "{{\"id\":{d},\"role\":\"{s}\",\"cols\":{d},\"rows\":{d}}}", .{ info.id, role_str, info.cols, info.rows }) catch continue;
        try out.appendSlice(alloc, entry);
    }

    try out.appendSlice(alloc, "]}\n");
    try writeAll(STDOUT_FILENO, out.items);
}

fn cmdKick(alloc: std.mem.Allocator, args: []const []const u8) !void {
    if (args.len < 2) {
        try writeAll(STDERR_FILENO, "Usage: vanish kick <socket|name> <client-id>\n");
        std.process.exit(1);
    }

    const socket_path = try resolveSocketPath(alloc, args[0]);
    defer alloc.free(socket_path);

    const client_id = std.fmt.parseInt(u32, args[1], 10) catch {
        try writeAll(STDERR_FILENO, "Invalid client ID\n");
        std.process.exit(1);
    };

    const sock = connectToSession(socket_path) catch |err| {
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Could not connect to session: {}\n", .{err}) catch "Could not connect\n";
        try writeAll(STDERR_FILENO, msg);
        std.process.exit(1);
    };
    defer posix.close(sock);

    // Send hello as viewer
    var hello = protocol.Hello{ .role = .viewer, .cols = 80, .rows = 24 };
    hello.setTerm("xterm-256color");
    try protocol.writeStruct(sock, @intFromEnum(protocol.ClientMsg.hello), hello);

    // Read welcome
    const welcome_hdr = try protocol.readHeader(sock);
    if (welcome_hdr.msg_type == @intFromEnum(protocol.ServerMsg.denied)) {
        try writeAll(STDERR_FILENO, "Connection denied\n");
        std.process.exit(1);
    }
    var welcome_buf: [@sizeOf(protocol.Welcome)]u8 = undefined;
    try protocol.readExact(sock, &welcome_buf);

    // Skip full state if sent
    const state_hdr = protocol.readHeader(sock) catch {
        try writeAll(STDERR_FILENO, "Protocol error\n");
        std.process.exit(1);
    };
    if (state_hdr.msg_type == @intFromEnum(protocol.ServerMsg.full)) {
        const skip = try alloc.alloc(u8, state_hdr.len);
        defer alloc.free(skip);
        protocol.readExact(sock, skip) catch {};
    }

    // Send kick request
    const kick = protocol.KickClient{ .id = client_id };
    try protocol.writeStruct(sock, @intFromEnum(protocol.ClientMsg.kick_client), kick);

    try writeAll(STDOUT_FILENO, "Kick request sent\n");
}

fn connectToSession(path: []const u8) !posix.socket_t {
    const sock = try posix.socket(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0);
    errdefer posix.close(sock);

    var addr = std.net.Address.initUnix(path) catch return error.PathTooLong;
    try posix.connect(sock, &addr.any, addr.getOsSockLen());

    return sock;
}

fn appendJsonString(out: *std.ArrayList(u8), alloc: std.mem.Allocator, s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try out.appendSlice(alloc, "\\\""),
            '\\' => try out.appendSlice(alloc, "\\\\"),
            '\n' => try out.appendSlice(alloc, "\\n"),
            '\r' => try out.appendSlice(alloc, "\\r"),
            '\t' => try out.appendSlice(alloc, "\\t"),
            else => {
                if (c < 0x20) {
                    var buf: [6]u8 = undefined;
                    _ = std.fmt.bufPrint(&buf, "\\u{x:0>4}", .{c}) catch continue;
                    try out.appendSlice(alloc, &buf);
                } else {
                    try out.append(alloc, c);
                }
            },
        }
    }
}

fn getDefaultSocketDir(alloc: std.mem.Allocator) ![]const u8 {
    if (std.posix.getenv("XDG_RUNTIME_DIR")) |xdg| {
        return try std.fmt.allocPrint(alloc, "{s}/vanish", .{xdg});
    }
    const uid = std.os.linux.getuid();
    return try std.fmt.allocPrint(alloc, "/tmp/vanish-{d}", .{uid});
}

fn resolveSocketPath(alloc: std.mem.Allocator, name_or_path: []const u8) ![]const u8 {
    if (std.mem.indexOf(u8, name_or_path, "/") != null) {
        return try alloc.dupe(u8, name_or_path);
    }
    const dir = try getDefaultSocketDir(alloc);
    defer alloc.free(dir);
    return try std.fmt.allocPrint(alloc, "{s}/{s}", .{ dir, name_or_path });
}

test "basic" {
    // Placeholder
}
