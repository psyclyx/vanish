const std = @import("std");
const ghostty_vt = @import("ghostty-vt");

const Terminal = ghostty_vt.Terminal;
const TerminalFormatter = ghostty_vt.formatter.TerminalFormatter;

pub const VTerminal = @This();

alloc: std.mem.Allocator,
term: Terminal,
cols: u16,
rows: u16,
/// Set to true when an ED 2 (clear screen) sequence is detected.
/// When true, scrollback from before the clear should not be shared.
screen_cleared: bool = false,

pub fn init(alloc: std.mem.Allocator, cols: u16, rows: u16) !VTerminal {
    const term = try Terminal.init(alloc, .{
        .cols = cols,
        .rows = rows,
        // Reduce scrollback to minimize memory allocation after fork
        // Default is 10,000 which causes excessive mremap calls
        .max_scrollback = 1000,
    });
    return .{
        .alloc = alloc,
        .term = term,
        .cols = cols,
        .rows = rows,
    };
}

pub fn deinit(self: *VTerminal) void {
    self.term.deinit(self.alloc);
}

pub fn resize(self: *VTerminal, cols: u16, rows: u16) !void {
    try self.term.resize(self.alloc, cols, rows);
    self.cols = cols;
    self.rows = rows;
}

pub fn feed(self: *VTerminal, data: []const u8) void {
    // Detect ED 2 (clear screen) sequence: ESC [ 2 J
    // This sets a flag to prevent sharing pre-clear scrollback
    if (std.mem.indexOf(u8, data, "\x1b[2J") != null or
        std.mem.indexOf(u8, data, "\x1b[3J") != null)
    {
        self.screen_cleared = true;
    }

    var stream = self.term.vtStream();
    defer stream.deinit();
    stream.nextSlice(data) catch {};
}

pub fn getPlainText(self: *VTerminal) ![]const u8 {
    return try self.term.plainString(self.alloc);
}

pub fn getCursor(self: *VTerminal) struct { x: u16, y: u16 } {
    const c = self.term.screens.active.cursor;
    return .{ .x = c.x, .y = c.y };
}

pub fn dumpScreen(self: *VTerminal, alloc: std.mem.Allocator) ![]u8 {
    var formatter: TerminalFormatter = .init(&self.term, .{
        .emit = .vt,
        .palette = &self.term.colors.palette.current,
    });
    formatter.extra.screen.cursor = true;

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(alloc);

    const writer = output.writer(alloc);
    try std.fmt.format(writer, "{f}", .{formatter});

    return output.toOwnedSlice(alloc);
}

pub fn dumpViewport(
    self: *VTerminal,
    alloc: std.mem.Allocator,
    offset_x: u16,
    offset_y: u16,
    view_cols: u16,
    view_rows: u16,
) ![]u8 {
    const screen = self.term.screens.active;

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(alloc);

    const writer = output.writer(alloc);

    // Clear screen and reset cursor
    try writer.writeAll("\x1b[2J\x1b[H");

    // Calculate visible region bounds
    const end_x: u16 = @min(offset_x + view_cols, self.cols);
    const end_y: u16 = @min(offset_y + view_rows, self.rows);

    // Render each visible row
    var out_row: u16 = 1;
    var y = offset_y;
    while (y < end_y) : (y += 1) {
        const pt = ghostty_vt.point.Point{ .active = .{ .x = 0, .y = y } };
        var row_pin = screen.pages.pin(pt) orelse continue;

        // Move cursor to output row
        try std.fmt.format(writer, "\x1b[{d};1H", .{out_row});

        // Get all cells in this row
        const all_cells = row_pin.cells(.all);

        // Render cells in the visible column range
        var last_style: ?ghostty_vt.Style = null;
        var x = offset_x;
        while (x < end_x) : (x += 1) {
            if (x >= all_cells.len) {
                try writer.writeByte(' ');
                continue;
            }
            const cell = &all_cells[x];

            // Update pin x for style lookup
            row_pin.x = x;

            // Apply cell styling if changed
            const cell_style = row_pin.style(cell);
            if (last_style == null or !stylesEqual(last_style.?, cell_style)) {
                try writeStyle(writer, cell_style);
                last_style = cell_style;
            }

            try writeCell(writer, cell, &row_pin);
        }

        // Reset style at end of each row
        try writer.writeAll("\x1b[0m");
        out_row += 1;
    }

    // Position cursor within the visible viewport
    const cursor = screen.cursor;
    if (cursor.x >= offset_x and cursor.x < end_x and
        cursor.y >= offset_y and cursor.y < end_y)
    {
        const cx = cursor.x - offset_x + 1;
        const cy = cursor.y - offset_y + 1;
        try std.fmt.format(writer, "\x1b[{d};{d}H", .{ cy, cx });
    }

    return output.toOwnedSlice(alloc);
}

fn stylesEqual(a: ghostty_vt.Style, b: ghostty_vt.Style) bool {
    return a.flags.bold == b.flags.bold and
        a.flags.italic == b.flags.italic and
        a.flags.underline == b.flags.underline and
        a.fg_color.eql(b.fg_color) and
        a.bg_color.eql(b.bg_color);
}

fn writeCell(writer: anytype, cell: anytype, row_pin: anytype) !void {
    switch (cell.content_tag) {
        .codepoint => {
            const cp = cell.content.codepoint;
            if (cp >= 0x20) {
                try writeCodepoint(writer, cp);
            } else {
                try writer.writeByte(' ');
            }
        },
        .codepoint_grapheme => {
            if (row_pin.grapheme(cell)) |cps| {
                const first_cp = cell.content.codepoint;
                if (first_cp >= 0x20) try writeCodepoint(writer, first_cp);
                for (cps) |cp| try writeCodepoint(writer, cp);
            } else {
                try writer.writeByte(' ');
            }
        },
        else => try writer.writeByte(' '),
    }
}

