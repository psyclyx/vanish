const std = @import("std");
const keybind = @import("keybind.zig");

pub const ServeConfig = struct {
    bind: ?[]const u8 = null, // null means 127.0.0.1 + ::1
    port: u16 = 7890,
};

pub const Config = struct {
    leader: u8 = 0x01, // Ctrl+A
    leader_ctrl: bool = true,
    socket_dir: ?[]const u8 = null,
    binds: []const keybind.Bind = &keybind.default_binds,
    serve: ServeConfig = .{},

    // Owned memory from parsing
    _arena: ?std.heap.ArenaAllocator = null,

    pub fn deinit(self: *Config) void {
        if (self._arena) |*arena| {
            arena.deinit();
        }
    }

    pub fn toKeybindConfig(self: *const Config) keybind.Config {
        return .{
            .leader = self.leader,
            .leader_ctrl = self.leader_ctrl,
            .binds = self.binds,
        };
    }

    /// Write config as JSON to the provided writer
    pub fn writeJson(self: *const Config, writer: anytype) !void {
        try writer.writeAll("{\n");

        // Leader key
        try writer.writeAll("  \"leader\": \"");
        try writeKeyJson(writer, self.leader, self.leader_ctrl);
        try writer.writeAll("\",\n");

        // Socket dir
        try writer.writeAll("  \"socket_dir\": ");
        if (self.socket_dir) |dir| {
            try writer.writeByte('"');
            try writer.writeAll(dir);
            try writer.writeAll("\",\n");
        } else {
            try writer.writeAll("null,\n");
        }

        // Serve config
        try writer.writeAll("  \"serve\": {\n");
        try writer.writeAll("    \"bind\": ");
        if (self.serve.bind) |bind| {
            try writer.writeByte('"');
            try writer.writeAll(bind);
            try writer.writeAll("\",\n");
        } else {
            try writer.writeAll("null,\n");
        }
        try writer.print("    \"port\": {d}\n", .{self.serve.port});
        try writer.writeAll("  },\n");

        // Binds
        try writer.writeAll("  \"binds\": {\n");
        for (self.binds, 0..) |bind, i| {
            try writer.writeAll("    \"");
            try writeKeyJson(writer, bind.key, bind.ctrl);
            try writer.writeAll("\": \"");
            try writer.writeAll(actionToString(bind.action));
            try writer.writeByte('"');
            if (i < self.binds.len - 1) {
                try writer.writeByte(',');
            }
            try writer.writeByte('\n');
        }
        try writer.writeAll("  }\n");
        try writer.writeAll("}\n");
    }

    fn writeKeyJson(writer: anytype, key: u8, ctrl: bool) !void {
        if (ctrl) {
            // Ctrl+A through Ctrl+Z (0x01-0x1A)
            if (key >= 1 and key <= 26) {
                try writer.print("^{c}", .{'A' + key - 1});
                return;
            }
            // Special control characters
            switch (key) {
                0x00 => try writer.writeAll("^ "), // Ctrl+Space
                0x1B => try writer.writeAll("^["), // ESC
                0x1C => try writer.writeAll("^\\\\"), // Ctrl+\ (escaped for JSON)
                0x1D => try writer.writeAll("^]"),
                0x1E => try writer.writeAll("^^"),
                0x1F => try writer.writeAll("^_"),
                else => try writer.writeByte(key),
            }
        } else if (key == 0x1b) {
            try writer.writeAll("Escape");
        } else {
            try writer.writeByte(key);
        }
    }
};

fn actionToString(action: keybind.Action) []const u8 {
    return switch (action) {
        .detach => "detach",
        .scrollback => "scrollback",
        .scroll_up => "scroll_up",
        .scroll_down => "scroll_down",
        .scroll_left => "scroll_left",
        .scroll_right => "scroll_right",
        .scroll_page_up => "scroll_page_up",
        .scroll_page_down => "scroll_page_down",
        .scroll_top => "scroll_top",
        .scroll_bottom => "scroll_bottom",
        .toggle_status => "toggle_status",
        .takeover => "takeover",
        .help => "help",
        .cancel => "cancel",
    };
}

