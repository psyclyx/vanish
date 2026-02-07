const std = @import("std");
const posix = std.posix;

pub const Role = enum(u8) {
    primary = 0,
    viewer = 1,
};

pub const ClientMsg = enum(u8) {
    hello = 0x01,
    input = 0x02,
    resize = 0x03,
    detach = 0x04,
    scrollback = 0x05,
    takeover = 0x06,
    list_clients = 0x07,
    kick_client = 0x08,
};

pub const ServerMsg = enum(u8) {
    welcome = 0x81,
    output = 0x82,
    full = 0x83,
    exit = 0x84,
    denied = 0x85,
    role_change = 0x86,
    session_resize = 0x87,
    client_list = 0x88,
};

pub const DenyReason = enum(u8) {
    primary_exists = 0,
    invalid_hello = 1,
};

pub const Hello = extern struct {
    role: Role,
    cols: u16,
    rows: u16,
    term: [64]u8 = std.mem.zeroes([64]u8),

    pub fn setTerm(self: *Hello, term: []const u8) void {
        const len = @min(term.len, self.term.len - 1);
        @memcpy(self.term[0..len], term[0..len]);
        self.term[len] = 0;
    }

    pub fn getTerm(self: *const Hello) []const u8 {
        const end = std.mem.indexOfScalar(u8, &self.term, 0) orelse self.term.len;
        return self.term[0..end];
    }
};

pub const Welcome = extern struct {
    role: Role,
    session_id: [16]u8,
    session_cols: u16,
    session_rows: u16,
};

pub const Resize = extern struct {
    cols: u16,
    rows: u16,
};

pub const Exit = extern struct {
    code: i32,
};

pub const Denied = extern struct {
    reason: DenyReason,
};

pub const RoleChange = extern struct {
    new_role: Role,
};

pub const SessionResize = extern struct {
    cols: u16,
    rows: u16,
};

pub const ClientInfo = extern struct {
    id: u32,
    role: Role,
    cols: u16,
    rows: u16,
};

pub const KickClient = extern struct {
    id: u32,
};

pub const Header = extern struct {
    msg_type: u8,
    len: u32,

    pub const size = @sizeOf(Header);
};

fn writeAllFd(fd: posix.fd_t, data: []const u8) !void {
    var written: usize = 0;
    while (written < data.len) {
        const n = posix.write(fd, data[written..]) catch |err| {
            if (err == error.WouldBlock) continue;
            return err;
        };
        written += n;
    }
}

fn readAllFd(fd: posix.fd_t, buf: []u8) !usize {
    var total: usize = 0;
    while (total < buf.len) {
        const n = posix.read(fd, buf[total..]) catch |err| {
            if (err == error.WouldBlock) continue;
            return err;
        };
        if (n == 0) break;
        total += n;
    }
    return total;
}

pub fn writeMsg(fd: posix.fd_t, msg_type: u8, payload: []const u8) !void {
    const header = Header{
        .msg_type = msg_type,
        .len = @intCast(payload.len),
    };
    try writeAllFd(fd, std.mem.asBytes(&header));
    if (payload.len > 0) {
        try writeAllFd(fd, payload);
    }
}

pub fn writeStruct(fd: posix.fd_t, msg_type: u8, data: anytype) !void {
    try writeMsg(fd, msg_type, std.mem.asBytes(&data));
}

pub fn readHeader(fd: posix.fd_t) !Header {
    var buf: [@sizeOf(Header)]u8 = undefined;
    const n = try readAllFd(fd, &buf);
    if (n < buf.len) return error.EndOfStream;
    return std.mem.bytesToValue(Header, &buf);
}

pub fn readPayload(alloc: std.mem.Allocator, fd: posix.fd_t, len: u32) ![]u8 {
    const buf = try alloc.alloc(u8, len);
    errdefer alloc.free(buf);
    const n = try readAllFd(fd, buf);
    if (n < len) {
        alloc.free(buf);
        return error.EndOfStream;
    }
    return buf;
}

pub fn readExact(fd: posix.fd_t, buf: []u8) !void {
    const n = try readAllFd(fd, buf);
    if (n < buf.len) return error.EndOfStream;
}

test "hello struct" {
    var hello = Hello{
        .role = .primary,
        .cols = 80,
        .rows = 24,
    };
    hello.setTerm("xterm-256color");
    try std.testing.expectEqualStrings("xterm-256color", hello.getTerm());
}

test "hello term truncation" {
    var hello = Hello{
        .role = .primary,
        .cols = 80,
        .rows = 24,
    };
    const long_term = "a" ** 100;
    hello.setTerm(long_term);
    try std.testing.expect(hello.getTerm().len < 64);
}

test "header size" {
    try std.testing.expectEqual(@as(usize, 5), @sizeOf(Header));
}

test "message types" {
    try std.testing.expectEqual(@as(u8, 0x01), @intFromEnum(ClientMsg.hello));
    try std.testing.expectEqual(@as(u8, 0x81), @intFromEnum(ServerMsg.welcome));
}
