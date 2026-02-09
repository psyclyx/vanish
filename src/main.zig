const std = @import("std");
const posix = std.posix;

const Pty = @import("pty.zig");
const Session = @import("session.zig");
const protocol = @import("protocol.zig");
const VTerminal = @import("terminal.zig");
const config = @import("config.zig");
const paths = @import("paths.zig");
const naming = @import("naming.zig");
const Auth = @import("auth.zig");
const HttpServer = @import("http.zig");

const STDERR_FILENO = posix.STDERR_FILENO;
const STDOUT_FILENO = posix.STDOUT_FILENO;

const usage_header =
    \\vanish - terminal session multiplexer
    \\
    \\Usage:
    \\  vanish [options] <command> [command-options]
    \\
    \\Global options:
    \\  -c, --config <path>  Config file (default: {s})
    \\  -v                   Verbose output
    \\  -vv                  Debug output
    \\  -h, --help           Show this help
    \\
    \\Commands:
    \\  new          Create session and attach
    \\  attach       Attach to existing session
    \\  send         Send keys to a session
    \\  list         List sessions
    \\  clients      List connected clients
    \\  kick         Disconnect a client
    \\  kill         Terminate a session
    \\  serve        Start HTTP server for web terminal access
    \\  otp          Generate one-time password for auth
    \\  revoke       Revoke authentication tokens
    \\  print-config Print effective configuration
    \\
    \\Run 'vanish <command> --help' for command-specific options.
    \\
;

const usage_commands =
    \\Command usage:
    \\  vanish new [--detach] [--auto-name] [--serve] <name> <command> [args...]
    \\  vanish attach [--primary] <name>
    \\  vanish send <name> <keys>
    \\  vanish list [--json]
    \\  vanish clients [--json] <name>
    \\  vanish kick <name> <client-id>
    \\  vanish kill <name>
    \\  vanish serve [options]
    \\  vanish otp [options]
    \\  vanish revoke [options]
    \\  vanish print-config
    \\
    \\Serve options:
    \\  -b, --bind <addr>    Bind address (default: 127.0.0.1 and ::1)
    \\  -p, --port <port>    Port (default: 7890)
    \\  -d, --daemonize      Run in background
    \\
    \\OTP options:
    \\  --duration <time>    Temporary token (e.g., "1h", "30m", "7d")
    \\  --session <name>     Scoped to session
    \\  --daemon             Valid until HTTP server restarts
    \\  --indefinite         Never expires (default)
    \\  --read-only          View only (no input, takeover, or resize)
    \\
    \\Revoke options:
    \\  --temporary          Revoke all duration-based tokens
    \\  --session <name>     Revoke tokens for specific session
    \\  --daemon             Revoke all daemon-scoped tokens
    \\  --indefinite         Revoke all indefinite tokens
    \\  --all                Revoke everything
    \\
;

pub const Verbosity = enum(u2) {
    quiet = 0,
    verbose = 1,
    debug = 2,
};

var global_verbosity: Verbosity = .quiet;

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

fn logVerbose(comptime fmt: []const u8, args: anytype) void {
    if (@intFromEnum(global_verbosity) >= @intFromEnum(Verbosity.verbose)) {
        var buf: [1024]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, fmt ++ "\n", args) catch return;
        writeAll(STDERR_FILENO, msg) catch {};
    }
}

fn logDebug(comptime fmt: []const u8, args: anytype) void {
    if (@intFromEnum(global_verbosity) >= @intFromEnum(Verbosity.debug)) {
        var buf: [1024]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "[debug] " ++ fmt ++ "\n", args) catch return;
        writeAll(STDERR_FILENO, msg) catch {};
    }
}

fn leaderToString(key: u8) []const u8 {
    return switch (key) {
        0x00 => "^ ",
        1...26 => &[_]u8{ '^', 'A' + key - 1 },
        0x1B => "^[",
        0x1C => "^\\",
        0x1D => "^]",
        0x1E => "^^",
        0x1F => "^_",
        else => "?",
    };
}

