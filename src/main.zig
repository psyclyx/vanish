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
    \\  vanish list [directory]
    \\
    \\Commands:
    \\  new      Create a new session
    \\  attach   Attach to an existing session (--viewer for read-only)
    \\  list     List available sessions
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
    } else if (std.mem.eql(u8, cmd, "list")) {
        try cmdList(alloc, args[2..]);
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

fn cmdList(alloc: std.mem.Allocator, args: []const []const u8) !void {
    const show_full_path = args.len > 0;
    const dir_path = if (args.len > 0) args[0] else blk: {
        const path = getDefaultSocketDir(alloc) catch {
            try writeAll(STDERR_FILENO, "Could not determine socket directory\n");
            return;
        };
        break :blk path;
    };

    var dir = std.fs.openDirAbsolute(dir_path, .{ .iterate = true }) catch |err| {
        if (err == error.FileNotFound) {
            try writeAll(STDOUT_FILENO, "No sessions found\n");
            return;
        }
        return err;
    };
    defer dir.close();

    var found = false;
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .unix_domain_socket) {
            var buf: [std.fs.max_path_bytes]u8 = undefined;
            const msg = if (show_full_path)
                std.fmt.bufPrint(&buf, "{s}/{s}\n", .{ dir_path, entry.name }) catch continue
            else
                std.fmt.bufPrint(&buf, "{s}\n", .{entry.name}) catch continue;
            try writeAll(STDOUT_FILENO, msg);
            found = true;
        }
    }

    if (!found) {
        try writeAll(STDOUT_FILENO, "No sessions found\n");
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
