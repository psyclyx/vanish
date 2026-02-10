const std = @import("std");

pub const Action = enum {
    detach,
    scrollback,
    scroll_up,
    scroll_down,
    scroll_left,
    scroll_right,
    scroll_page_up,
    scroll_page_down,
    scroll_top,
    scroll_bottom,
    toggle_status,
    takeover,
    help,
    cancel,
};

pub const Bind = struct {
    key: u8,
    ctrl: bool = false,
    action: Action,
    desc: []const u8,
};

pub const Config = struct {
    leader: u8 = 0x01, // Ctrl+A
    leader_ctrl: bool = true,
    binds: []const Bind = &default_binds,
};

pub const default_binds = [_]Bind{
    .{ .key = 'd', .action = .detach, .desc = "detach" },
    .{ .key = 0x01, .ctrl = true, .action = .detach, .desc = "detach" }, // Ctrl+A Ctrl+A
    .{ .key = '[', .action = .scrollback, .desc = "scrollback" },
    .{ .key = 'h', .action = .scroll_left, .desc = "pan left" },
    .{ .key = 'j', .action = .scroll_down, .desc = "pan down" },
    .{ .key = 'k', .action = .scroll_up, .desc = "pan up" },
    .{ .key = 'l', .action = .scroll_right, .desc = "pan right" },
    .{ .key = 'u', .ctrl = true, .action = .scroll_page_up, .desc = "page up" },
    .{ .key = 'd', .ctrl = true, .action = .scroll_page_down, .desc = "page down" },
    .{ .key = 'g', .action = .scroll_top, .desc = "top-left" },
    .{ .key = 'G', .action = .scroll_bottom, .desc = "bottom-right" },
    .{ .key = 's', .action = .toggle_status, .desc = "toggle status" },
    .{ .key = 't', .action = .takeover, .desc = "takeover" },
    .{ .key = '?', .action = .help, .desc = "help" },
    .{ .key = 0x1b, .action = .cancel, .desc = "cancel" }, // Escape
};

pub const State = struct {
    config: Config,
    in_leader: bool = false,
    show_status: bool = false,
    scroll_offset: i32 = 0,

    pub fn init(config: Config) State {
        return .{ .config = config };
    }

    pub fn isLeaderKey(self: *const State, byte: u8, is_ctrl: bool) bool {
        return byte == self.config.leader and is_ctrl == self.config.leader_ctrl;
    }

    pub fn leaderName(self: *const State) []const u8 {
        if (self.config.leader_ctrl and self.config.leader <= 26) {
            const names = [_][]const u8{ "^@", "^A", "^B", "^C", "^D", "^E", "^F", "^G", "^H", "^I", "^J", "^K", "^L", "^M", "^N", "^O", "^P", "^Q", "^R", "^S", "^T", "^U", "^V", "^W", "^X", "^Y", "^Z" };
            return names[self.config.leader];
        }
        return "?";
    }

    pub fn processKey(self: *State, byte: u8, is_ctrl: bool) ?Action {
        if (!self.in_leader) {
            if (self.isLeaderKey(byte, is_ctrl)) {
                self.in_leader = true;
                return null;
            }
            return null;
        }

        self.in_leader = false;

        for (self.config.binds) |bind| {
            if (bind.key == byte and bind.ctrl == is_ctrl) {
                return bind.action;
            }
        }

        return .cancel;
    }

    pub fn formatHint(self: *const State, buf: []u8) ![]const u8 {
        var fbs = std.io.fixedBufferStream(buf);
        const writer = fbs.writer();

        if (self.in_leader) {
            // Show curated bindings, not all. Pan binds omitted (shown in help).
            // Deduplicate by action - only show first bind per action.
            try writer.writeAll("\x1b[2m \xe2\x94\x80\x1b[0m "); // dim " ─ "
            var seen = [_]bool{false} ** @typeInfo(Action).@"enum".fields.len;
            var first = true;
            for (self.config.binds) |bind| {
                const idx = @intFromEnum(bind.action);
                if (isHintBind(bind.action) and !seen[idx]) {
                    seen[idx] = true;
                    if (!first) try writer.writeAll("\x1b[2m\xe2\x94\x82\x1b[0m"); // dim "│"
                    first = false;
                    if (bind.ctrl) {
                        try writer.print("\x1b[1m^{c}\x1b[22m {s} ", .{ bind.key + 'A' - 1, bind.desc });
                    } else {
                        try writer.print("\x1b[1m{c}\x1b[22m {s} ", .{ bind.key, bind.desc });
                    }
                }
            }
        }

        return fbs.getWritten();
    }

    fn isHintBind(action: Action) bool {
        return switch (action) {
            .detach, .toggle_status, .takeover, .help, .scrollback => true,
            else => false,
        };
    }
};

test "keybind basic" {
    var state = State.init(.{});

    try std.testing.expect(!state.in_leader);
    _ = state.processKey(0x01, true); // Ctrl+A
    try std.testing.expect(state.in_leader);

    const action = state.processKey('d', false);
    try std.testing.expect(action == .detach);
    try std.testing.expect(!state.in_leader);
}

test "keybind cancel" {
    var state = State.init(.{});

    _ = state.processKey(0x01, true);
    const action = state.processKey('x', false);
    try std.testing.expect(action == .cancel);
}

test "keybind escape cancels" {
    var state = State.init(.{});

    _ = state.processKey(0x01, true);
    try std.testing.expect(state.in_leader);

    const action = state.processKey(0x1b, false);
    try std.testing.expect(action == .cancel);
    try std.testing.expect(!state.in_leader);
}

test "keybind scroll actions" {
    var state = State.init(.{});

    _ = state.processKey(0x01, true);
    try std.testing.expect(state.processKey('k', false) == .scroll_up);

    _ = state.processKey(0x01, true);
    try std.testing.expect(state.processKey('j', false) == .scroll_down);

    _ = state.processKey(0x01, true);
    try std.testing.expect(state.processKey('g', false) == .scroll_top);

    _ = state.processKey(0x01, true);
    try std.testing.expect(state.processKey('G', false) == .scroll_bottom);
}

test "keybind hint format" {
    var state = State.init(.{});
    var buf: [512]u8 = undefined;

    const hint_before = try state.formatHint(&buf);
    try std.testing.expectEqual(@as(usize, 0), hint_before.len);

    _ = state.processKey(0x01, true);
    const hint_after = try state.formatHint(&buf);
    try std.testing.expect(hint_after.len > 0);
}

test "keybind takeover" {
    var state = State.init(.{});

    _ = state.processKey(0x01, true);
    try std.testing.expect(state.processKey('t', false) == .takeover);
}