fn printUsage(alloc: std.mem.Allocator) void {
    const default_path = config.getDefaultConfigPath(alloc);
    defer if (default_path) |p| alloc.free(p);

    var buf: [2048]u8 = undefined;
    const header = std.fmt.bufPrint(&buf, usage_header, .{default_path orelse "(none)"}) catch usage_header;
    writeAll(STDOUT_FILENO, header) catch {};
    writeAll(STDOUT_FILENO, usage_commands) catch {};
}

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    // Parse global options
    var config_path: ?[]const u8 = null;
    var arg_idx: usize = 1;

    while (arg_idx < args.len) {
        const arg = args[arg_idx];
        if (std.mem.eql(u8, arg, "-c") or std.mem.eql(u8, arg, "--config")) {
            arg_idx += 1;
            if (arg_idx >= args.len) {
                try writeAll(STDERR_FILENO, "Error: --config requires a path argument\n");
                std.process.exit(1);
            }
            config_path = args[arg_idx];
            arg_idx += 1;
        } else if (std.mem.eql(u8, arg, "-vv")) {
            global_verbosity = .debug;
            arg_idx += 1;
        } else if (std.mem.eql(u8, arg, "-v")) {
            global_verbosity = .verbose;
            arg_idx += 1;
        } else if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printUsage(alloc);
            return;
        } else if (arg.len > 0 and arg[0] == '-') {
            // Unknown global option - might be command-specific, stop parsing
            break;
        } else {
            // Not an option, must be the command
            break;
        }
    }

    if (arg_idx >= args.len) {
        printUsage(alloc);
        std.process.exit(1);
    }

    // Load config
    const load_result = config.load(alloc, config_path);
    var cfg = load_result.config;
    defer cfg.deinit();
    defer if (load_result.path_searched) |p| alloc.free(p);

    // Log config loading
    if (load_result.path_used) |path| {
        logVerbose("config: loaded from {s}", .{path});
    } else if (config_path != null) {
        try writeAll(STDERR_FILENO, "Warning: could not load config from specified path, using defaults\n");
    } else if (load_result.error_type) |err| {
        if (load_result.path_searched) |path| {
            var buf: [512]u8 = undefined;
            const reason = switch (err) {
                .duplicate_key => "duplicate key in JSON (check for repeated keys in binds)",
                .invalid_json => "invalid JSON syntax",
                .read_failed => "could not read file",
                .not_found => "file not found",
            };
            const msg = std.fmt.bufPrint(&buf, "Warning: {s}: {s}, using defaults\n", .{ path, reason }) catch "Warning: config error\n";
            try writeAll(STDERR_FILENO, msg);
        }
    } else {
        logVerbose("config: using defaults (no config file found)", .{});
    }
    logDebug("config: leader={s} socket_dir={s} serve.port={d}", .{
        leaderToString(cfg.leader),
        cfg.socket_dir orelse "(default)",
        cfg.serve.port,
    });

    const cmd = args[arg_idx];
    const cmd_args = args[arg_idx + 1 ..];

    if (std.mem.eql(u8, cmd, "new")) {
        try cmdNew(alloc, cmd_args, &cfg);
    } else if (std.mem.eql(u8, cmd, "attach")) {
        try cmdAttach(alloc, cmd_args, &cfg);
    } else if (std.mem.eql(u8, cmd, "send")) {
        try cmdSend(alloc, cmd_args, &cfg);
    } else if (std.mem.eql(u8, cmd, "list")) {
        try cmdList(alloc, cmd_args, &cfg);
    } else if (std.mem.eql(u8, cmd, "clients")) {
        try cmdClients(alloc, cmd_args, &cfg);
    } else if (std.mem.eql(u8, cmd, "kick")) {
        try cmdKick(alloc, cmd_args, &cfg);
    } else if (std.mem.eql(u8, cmd, "kill")) {
        try cmdKill(alloc, cmd_args, &cfg);
    } else if (std.mem.eql(u8, cmd, "serve")) {
        try cmdServe(alloc, cmd_args, &cfg);
    } else if (std.mem.eql(u8, cmd, "otp")) {
        try cmdOtp(alloc, cmd_args);
    } else if (std.mem.eql(u8, cmd, "revoke")) {
        try cmdRevoke(alloc, cmd_args);
    } else if (std.mem.eql(u8, cmd, "print-config")) {
        try cmdPrintConfig(&cfg);
    } else if (std.mem.eql(u8, cmd, "-h") or std.mem.eql(u8, cmd, "--help")) {
        printUsage(alloc);
    } else {
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Unknown command: {s}\n", .{cmd}) catch "Unknown command\n";
        try writeAll(STDERR_FILENO, msg);
        printUsage(alloc);
        std.process.exit(1);
    }
}