fn writeCodepoint(writer: anytype, cp: u21) !void {
    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(cp, &buf) catch return;
    try writer.writeAll(buf[0..len]);
}

fn writeStyle(writer: anytype, s: ghostty_vt.Style) !void {
    try writer.writeAll("\x1b[0m"); // reset first

    if (s.flags.bold) try writer.writeAll("\x1b[1m");
    if (s.flags.italic) try writer.writeAll("\x1b[3m");
    if (s.flags.underline != .none) try writer.writeAll("\x1b[4m");

    // Foreground color
    switch (s.fg_color) {
        .none => {},
        .palette => |idx| try std.fmt.format(writer, "\x1b[38;5;{d}m", .{idx}),
        .rgb => |rgb| try std.fmt.format(writer, "\x1b[38;2;{d};{d};{d}m", .{ rgb.r, rgb.g, rgb.b }),
    }

    // Background color
    switch (s.bg_color) {
        .none => {},
        .palette => |idx| try std.fmt.format(writer, "\x1b[48;5;{d}m", .{idx}),
        .rgb => |rgb| try std.fmt.format(writer, "\x1b[48;2;{d};{d};{d}m", .{ rgb.r, rgb.g, rgb.b }),
    }
}

pub fn dumpScrollback(self: *VTerminal, alloc: std.mem.Allocator) ![]u8 {
    const screen = self.term.screens.active;

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(alloc);

    const tl = screen.pages.getTopLeft(.screen);
    const br = screen.pages.getBottomRight(.screen);

    if (br) |bottom| {
        const sel = ghostty_vt.Selection.init(tl, bottom, false);

        const formatter: ghostty_vt.formatter.ScreenFormatter = .{
            .screen = screen,
            .opts = .{ .emit = .plain, .unwrap = true },
            .content = .{ .selection = sel },
            .extra = .none,
            .pin_map = null,
        };

        const writer = output.writer(alloc);
        try std.fmt.format(writer, "{f}", .{formatter});
    }

    return output.toOwnedSlice(alloc);
}

test "terminal basic" {
    const alloc = std.testing.allocator;
    var term = try init(alloc, 80, 24);
    defer term.deinit();

    term.feed("Hello, World!");
    const text = try term.getPlainText();
    defer alloc.free(@constCast(text));

    try std.testing.expect(std.mem.indexOf(u8, text, "Hello, World!") != null);
}

test "terminal dump screen" {
    const alloc = std.testing.allocator;
    var term = try init(alloc, 80, 24);
    defer term.deinit();

    term.feed("\x1b[31mRed Text\x1b[0m");
    const screen = try term.dumpScreen(alloc);
    defer alloc.free(screen);

    try std.testing.expect(screen.len > 0);
}

test "terminal resize" {
    const alloc = std.testing.allocator;
    var term = try init(alloc, 80, 24);
    defer term.deinit();

    try term.resize(120, 40);
    try std.testing.expectEqual(@as(u16, 120), term.cols);
    try std.testing.expectEqual(@as(u16, 40), term.rows);
}

test "terminal scrollback" {
    const alloc = std.testing.allocator;
    var term = try init(alloc, 80, 24);
    defer term.deinit();

    term.feed("Line 1\n");
    term.feed("Line 2\n");
    const scrollback = try term.dumpScrollback(alloc);
    defer alloc.free(scrollback);

    try std.testing.expect(scrollback.len > 0);
}

test "terminal viewport dump" {
    const alloc = std.testing.allocator;
    var term = try init(alloc, 120, 50);
    defer term.deinit();

    // Fill some content
    term.feed("AAAA\x1b[2;1HBBBB\x1b[3;1HCCCC");

    // Dump a viewport from (0,0) with size 80x24
    const viewport = try term.dumpViewport(alloc, 0, 0, 80, 24);
    defer alloc.free(viewport);

    try std.testing.expect(viewport.len > 0);
    // Should contain our text
    try std.testing.expect(std.mem.indexOf(u8, viewport, "AAAA") != null);
}

test "terminal zsh prompt sequence" {
    const alloc = std.testing.allocator;
    var term = try init(alloc, 80, 24);
    defer term.deinit();

    // Exact sequence from zsh prompt that was causing issues
    term.feed("\x1b[0m\x1b[27m\x1b[24m\x1b[J\x1b[34m~proj/vanish");

    // If we get here without panicking, the test passed
    const text = try term.getPlainText();
    defer alloc.free(@constCast(text));

    try std.testing.expect(std.mem.indexOf(u8, text, "~proj/vanish") != null);
}

test "terminal clear screen detection" {
    const alloc = std.testing.allocator;
    var term = try init(alloc, 80, 24);
    defer term.deinit();

    // Initially not cleared
    try std.testing.expect(!term.screen_cleared);

    // Regular output doesn't set cleared
    term.feed("Hello\n");
    try std.testing.expect(!term.screen_cleared);

    // ED 2 (clear screen) sets the flag
    term.feed("\x1b[2J");
    try std.testing.expect(term.screen_cleared);
}

test "terminal clear scrollback detection" {
    const alloc = std.testing.allocator;
    var term = try init(alloc, 80, 24);
    defer term.deinit();

    // ED 3 (clear screen + scrollback) also sets the flag
    term.feed("\x1b[3J");
    try std.testing.expect(term.screen_cleared);
}
