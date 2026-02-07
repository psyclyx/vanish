const std = @import("std");
const ghostty_vt = @import("ghostty-vt");

const Terminal = ghostty_vt.Terminal;
const TerminalFormatter = ghostty_vt.formatter.TerminalFormatter;

pub const VTerminal = @This();

alloc: std.mem.Allocator,
term: Terminal,
cols: u16,
rows: u16,

pub fn init(alloc: std.mem.Allocator, cols: u16, rows: u16) !VTerminal {
    const term = try Terminal.init(alloc, .{
        .cols = cols,
        .rows = rows,
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
    var stream = self.term.vtStream();
    defer stream.deinit();
    stream.nextSlice(data) catch {};
}

pub fn getPlainText(self: *VTerminal) ![]const u8 {
    return try self.term.plainString(self.alloc);
}

pub fn dumpScreen(self: *VTerminal, alloc: std.mem.Allocator) ![]u8 {
    const formatter: TerminalFormatter = .init(&self.term, .{
        .emit = .vt,
        .palette = &self.term.colors.palette.current,
    });

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(alloc);

    const writer = output.writer(alloc);
    try std.fmt.format(writer, "{f}", .{formatter});

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