const NewCmdArgs = struct {
    detach: bool,
    serve: bool,
    auto_name: bool,
    session_name: []const u8,
    cmd_args: []const []const u8,
};

fn parseCmdNewArgs(
    alloc: std.mem.Allocator,
    args: []const []const u8,
    cfg: *const config.Config,
    name_buf: *[64]u8,
) !NewCmdArgs {
    if (args.len < 1) {
        try writeAll(STDERR_FILENO, "Usage: vanish new [--detach] [--auto-name] [--serve] <name> <command> [args...]\n");
        std.process.exit(1);
    }

    var detach = false;
    var auto_name = false;
    var serve = false;
    var arg_idx: usize = 0;

    while (arg_idx < args.len) {
        if (std.mem.eql(u8, args[arg_idx], "--detach") or std.mem.eql(u8, args[arg_idx], "-d")) {
            detach = true;
            arg_idx += 1;
        } else if (std.mem.eql(u8, args[arg_idx], "--auto-name") or std.mem.eql(u8, args[arg_idx], "-a")) {
            auto_name = true;
            arg_idx += 1;
        } else if (std.mem.eql(u8, args[arg_idx], "--serve") or std.mem.eql(u8, args[arg_idx], "-s")) {
            serve = true;
            arg_idx += 1;
        } else {
            break;
        }
    }

    const min_args = if (auto_name) arg_idx + 1 else arg_idx + 2;
    if (args.len < min_args) {
        try writeAll(STDERR_FILENO, "Usage: vanish new [--detach] [--auto-name] [--serve] <name> <command> [args...]\n");
        std.process.exit(1);
    }

    const session_name = if (auto_name) blk: {
        var cmd_idx = arg_idx;
        if (cmd_idx < args.len and std.mem.eql(u8, args[cmd_idx], "--")) cmd_idx += 1;
        if (cmd_idx >= args.len) {
            try writeAll(STDERR_FILENO, "Missing command\n");
            std.process.exit(1);
        }
        const socket_dir = try paths.getDefaultSocketDir(alloc, cfg);
        defer alloc.free(socket_dir);
        break :blk naming.generateUnique(name_buf, args[cmd_idx], socket_dir);
    } else args[arg_idx];

    var cmd_start: usize = if (auto_name) arg_idx else arg_idx + 1;
    if (cmd_start < args.len and std.mem.eql(u8, args[cmd_start], "--")) {
        cmd_start += 1;
    }
    if (cmd_start >= args.len) {
        try writeAll(STDERR_FILENO, "Missing command\n");
        std.process.exit(1);
    }

    return .{
        .detach = detach,
        .serve = serve,
        .auto_name = auto_name,
        .session_name = session_name,
        .cmd_args = args[cmd_start..],
    };
}

