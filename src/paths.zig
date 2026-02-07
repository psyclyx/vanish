const std = @import("std");
const config = @import("config.zig");

pub fn getDefaultSocketDir(alloc: std.mem.Allocator, cfg: *const config.Config) ![]const u8 {
    if (cfg.socket_dir) |dir| {
        return try alloc.dupe(u8, dir);
    }
    if (std.posix.getenv("XDG_RUNTIME_DIR")) |xdg| {
        return try std.fmt.allocPrint(alloc, "{s}/vanish", .{xdg});
    }
    const uid = std.os.linux.getuid();
    return try std.fmt.allocPrint(alloc, "/tmp/vanish-{d}", .{uid});
}

pub fn resolveSocketPath(alloc: std.mem.Allocator, name_or_path: []const u8, cfg: *const config.Config) ![]const u8 {
    if (std.mem.indexOf(u8, name_or_path, "/") != null) {
        return try alloc.dupe(u8, name_or_path);
    }
    const dir = try getDefaultSocketDir(alloc, cfg);
    defer alloc.free(dir);
    return try std.fmt.allocPrint(alloc, "{s}/{s}", .{ dir, name_or_path });
}

pub fn appendJsonEscaped(alloc: std.mem.Allocator, list: *std.ArrayList(u8), s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try list.appendSlice(alloc, "\\\""),
            '\\' => try list.appendSlice(alloc, "\\\\"),
            '\n' => try list.appendSlice(alloc, "\\n"),
            '\r' => try list.appendSlice(alloc, "\\r"),
            '\t' => try list.appendSlice(alloc, "\\t"),
            else => {
                if (c < 0x20) {
                    var buf: [6]u8 = undefined;
                    _ = std.fmt.bufPrint(&buf, "\\u{x:0>4}", .{c}) catch continue;
                    try list.appendSlice(alloc, &buf);
                } else {
                    try list.append(alloc, c);
                }
            },
        }
    }
}