pub const LoadResult = struct {
    config: Config,
    path_used: ?[]const u8, // null if defaults, otherwise the path that was loaded
    path_searched: ?[]const u8, // the default path that would be searched
    error_type: ?LoadError = null, // set if file exists but failed to load
};

pub fn load(alloc: std.mem.Allocator, explicit_path: ?[]const u8) LoadResult {
    const default_path = getDefaultConfigPath(alloc);

    if (explicit_path) |path| {
        switch (loadFromPath(alloc, path)) {
            .ok => |cfg| return .{
                .config = cfg,
                .path_used = path,
                .path_searched = default_path,
            },
            .err => |e| return .{
                .config = .{},
                .path_used = null,
                .path_searched = default_path,
                .error_type = if (e == .not_found) null else e,
            },
        }
    }

    if (default_path) |path| {
        switch (loadFromPath(alloc, path)) {
            .ok => |cfg| return .{
                .config = cfg,
                .path_used = path,
                .path_searched = default_path,
            },
            .err => |e| return .{
                .config = .{},
                .path_used = null,
                .path_searched = default_path,
                .error_type = if (e == .not_found) null else e,
            },
        }
    }

    return .{
        .config = .{},
        .path_used = null,
        .path_searched = default_path,
    };
}

pub const LoadError = enum { not_found, read_failed, invalid_json, duplicate_key };
pub const ParseResult = union(enum) { ok: Config, err: LoadError };

pub fn loadFromPath(alloc: std.mem.Allocator, path: []const u8) ParseResult {
    const file = std.fs.openFileAbsolute(path, .{}) catch return .{ .err = .not_found };
    defer file.close();

    const stat = file.stat() catch return .{ .err = .read_failed };
    if (stat.size > 1024 * 1024) return .{ .err = .read_failed }; // 1MB limit

    const content = file.readToEndAlloc(alloc, 1024 * 1024) catch return .{ .err = .read_failed };
    defer alloc.free(content);

    return parse(alloc, content);
}

pub fn getDefaultConfigPath(alloc: std.mem.Allocator) ?[]const u8 {
    if (std.posix.getenv("XDG_CONFIG_HOME")) |xdg| {
        return std.fmt.allocPrint(alloc, "{s}/vanish/config.json", .{xdg}) catch null;
    }
    if (std.posix.getenv("HOME")) |home| {
        return std.fmt.allocPrint(alloc, "{s}/.config/vanish/config.json", .{home}) catch null;
    }
    return null;
}

fn parse(alloc: std.mem.Allocator, content: []const u8) ParseResult {
    var arena = std.heap.ArenaAllocator.init(alloc);
    const arena_alloc = arena.allocator();

    const parsed = std.json.parseFromSlice(std.json.Value, arena_alloc, content, .{}) catch |e| {
        arena.deinit();
        return .{ .err = if (e == error.DuplicateField) LoadError.duplicate_key else LoadError.invalid_json };
    };
    const root = parsed.value;

    if (root != .object) {
        arena.deinit();
        return .{ .err = .invalid_json };
    }

    var config = Config{ ._arena = arena };

    if (root.object.get("leader")) |leader_val| {
        if (parseLeader(leader_val)) |leader| {
            config.leader = leader.key;
            config.leader_ctrl = leader.ctrl;
        }
    }

    if (root.object.get("socket_dir")) |dir_val| {
        if (dir_val == .string) {
            config.socket_dir = arena_alloc.dupe(u8, dir_val.string) catch {
                config.deinit();
                return .{ .err = .invalid_json };
            };
        }
    }

    if (root.object.get("binds")) |binds_val| {
        if (binds_val == .object) {
            if (parseBinds(arena_alloc, binds_val.object)) |binds| {
                config.binds = binds;
            }
        }
    }

    if (root.object.get("serve")) |serve_val| {
        if (serve_val == .object) {
            if (serve_val.object.get("bind")) |bind_val| {
                if (bind_val == .string) {
                    config.serve.bind = arena_alloc.dupe(u8, bind_val.string) catch {
                        config.deinit();
                        return .{ .err = .invalid_json };
                    };
                }
            }
            if (serve_val.object.get("port")) |port_val| {
                if (port_val == .integer) {
                    const p = port_val.integer;
                    if (p > 0 and p <= 65535) {
                        config.serve.port = @intCast(p);
                    }
                }
            }
        }
    }

    return .{ .ok = config };
}