fn forkSession(socket_path: []const u8, cmd_args: []const []const u8) !void {
    const pipe_fds = try posix.pipe();

    const pid = try posix.fork();
    if (pid == 0) {
        posix.close(pipe_fds[0]);
        daemonize();

        // Use C allocator in child (GPA is not fork-safe, page_allocator
        // has mremap issues after fork that cause ghostty-vt panics)
        const child_alloc = std.heap.c_allocator;

        const child_socket_path = child_alloc.dupe(u8, socket_path) catch std.process.exit(1);
        const child_cmd_args = child_alloc.alloc([]const u8, cmd_args.len) catch std.process.exit(1);
        for (cmd_args, 0..) |arg, i| {
            child_cmd_args[i] = child_alloc.dupe(u8, arg) catch std.process.exit(1);
        }

        Session.runWithNotify(child_alloc, child_socket_path, child_cmd_args, pipe_fds[1]) catch std.process.exit(1);
        std.process.exit(0);
    }

    posix.close(pipe_fds[1]);

    var buf: [1]u8 = undefined;
    const n = posix.read(pipe_fds[0], &buf) catch 0;
    posix.close(pipe_fds[0]);

    if (n == 0) {
        try writeAll(STDERR_FILENO, "Session failed to start\n");
        std.process.exit(1);
    }
}

fn cmdNew(alloc: std.mem.Allocator, args: []const []const u8, cfg: *const config.Config) !void {
    var name_buf: [64]u8 = undefined;
    const parsed = try parseCmdNewArgs(alloc, args, cfg, &name_buf);

    const socket_path = try paths.resolveSocketPath(alloc, parsed.session_name, cfg);
    defer alloc.free(socket_path);

    if (Session.isSocketLive(socket_path)) {
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Session '{s}' already exists\n", .{parsed.session_name}) catch "Session already exists\n";
        try writeAll(STDERR_FILENO, msg);
        std.process.exit(1);
    }

    try forkSession(socket_path, parsed.cmd_args);

    if (parsed.auto_name) {
        var msg_buf: [128]u8 = undefined;
        const msg = std.fmt.bufPrint(&msg_buf, "{s}\n", .{parsed.session_name}) catch parsed.session_name;
        try writeAll(STDERR_FILENO, msg);
    }

    if (parsed.serve or cfg.serve.auto_serve) {
        maybeStartServe(alloc, cfg);
    }

    if (!parsed.detach) {
        const Client = @import("client.zig");
        try Client.attach(alloc, socket_path, false, cfg);
    }
}

fn cmdAttach(alloc: std.mem.Allocator, args: []const []const u8, cfg: *const config.Config) !void {
    if (args.len < 1) {
        try writeAll(STDERR_FILENO, "Usage: vanish attach [--primary] <name>\n");
        std.process.exit(1);
    }

    var socket_arg: ?[]const u8 = null;
    var as_primary = false;

    for (args) |arg| {
        if (std.mem.eql(u8, arg, "--primary") or std.mem.eql(u8, arg, "-p")) {
            as_primary = true;
        } else if (std.mem.eql(u8, arg, "--viewer") or std.mem.eql(u8, arg, "-v")) {
            // Keep --viewer for backwards compatibility, but it's now the default
        } else if (socket_arg == null) {
            socket_arg = arg;
        }
    }

    if (socket_arg == null) {
        try writeAll(STDERR_FILENO, "Usage: vanish attach [--primary] <name>\n");
        std.process.exit(1);
    }

    const socket_path = try paths.resolveSocketPath(alloc, socket_arg.?, cfg);
    defer alloc.free(socket_path);

    const Client = @import("client.zig");
    try Client.attach(alloc, socket_path, !as_primary, cfg);
}

fn cmdSend(alloc: std.mem.Allocator, args: []const []const u8, cfg: *const config.Config) !void {
    if (args.len < 2) {
        try writeAll(STDERR_FILENO, "Usage: vanish send <name> <keys>\n");
        std.process.exit(1);
    }

    const socket_path = try paths.resolveSocketPath(alloc, args[0], cfg);
    defer alloc.free(socket_path);

    const keys = args[1];
    const Client = @import("client.zig");
    try Client.send(socket_path, keys);
}

