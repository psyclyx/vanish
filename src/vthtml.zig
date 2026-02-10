const std = @import("std");
const ghostty_vt = @import("ghostty-vt");
const VTerminal = @import("terminal.zig");
const paths = @import("paths.zig");

/// Represents the rendered state of a single cell
pub const Cell = struct {
    /// UTF-8 encoded character (up to 4 bytes)
    char: [4]u8 = .{ ' ', 0, 0, 0 },
    char_len: u3 = 1,
    /// Style encoded as flags + colors
    bold: bool = false,
    italic: bool = false,
    underline: bool = false,
    inverse: bool = false,
    fg: Color = .{ .none = {} },
    bg: Color = .{ .none = {} },

    pub const Color = union(enum) {
        none,
        palette: u8,
        rgb: struct { r: u8, g: u8, b: u8 },
    };

    fn eql(self: Cell, other: Cell) bool {
        if (self.char_len != other.char_len) return false;
        for (0..self.char_len) |i| {
            if (self.char[i] != other.char[i]) return false;
        }
        if (self.bold != other.bold) return false;
        if (self.italic != other.italic) return false;
        if (self.underline != other.underline) return false;
        if (self.inverse != other.inverse) return false;
        if (!colorEql(self.fg, other.fg)) return false;
        if (!colorEql(self.bg, other.bg)) return false;
        return true;
    }

    fn colorEql(a: Color, b: Color) bool {
        return switch (a) {
            .none => b == .none,
            .palette => |ai| switch (b) {
                .palette => |bi| ai == bi,
                else => false,
            },
            .rgb => |ar| switch (b) {
                .rgb => |br| ar.r == br.r and ar.g == br.g and ar.b == br.b,
                else => false,
            },
        };
    }
};