const LeaderKey = struct { key: u8, ctrl: bool };

fn parseLeader(val: std.json.Value) ?LeaderKey {
    if (val != .string) return null;
    return parseKeyString(val.string);
}

fn parseBinds(alloc: std.mem.Allocator, obj: std.json.ObjectMap) ?[]const keybind.Bind {
    var list: std.ArrayList(keybind.Bind) = .empty;

    var it = obj.iterator();
    while (it.next()) |entry| {
        const key_str = entry.key_ptr.*;
        const action_val = entry.value_ptr.*;

        if (action_val != .string) continue;

        const key_info = parseKeyString(key_str) orelse continue;
        const action = parseAction(action_val.string) orelse continue;
        const desc = actionDesc(action);

        list.append(alloc, .{
            .key = key_info.key,
            .ctrl = key_info.ctrl,
            .action = action,
            .desc = desc,
        }) catch continue;
    }

    if (list.items.len == 0) return null;
    return list.toOwnedSlice(alloc) catch null;
}

fn parseKeyString(s: []const u8) ?LeaderKey {
    if (s.len == 2 and s[0] == '^') {
        const c = s[1];
        const lower = std.ascii.toLower(c);
        if (lower >= 'a' and lower <= 'z') {
            return .{ .key = lower - 'a' + 1, .ctrl = true };
        }
        // Special control characters
        switch (c) {
            ' ' => return .{ .key = 0x00, .ctrl = true }, // Ctrl+Space
            '[' => return .{ .key = 0x1B, .ctrl = true },
            '\\' => return .{ .key = 0x1C, .ctrl = true },
            ']' => return .{ .key = 0x1D, .ctrl = true },
            '^' => return .{ .key = 0x1E, .ctrl = true },
            '_' => return .{ .key = 0x1F, .ctrl = true },
            else => {},
        }
    }
    if (s.len >= 6 and std.ascii.startsWithIgnoreCase(s, "ctrl+")) {
        const rest = s[5..];
        if (rest.len == 1) {
            const c = rest[0];
            const lower = std.ascii.toLower(c);
            if (lower >= 'a' and lower <= 'z') {
                return .{ .key = lower - 'a' + 1, .ctrl = true };
            }
            switch (c) {
                ' ' => return .{ .key = 0x00, .ctrl = true }, // Ctrl+Space
                '[' => return .{ .key = 0x1B, .ctrl = true },
                '\\' => return .{ .key = 0x1C, .ctrl = true },
                ']' => return .{ .key = 0x1D, .ctrl = true },
                '^' => return .{ .key = 0x1E, .ctrl = true },
                '_' => return .{ .key = 0x1F, .ctrl = true },
                else => {},
            }
        } else if (std.ascii.eqlIgnoreCase(rest, "space")) {
            return .{ .key = 0x00, .ctrl = true }; // Ctrl+Space
        }
    }
    if (s.len == 1) {
        return .{ .key = s[0], .ctrl = false };
    }
    if (std.mem.eql(u8, s, "Escape") or std.mem.eql(u8, s, "Esc")) {
        return .{ .key = 0x1b, .ctrl = false };
    }
    return null;
}