fn cmdList(alloc: std.mem.Allocator, args: []const []const u8, cfg: *const config.Config) !void {
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
        break :blk paths.getDefaultSocketDir(alloc, cfg) catch {
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
                var path_buf: [std.fs.max_path_bytes]u8 = undefined;
                const socket_path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ dir_path, name }) catch continue;
                const live = Session.isSocketLive(socket_path);
                var buf: [std.fs.max_path_bytes]u8 = undefined;
                const display = if (explicit_dir != null) socket_path else name;
                const suffix: []const u8 = if (live) "\n" else " (stale)\n";
                const msg = std.fmt.bufPrint(&buf, "{s}{s}", .{ display, suffix }) catch continue;
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

        var path_buf: [std.fs.max_path_bytes]u8 = undefined;
        const socket_path = std.fmt.bufPrint(&path_buf, "{s}/{s}", .{ dir_path, name }) catch continue;
        const live = Session.isSocketLive(socket_path);

        try out.appendSlice(alloc, "{\"name\":\"");
        try paths.appendJsonEscaped(alloc, &out, name);
        try out.appendSlice(alloc, "\",\"path\":\"");
        try paths.appendJsonEscaped(alloc, &out, dir_path);
        try out.append(alloc, '/');
        try paths.appendJsonEscaped(alloc, &out, name);
        if (live) {
            try out.appendSlice(alloc, "\",\"live\":true}");
        } else {
            try out.appendSlice(alloc, "\",\"live\":false}");
        }
    }

    try out.appendSlice(alloc, "]}\n");
    try writeAll(STDOUT_FILENO, out.items);
}

fn cmdClients(alloc: std.mem.Allocator, args: []const []const u8, cfg: *const config.Config) !void {
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
        try writeAll(STDERR_FILENO, "Usage: vanish clients [--json] <name>\n");
        std.process.exit(1);
    }

    const socket_path = try paths.resolveSocketPath(alloc, socket_arg.?, cfg);
    defer alloc.free(socket_path);

    const sock = connectAsViewer(alloc, socket_path) catch |err| {
        const err_msg = if (err == error.ConnectionDenied) "Connection denied" else "Could not connect to session";
        if (as_json) {
            var buf: [128]u8 = undefined;
            const json = std.fmt.bufPrint(&buf, "{{\"error\":\"{s}\"}}\n", .{err_msg}) catch "{\"error\":\"Connection failed\"}\n";
            try writeAll(STDOUT_FILENO, json);
        } else {
            var buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "{s}\n", .{err_msg}) catch "Could not connect\n";
            try writeAll(STDERR_FILENO, msg);
        }
        std.process.exit(1);
    };
    defer posix.close(sock);

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

fn cmdKick(alloc: std.mem.Allocator, args: []const []const u8, cfg: *const config.Config) !void {
    if (args.len < 2) {
        try writeAll(STDERR_FILENO, "Usage: vanish kick <name> <client-id>\n");
        std.process.exit(1);
    }

    const socket_path = try paths.resolveSocketPath(alloc, args[0], cfg);
    defer alloc.free(socket_path);

    const client_id = std.fmt.parseInt(u32, args[1], 10) catch {
        try writeAll(STDERR_FILENO, "Invalid client ID\n");
        std.process.exit(1);
    };

    const sock = connectAsViewer(alloc, socket_path) catch |err| {
        const err_msg = if (err == error.ConnectionDenied) "Connection denied" else "Could not connect to session";
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "{s}\n", .{err_msg}) catch "Could not connect\n";
        try writeAll(STDERR_FILENO, msg);
        std.process.exit(1);
    };
    defer posix.close(sock);

    // Send kick request
    const kick = protocol.KickClient{ .id = client_id };
    try protocol.writeStruct(sock, @intFromEnum(protocol.ClientMsg.kick_client), kick);

    try writeAll(STDOUT_FILENO, "Kick request sent\n");
}

