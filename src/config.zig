const std = @import("std");
const keybind = @import("keybind.zig");

pub const Config = struct {
    leader: u8 = 0x01, // Ctrl+A
    leader_ctrl: bool = true,
    socket_dir: ?[]const u8 = null,
    binds: []const keybind.Bind = &keybind.default_binds,

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
};

pub fn load(alloc: std.mem.Allocator) Config {
    const path = getConfigPath(alloc) orelse return .{};
    defer alloc.free(path);

    const file = std.fs.openFileAbsolute(path, .{}) catch return .{};
    defer file.close();

    const stat = file.stat() catch return .{};
    if (stat.size > 1024 * 1024) return .{}; // 1MB limit

    const content = file.readToEndAlloc(alloc, 1024 * 1024) catch return .{};
    defer alloc.free(content);

    return parse(alloc, content) catch .{};
}

fn getConfigPath(alloc: std.mem.Allocator) ?[]const u8 {
    if (std.posix.getenv("XDG_CONFIG_HOME")) |xdg| {
        return std.fmt.allocPrint(alloc, "{s}/vanish/config.json", .{xdg}) catch null;
    }
    if (std.posix.getenv("HOME")) |home| {
        return std.fmt.allocPrint(alloc, "{s}/.config/vanish/config.json", .{home}) catch null;
    }
    return null;
}

fn parse(alloc: std.mem.Allocator, content: []const u8) !Config {
    var arena = std.heap.ArenaAllocator.init(alloc);
    errdefer arena.deinit();
    const arena_alloc = arena.allocator();

    const parsed = std.json.parseFromSlice(std.json.Value, arena_alloc, content, .{}) catch return error.InvalidJson;
    const root = parsed.value;

    if (root != .object) return error.InvalidJson;

    var config = Config{ ._arena = arena };

    if (root.object.get("leader")) |leader_val| {
        if (parseLeader(leader_val)) |leader| {
            config.leader = leader.key;
            config.leader_ctrl = leader.ctrl;
        }
    }

    if (root.object.get("socket_dir")) |dir_val| {
        if (dir_val == .string) {
            config.socket_dir = try arena_alloc.dupe(u8, dir_val.string);
        }
    }

    if (root.object.get("binds")) |binds_val| {
        if (binds_val == .object) {
            if (parseBinds(arena_alloc, binds_val.object)) |binds| {
                config.binds = binds;
            }
        }
    }

    return config;
}

const LeaderKey = struct { key: u8, ctrl: bool };

fn parseLeader(val: std.json.Value) ?LeaderKey {
    if (val != .string) return null;
    const s = val.string;

    // "^A" or "Ctrl+A" format
    if (s.len == 2 and s[0] == '^') {
        const c = std.ascii.toLower(s[1]);
        if (c >= 'a' and c <= 'z') {
            return .{ .key = c - 'a' + 1, .ctrl = true };
        }
    }

    // "Ctrl+X" format
    if (s.len >= 6 and std.ascii.startsWithIgnoreCase(s, "ctrl+")) {
        const c = std.ascii.toLower(s[5]);
        if (c >= 'a' and c <= 'z') {
            return .{ .key = c - 'a' + 1, .ctrl = true };
        }
    }

    // Single character (no ctrl)
    if (s.len == 1) {
        return .{ .key = s[0], .ctrl = false };
    }

    return null;
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
        const c = std.ascii.toLower(s[1]);
        if (c >= 'a' and c <= 'z') {
            return .{ .key = c - 'a' + 1, .ctrl = true };
        }
    }
    if (s.len >= 6 and std.ascii.startsWithIgnoreCase(s, "ctrl+")) {
        const c = std.ascii.toLower(s[5]);
        if (c >= 'a' and c <= 'z') {
            return .{ .key = c - 'a' + 1, .ctrl = true };
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
    const result = parseLeader(.{ .string = "^B" }).?;
    try std.testing.expectEqual(@as(u8, 0x02), result.key);
    try std.testing.expect(result.ctrl);
}

test "parse leader Ctrl+B" {
    const result = parseLeader(.{ .string = "Ctrl+B" }).?;
    try std.testing.expectEqual(@as(u8, 0x02), result.key);
    try std.testing.expect(result.ctrl);
}

test "parse action" {
    try std.testing.expectEqual(keybind.Action.detach, parseAction("detach").?);
    try std.testing.expectEqual(keybind.Action.scroll_up, parseAction("pan_up").?);
    try std.testing.expect(parseAction("invalid") == null);
}