fn parseAction(s: []const u8) ?keybind.Action {
    const map = .{
        .{ "detach", keybind.Action.detach },
        .{ "scrollback", keybind.Action.scrollback },
        .{ "scroll_up", keybind.Action.scroll_up },
        .{ "scroll_down", keybind.Action.scroll_down },
        .{ "scroll_left", keybind.Action.scroll_left },
        .{ "scroll_right", keybind.Action.scroll_right },
        .{ "scroll_page_up", keybind.Action.scroll_page_up },
        .{ "scroll_page_down", keybind.Action.scroll_page_down },
        .{ "scroll_top", keybind.Action.scroll_top },
        .{ "scroll_bottom", keybind.Action.scroll_bottom },
        .{ "toggle_status", keybind.Action.toggle_status },
        .{ "takeover", keybind.Action.takeover },
        .{ "help", keybind.Action.help },
        .{ "cancel", keybind.Action.cancel },
        // Aliases
        .{ "pan_up", keybind.Action.scroll_up },
        .{ "pan_down", keybind.Action.scroll_down },
        .{ "pan_left", keybind.Action.scroll_left },
        .{ "pan_right", keybind.Action.scroll_right },
        .{ "page_up", keybind.Action.scroll_page_up },
        .{ "page_down", keybind.Action.scroll_page_down },
        .{ "top", keybind.Action.scroll_top },
        .{ "bottom", keybind.Action.scroll_bottom },
        .{ "status", keybind.Action.toggle_status },
    };

    inline for (map) |entry| {
        if (std.mem.eql(u8, s, entry[0])) return entry[1];
    }
    return null;
}

fn actionDesc(action: keybind.Action) []const u8 {
    return switch (action) {
        .detach => "detach",
        .scrollback => "scrollback",
        .scroll_up => "pan up",
        .scroll_down => "pan down",
        .scroll_left => "pan left",
        .scroll_right => "pan right",
        .scroll_page_up => "page up",
        .scroll_page_down => "page down",
        .scroll_top => "top-left",
        .scroll_bottom => "bottom-right",
        .toggle_status => "toggle status",
        .takeover => "takeover",
        .help => "help",
        .cancel => "cancel",
    };
}

test "parse leader ^B" {
    const result = parseKeyString("^B").?;
    try std.testing.expectEqual(@as(u8, 0x02), result.key);
    try std.testing.expect(result.ctrl);
}

test "parse leader Ctrl+B" {
    const result = parseKeyString("Ctrl+B").?;
    try std.testing.expectEqual(@as(u8, 0x02), result.key);
    try std.testing.expect(result.ctrl);
}

test "parse action" {
    try std.testing.expectEqual(keybind.Action.detach, parseAction("detach").?);
    try std.testing.expectEqual(keybind.Action.scroll_up, parseAction("pan_up").?);
    try std.testing.expect(parseAction("invalid") == null);
}

test "parse leader ^backslash" {
    const result = parseKeyString("^\\").?;
    try std.testing.expectEqual(@as(u8, 0x1C), result.key);
    try std.testing.expect(result.ctrl);
}

test "parse leader Ctrl+backslash" {
    const result = parseKeyString("Ctrl+\\").?;
    try std.testing.expectEqual(@as(u8, 0x1C), result.key);
    try std.testing.expect(result.ctrl);
}

test "parse leader ^space" {
    const result = parseKeyString("^ ").?;
    try std.testing.expectEqual(@as(u8, 0x00), result.key);
    try std.testing.expect(result.ctrl);
}

test "parse leader Ctrl+Space" {
    const result = parseKeyString("Ctrl+Space").?;
    try std.testing.expectEqual(@as(u8, 0x00), result.key);
    try std.testing.expect(result.ctrl);
}

test "writeKeyJson backslash" {
    var buf: [32]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try Config.writeKeyJson(fbs.writer(), 0x1C, true);
    try std.testing.expectEqualStrings("^\\\\", fbs.getWritten());
}

test "writeKeyJson space" {
    var buf: [32]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    try Config.writeKeyJson(fbs.writer(), 0x00, true);
    try std.testing.expectEqualStrings("^ ", fbs.getWritten());
}