fn cmdKill(alloc: std.mem.Allocator, args: []const []const u8, cfg: *const config.Config) !void {
    if (args.len < 1) {
        try writeAll(STDERR_FILENO, "Usage: vanish kill <name>\n");
        std.process.exit(1);
    }

    const socket_path = try paths.resolveSocketPath(alloc, args[0], cfg);
    defer alloc.free(socket_path);

    const sock = connectAsViewer(alloc, socket_path) catch |err| {
        const err_msg = if (err == error.ConnectionDenied) "Connection denied" else "Could not connect to session";
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "{s}\n", .{err_msg}) catch "Could not connect\n";
        try writeAll(STDERR_FILENO, msg);
        std.process.exit(1);
    };
    defer posix.close(sock);

    // Send kill request
    try protocol.writeMsg(sock, @intFromEnum(protocol.ClientMsg.kill_session), &.{});

    try writeAll(STDOUT_FILENO, "Session terminated\n");
}

fn connectToSession(path: []const u8) !posix.socket_t {
    const sock = try posix.socket(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0);
    errdefer posix.close(sock);

    var addr = std.net.Address.initUnix(path) catch return error.PathTooLong;
    try posix.connect(sock, &addr.any, addr.getOsSockLen());

    return sock;
}

fn daemonize() void {
    _ = posix.setsid() catch {};
    posix.close(0);
    posix.close(1);
    posix.close(2);
    const devnull = posix.open("/dev/null", .{ .ACCMODE = .RDWR }, 0) catch std.process.exit(1);
    _ = posix.dup2(devnull, 0) catch {};
    _ = posix.dup2(devnull, 1) catch {};
    _ = posix.dup2(devnull, 2) catch {};
    if (devnull > 2) posix.close(devnull);
}

fn connectAsViewer(alloc: std.mem.Allocator, socket_path: []const u8) !posix.socket_t {
    const sock = try connectToSession(socket_path);
    errdefer posix.close(sock);

    var hello = protocol.Hello{ .role = .viewer, .cols = 80, .rows = 24 };
    hello.setTerm("xterm-256color");
    try protocol.writeStruct(sock, @intFromEnum(protocol.ClientMsg.hello), hello);

    const welcome_hdr = try protocol.readHeader(sock);
    if (welcome_hdr.msg_type == @intFromEnum(protocol.ServerMsg.denied)) {
        return error.ConnectionDenied;
    }
    var welcome_buf: [@sizeOf(protocol.Welcome)]u8 = undefined;
    try protocol.readExact(sock, &welcome_buf);

    // Skip full state if sent
    const state_hdr = try protocol.readHeader(sock);
    if (state_hdr.msg_type == @intFromEnum(protocol.ServerMsg.full)) {
        const skip = try alloc.alloc(u8, state_hdr.len);
        defer alloc.free(skip);
        protocol.readExact(sock, skip) catch {};
    }

    return sock;
}

fn maybeStartServe(alloc: std.mem.Allocator, cfg: *const config.Config) void {
    const port = cfg.serve.port;
    const bind_addr = cfg.serve.bind orelse "127.0.0.1";

    // Check if server is already running by trying to connect
    if (isPortListening(bind_addr, port)) {
        logVerbose("serve: HTTP server already running on {s}:{d}", .{ bind_addr, port });
        return;
    }

    // Fork a daemonized HTTP server
    const pid = posix.fork() catch |err| {
        logVerbose("serve: failed to fork HTTP server: {}", .{err});
        return;
    };

    if (pid != 0) {
        // Parent: server is starting
        logVerbose("serve: started HTTP server on {s}:{d}", .{ bind_addr, port });
        return;
    }

    daemonize();

    var server = HttpServer.init(alloc, cfg, bind_addr, port) catch std.process.exit(1);
    defer server.deinit();
    server.run() catch std.process.exit(1);
    std.process.exit(0);
}