/// A buffer storing the last-sent screen state for delta computation
pub const ScreenBuffer = struct {
    cells: []Cell,
    cols: u16,
    rows: u16,
    alloc: std.mem.Allocator,

    pub fn init(alloc: std.mem.Allocator, cols: u16, rows: u16) !ScreenBuffer {
        const cells = try alloc.alloc(Cell, @as(usize, cols) * rows);
        @memset(cells, Cell{});
        return .{
            .cells = cells,
            .cols = cols,
            .rows = rows,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *ScreenBuffer) void {
        self.alloc.free(self.cells);
    }

    pub fn resize(self: *ScreenBuffer, cols: u16, rows: u16) !void {
        self.alloc.free(self.cells);
        self.cells = try self.alloc.alloc(Cell, @as(usize, cols) * rows);
        @memset(self.cells, Cell{});
        self.cols = cols;
        self.rows = rows;
    }

    fn getCell(self: *ScreenBuffer, x: u16, y: u16) *Cell {
        return &self.cells[@as(usize, y) * self.cols + x];
    }

    /// Copy current VTerminal state to buffer, return list of changed positions
    pub fn updateFromVTerm(self: *ScreenBuffer, vterm: *VTerminal) ![]CellUpdate {
        var updates: std.ArrayList(CellUpdate) = .empty;
        errdefer updates.deinit(self.alloc);

        const screen = vterm.term.screens.active;

        var y: u16 = 0;
        while (y < self.rows and y < vterm.rows) : (y += 1) {
            const pt = ghostty_vt.point.Point{ .active = .{ .x = 0, .y = y } };
            var row_pin = screen.pages.pin(pt) orelse continue;
            const all_cells = row_pin.cells(.all);

            var x: u16 = 0;
            while (x < self.cols and x < vterm.cols) : (x += 1) {
                const new_cell = if (x < all_cells.len) blk: {
                    const vtcell = &all_cells[x];
                    row_pin.x = x;
                    break :blk cellFromVT(vtcell, row_pin);
                } else Cell{};

                const buf_cell = self.getCell(x, y);
                if (!buf_cell.eql(new_cell)) {
                    try updates.append(self.alloc, .{
                        .x = x,
                        .y = y,
                        .cell = new_cell,
                    });
                    buf_cell.* = new_cell;
                }
            }
        }

        return updates.toOwnedSlice(self.alloc);
    }

    /// Get full screen as updates (for keyframes)
    pub fn fullScreen(self: *ScreenBuffer, vterm: *VTerminal) ![]CellUpdate {
        var updates: std.ArrayList(CellUpdate) = .empty;
        errdefer updates.deinit(self.alloc);

        const screen = vterm.term.screens.active;

        var y: u16 = 0;
        while (y < self.rows and y < vterm.rows) : (y += 1) {
            const pt = ghostty_vt.point.Point{ .active = .{ .x = 0, .y = y } };
            var row_pin = screen.pages.pin(pt) orelse continue;
            const all_cells = row_pin.cells(.all);

            var x: u16 = 0;
            while (x < self.cols and x < vterm.cols) : (x += 1) {
                const new_cell = if (x < all_cells.len) blk: {
                    const vtcell = &all_cells[x];
                    row_pin.x = x;
                    break :blk cellFromVT(vtcell, row_pin);
                } else Cell{};

                try updates.append(self.alloc, .{
                    .x = x,
                    .y = y,
                    .cell = new_cell,
                });
                self.getCell(x, y).* = new_cell;
            }
        }

        return updates.toOwnedSlice(self.alloc);
    }
};

pub const CellUpdate = struct {
    x: u16,
    y: u16,
    cell: Cell,
};

fn cellFromVT(vtcell: *const ghostty_vt.Cell, row_pin: anytype) Cell {
    var cell = Cell{};

    // Extract character
    switch (vtcell.content_tag) {
        .codepoint => {
            const cp = vtcell.content.codepoint;
            if (cp >= 0x20) {
                cell.char_len = @intCast(std.unicode.utf8Encode(cp, &cell.char) catch 1);
            }
        },
        .codepoint_grapheme => {
            const cp = vtcell.content.codepoint;
            if (cp >= 0x20) {
                cell.char_len = @intCast(std.unicode.utf8Encode(cp, &cell.char) catch 1);
            }
            // Note: we only capture the base codepoint, not combining chars
            // This is a simplification - full grapheme support would need more storage
        },
        else => {},
    }

    // Extract style
    const style = row_pin.style(vtcell);
    cell.bold = style.flags.bold;
    cell.italic = style.flags.italic;
    cell.underline = style.flags.underline != .none;
    cell.inverse = style.flags.inverse;

    cell.fg = switch (style.fg_color) {
        .none => .{ .none = {} },
        .palette => |idx| .{ .palette = idx },
        .rgb => |rgb| .{ .rgb = .{ .r = rgb.r, .g = rgb.g, .b = rgb.b } },
    };
    cell.bg = switch (style.bg_color) {
        .none => .{ .none = {} },
        .palette => |idx| .{ .palette = idx },
        .rgb => |rgb| .{ .rgb = .{ .r = rgb.r, .g = rgb.g, .b = rgb.b } },
    };

    return cell;
}

/// Append CSS style string for a cell to the writer
fn appendCellStyle(alloc: std.mem.Allocator, out: *std.ArrayList(u8), cell: Cell) !void {
    if (cell.bold) try out.appendSlice(alloc, "font-weight:bold;");
    if (cell.italic) try out.appendSlice(alloc, "font-style:italic;");
    if (cell.underline) try out.appendSlice(alloc, "text-decoration:underline;");
    if (cell.inverse) try out.appendSlice(alloc, "filter:invert(1);");

    switch (cell.fg) {
        .none => {},
        .palette => |idx| {
            try out.appendSlice(alloc, "color:");
            try out.appendSlice(alloc, &color256ToHex(idx));
            try out.append(alloc, ';');
        },
        .rgb => |rgb| {
            var buf: [24]u8 = undefined;
            const s = std.fmt.bufPrint(&buf, "color:#{x:0>2}{x:0>2}{x:0>2};", .{ rgb.r, rgb.g, rgb.b }) catch "";
            try out.appendSlice(alloc, s);
        },
    }

    switch (cell.bg) {
        .none => {},
        .palette => |idx| {
            try out.appendSlice(alloc, "background:");
            try out.appendSlice(alloc, &color256ToHex(idx));
            try out.append(alloc, ';');
        },
        .rgb => |rgb| {
            var buf: [30]u8 = undefined;
            const s = std.fmt.bufPrint(&buf, "background:#{x:0>2}{x:0>2}{x:0>2};", .{ rgb.r, rgb.g, rgb.b }) catch "";
            try out.appendSlice(alloc, s);
        },
    }
}

fn cellHasStyle(cell: Cell) bool {
    return cell.bold or cell.italic or cell.underline or
        cell.inverse or cell.fg != .none or cell.bg != .none;
}

/// Render multiple updates to a JSON array of structured cell objects
pub fn updatesToJson(alloc: std.mem.Allocator, updates: []const CellUpdate, cols: u16, rows: u16, cursor_x: u16, cursor_y: u16) ![]u8 {
    var json: std.ArrayList(u8) = .empty;
    errdefer json.deinit(alloc);

    try json.appendSlice(alloc, "{\"cols\":");
    try std.fmt.format(json.writer(alloc), "{d}", .{cols});
    try json.appendSlice(alloc, ",\"rows\":");
    try std.fmt.format(json.writer(alloc), "{d}", .{rows});
    try json.appendSlice(alloc, ",\"cx\":");
    try std.fmt.format(json.writer(alloc), "{d}", .{cursor_x});
    try json.appendSlice(alloc, ",\"cy\":");
    try std.fmt.format(json.writer(alloc), "{d}", .{cursor_y});
    try json.appendSlice(alloc, ",\"cells\":[");

    var first = true;
    for (updates) |update| {
        if (!first) try json.append(alloc, ',');
        first = false;

        try json.appendSlice(alloc, "{\"x\":");
        try std.fmt.format(json.writer(alloc), "{d}", .{update.x});
        try json.appendSlice(alloc, ",\"y\":");
        try std.fmt.format(json.writer(alloc), "{d}", .{update.y});

        // Character (JSON-escaped)
        try json.appendSlice(alloc, ",\"c\":\"");
        try paths.appendJsonEscaped(alloc, &json, update.cell.char[0..update.cell.char_len]);
        try json.append(alloc, '"');

        // Style (only if non-empty)
        if (cellHasStyle(update.cell)) {
            try json.appendSlice(alloc, ",\"s\":\"");
            try appendCellStyle(alloc, &json, update.cell);
            try json.append(alloc, '"');
        }

        try json.append(alloc, '}');
    }

    try json.appendSlice(alloc, "]}");
    return json.toOwnedSlice(alloc);
}

/// Convert 256-color index to hex color
fn color256ToHex(idx: u8) [7]u8 {
    const standard = [16][7]u8{
        "#000000".*, "#800000".*, "#008000".*, "#808000".*,
        "#000080".*, "#800080".*, "#008080".*, "#c0c0c0".*,
        "#808080".*, "#ff0000".*, "#00ff00".*, "#ffff00".*,
        "#0000ff".*, "#ff00ff".*, "#00ffff".*, "#ffffff".*,
    };

    if (idx < 16) return standard[idx];

    if (idx < 232) {
        const i = idx - 16;
        const r: u8 = @intCast((i / 36) * 51);
        const g: u8 = @intCast(((i / 6) % 6) * 51);
        const b: u8 = @intCast((i % 6) * 51);
        var buf: [7]u8 = undefined;
        _ = std.fmt.bufPrint(&buf, "#{x:0>2}{x:0>2}{x:0>2}", .{ r, g, b }) catch return "#000000".*;
        return buf;
    }

    const gray: u8 = @intCast((idx - 232) * 10 + 8);
    var buf: [7]u8 = undefined;
    _ = std.fmt.bufPrint(&buf, "#{x:0>2}{x:0>2}{x:0>2}", .{ gray, gray, gray }) catch return "#000000".*;
    return buf;
}

test "cell equality" {
    const a = Cell{};
    const b = Cell{};
    try std.testing.expect(a.eql(b));

    var c = Cell{};
    c.bold = true;
    try std.testing.expect(!a.eql(c));
}

test "cell to json" {
    const alloc = std.testing.allocator;

    const updates = [_]CellUpdate{.{
        .x = 5,
        .y = 10,
        .cell = .{
            .char = .{ 'A', 0, 0, 0 },
            .char_len = 1,
            .bold = true,
            .fg = .{ .palette = 1 }, // red
        },
    }};

    const json = try updatesToJson(alloc, &updates, 80, 24, 5, 10);
    defer alloc.free(json);

    try std.testing.expect(std.mem.indexOf(u8, json, "\"x\":5") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"y\":10") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "\"c\":\"A\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, json, "font-weight:bold") != null);
}

test "screen buffer init" {
    const alloc = std.testing.allocator;
    var buf = try ScreenBuffer.init(alloc, 80, 24);
    defer buf.deinit();

    try std.testing.expectEqual(@as(u16, 80), buf.cols);
    try std.testing.expectEqual(@as(u16, 24), buf.rows);
}