fn isPortListening(addr: []const u8, port: u16) bool {
    // Try IPv4
    if (std.net.Address.parseIp4(addr, port)) |sa| {
        const sock = posix.socket(posix.AF.INET, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0) catch return false;
        defer posix.close(sock);
        posix.connect(sock, &sa.any, sa.getOsSockLen()) catch return false;
        return true;
    } else |_| {}

    // Try IPv6
    if (std.net.Address.parseIp6(addr, port)) |sa| {
        const sock = posix.socket(posix.AF.INET6, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0) catch return false;
        defer posix.close(sock);
        posix.connect(sock, &sa.any, sa.getOsSockLen()) catch return false;
        return true;
    } else |_| {}

    return false;
}

fn cmdServe(alloc: std.mem.Allocator, args: []const []const u8, cfg: *const config.Config) !void {
    var bind_addr: []const u8 = cfg.serve.bind orelse "127.0.0.1";
    var port: u16 = cfg.serve.port;
    var run_as_daemon = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "-b") or std.mem.eql(u8, arg, "--bind")) {
            i += 1;
            if (i >= args.len) {
                try writeAll(STDERR_FILENO, "Missing bind address\n");
                std.process.exit(1);
            }
            bind_addr = args[i];
        } else if (std.mem.eql(u8, arg, "-p") or std.mem.eql(u8, arg, "--port")) {
            i += 1;
            if (i >= args.len) {
                try writeAll(STDERR_FILENO, "Missing port\n");
                std.process.exit(1);
            }
            port = std.fmt.parseInt(u16, args[i], 10) catch {
                try writeAll(STDERR_FILENO, "Invalid port\n");
                std.process.exit(1);
            };
        } else if (std.mem.eql(u8, arg, "-d") or std.mem.eql(u8, arg, "--daemonize")) {
            run_as_daemon = true;
        }
    }

    if (run_as_daemon) {
        const pid = try posix.fork();
        if (pid != 0) {
            // Parent exits
            return;
        }

        daemonize();
    }

    var server = HttpServer.init(alloc, cfg, bind_addr, port) catch |err| {
        if (!run_as_daemon) {
            var buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Failed to initialize server: {}\n", .{err}) catch "Failed to initialize server\n";
            try writeAll(STDERR_FILENO, msg);
        }
        std.process.exit(1);
    };
    defer server.deinit();

    server.run() catch |err| {
        if (!run_as_daemon) {
            var buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Server error: {}\n", .{err}) catch "Server error\n";
            try writeAll(STDERR_FILENO, msg);
        }
        std.process.exit(1);
    };
}

fn cmdOtp(alloc: std.mem.Allocator, args: []const []const u8) !void {
    var scope: Auth.Scope = .indefinite;
    var session: ?[]const u8 = null;
    var duration: ?i64 = null;
    var read_only = false;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--duration")) {
            i += 1;
            if (i >= args.len) {
                try writeAll(STDERR_FILENO, "Missing duration value\n");
                std.process.exit(1);
            }
            duration = parseDuration(args[i]) orelse {
                try writeAll(STDERR_FILENO, "Invalid duration format (use e.g., 1h, 30m, 7d)\n");
                std.process.exit(1);
            };
            scope = .temporary;
        } else if (std.mem.eql(u8, arg, "--session")) {
            i += 1;
            if (i >= args.len) {
                try writeAll(STDERR_FILENO, "Missing session name\n");
                std.process.exit(1);
            }
            session = args[i];
            scope = .session;
        } else if (std.mem.eql(u8, arg, "--daemon")) {
            scope = .daemon;
        } else if (std.mem.eql(u8, arg, "--indefinite")) {
            scope = .indefinite;
        } else if (std.mem.eql(u8, arg, "--read-only")) {
            read_only = true;
        }
    }

    var auth = Auth.init(alloc) catch |err| {
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Failed to initialize auth: {}\n", .{err}) catch "Failed to initialize auth\n";
        try writeAll(STDERR_FILENO, msg);
        std.process.exit(1);
    };
    defer auth.deinit();

    const otp = auth.generateOtp(scope, session, duration, read_only) catch |err| {
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Failed to generate OTP: {}\n", .{err}) catch "Failed to generate OTP\n";
        try writeAll(STDERR_FILENO, msg);
        std.process.exit(1);
    };
    defer alloc.free(otp);

    try writeAll(STDOUT_FILENO, otp);
    try writeAll(STDOUT_FILENO, "\n");
}

fn cmdRevoke(alloc: std.mem.Allocator, args: []const []const u8) !void {
    var auth = Auth.init(alloc) catch |err| {
        var buf: [256]u8 = undefined;
        const msg = std.fmt.bufPrint(&buf, "Failed to initialize auth: {}\n", .{err}) catch "Failed to initialize auth\n";
        try writeAll(STDERR_FILENO, msg);
        std.process.exit(1);
    };
    defer auth.deinit();

    var revoke_all = false;
    var scope: ?Auth.Scope = null;
    var session: ?[]const u8 = null;

    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = args[i];
        if (std.mem.eql(u8, arg, "--all")) {
            revoke_all = true;
        } else if (std.mem.eql(u8, arg, "--temporary")) {
            scope = .temporary;
        } else if (std.mem.eql(u8, arg, "--daemon")) {
            scope = .daemon;
        } else if (std.mem.eql(u8, arg, "--indefinite")) {
            scope = .indefinite;
        } else if (std.mem.eql(u8, arg, "--session")) {
            i += 1;
            if (i >= args.len) {
                try writeAll(STDERR_FILENO, "Missing session name\n");
                std.process.exit(1);
            }
            session = args[i];
            scope = .session;
        }
    }

    if (revoke_all) {
        // Rotate all keys
        auth.rotateKey(.temporary, null) catch {};
        auth.rotateKey(.daemon, null) catch {};
        auth.rotateKey(.indefinite, null) catch {};
        // Revoke all OTPs
        auth.revokeOtps(null, null) catch {};
        try writeAll(STDOUT_FILENO, "All tokens revoked\n");
    } else if (scope) |s| {
        auth.rotateKey(s, session) catch |err| {
            var buf: [256]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Failed to revoke: {}\n", .{err}) catch "Failed to revoke\n";
            try writeAll(STDERR_FILENO, msg);
            std.process.exit(1);
        };
        auth.revokeOtps(s, session) catch {};
        try writeAll(STDOUT_FILENO, "Tokens revoked\n");
    } else {
        try writeAll(STDERR_FILENO, "Specify --all, --temporary, --daemon, --indefinite, or --session\n");
        std.process.exit(1);
    }
}

fn cmdPrintConfig(cfg: *const config.Config) !void {
    var buf: [4096]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    cfg.writeJson(stream.writer()) catch {
        try writeAll(STDERR_FILENO, "Failed to serialize config\n");
        std.process.exit(1);
    };
    try writeAll(STDOUT_FILENO, stream.getWritten());
}

fn parseDuration(s: []const u8) ?i64 {
    if (s.len < 2) return null;

    const unit = s[s.len - 1];
    const value_str = s[0 .. s.len - 1];
    const value = std.fmt.parseInt(i64, value_str, 10) catch return null;

    return switch (unit) {
        's' => value,
        'm' => value * 60,
        'h' => value * 3600,
        'd' => value * 86400,
        'w' => value * 604800,
        else => null,
    };
}

test "basic" {
    // Placeholder
}

test "parse duration" {
    try std.testing.expectEqual(@as(?i64, 60), parseDuration("1m"));
    try std.testing.expectEqual(@as(?i64, 3600), parseDuration("1h"));
    try std.testing.expectEqual(@as(?i64, 86400), parseDuration("1d"));
    try std.testing.expectEqual(@as(?i64, 604800), parseDuration("1w"));
    try std.testing.expectEqual(@as(?i64, null), parseDuration("invalid"));
}
