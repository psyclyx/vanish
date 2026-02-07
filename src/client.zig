const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const protocol = @import("protocol.zig");

const STDIN = 0;
const STDOUT = 1;

pub fn attach(alloc: std.mem.Allocator, socket_path: []const u8) !void {
    _ = alloc;

    const fd = try connectSocket(socket_path);
    defer posix.close(fd);

    const size = try getTerminalSize();

    var hello = protocol.Hello{
        .role = .primary,
        .cols = size.cols,
        .rows = size.rows,
    };
    if (std.posix.getenv("TERM")) |term| {
        hello.setTerm(term);
    }

    try protocol.writeStruct(fd, @intFromEnum(protocol.ClientMsg.hello), hello);

    const resp_header = try protocol.readHeader(fd);

    switch (@as(protocol.ServerMsg, @enumFromInt(resp_header.msg_type))) {
        .welcome => {
            var buf: [@sizeOf(protocol.Welcome)]u8 = undefined;
            try protocol.readExact(fd, &buf);
        },
        .denied => {
            var buf: [@sizeOf(protocol.Denied)]u8 = undefined;
            try protocol.readExact(fd, &buf);
            const denied = std.mem.bytesToValue(protocol.Denied, &buf);
            switch (denied.reason) {
                .primary_exists => {
                    _ = posix.write(posix.STDERR_FILENO, "Session already has a primary client\n") catch {};
                },
                .invalid_hello => {
                    _ = posix.write(posix.STDERR_FILENO, "Invalid handshake\n") catch {};
                },
            }
            return;
        },
        else => return error.UnexpectedMessage,
    }

    var old_termios: ?posix.termios = null;
    if (posix.isatty(STDIN)) {
        old_termios = setRawMode() catch null;
    }
    defer {
        if (old_termios) |t| restoreTermios(t);
    }

    try runClientLoop(fd);
}

fn runClientLoop(fd: posix.fd_t) !void {
    var poll_fds = [_]posix.pollfd{
        .{ .fd = STDIN, .events = posix.POLL.IN, .revents = 0 },
        .{ .fd = fd, .events = posix.POLL.IN, .revents = 0 },
    };

    while (true) {
        const ready = posix.poll(&poll_fds, -1) catch |err| {
            if (err == error.Interrupted) continue;
            return err;
        };

        if (ready == 0) continue;

        if (poll_fds[0].revents & posix.POLL.IN != 0) {
            var buf: [1024]u8 = undefined;
            const n = posix.read(STDIN, &buf) catch break;
            if (n == 0) break;
            protocol.writeMsg(fd, @intFromEnum(protocol.ClientMsg.input), buf[0..n]) catch break;
        }

        if (poll_fds[1].revents & posix.POLL.IN != 0) {
            const header = protocol.readHeader(fd) catch break;

            switch (@as(protocol.ServerMsg, @enumFromInt(header.msg_type))) {
                .output, .full => {
                    if (header.len > 0) {
                        var remaining: u32 = header.len;
                        var buf: [4096]u8 = undefined;
                        while (remaining > 0) {
                            const to_read: usize = @min(remaining, buf.len);
                            protocol.readExact(fd, buf[0..to_read]) catch break;
                            _ = posix.write(STDOUT, buf[0..to_read]) catch {};
                            remaining -= @intCast(to_read);
                        }
                    }
                },
                .exit => {
                    var buf: [@sizeOf(protocol.Exit)]u8 = undefined;
                    _ = protocol.readExact(fd, &buf) catch {};
                    return;
                },
                else => {
                    var remaining = header.len;
                    var skip_buf: [1024]u8 = undefined;
                    while (remaining > 0) {
                        const chunk: usize = @min(remaining, skip_buf.len);
                        protocol.readExact(fd, skip_buf[0..chunk]) catch break;
                        remaining -= @intCast(chunk);
                    }
                },
            }
        }

        if (poll_fds[1].revents & (posix.POLL.HUP | posix.POLL.ERR) != 0) {
            break;
        }
    }
}

fn connectSocket(path: []const u8) !posix.fd_t {
    var addr = std.net.Address.initUnix(path) catch return error.PathTooLong;
    const sock = try posix.socket(posix.AF.UNIX, posix.SOCK.STREAM | posix.SOCK.CLOEXEC, 0);
    errdefer posix.close(sock);

    try posix.connect(sock, &addr.any, addr.getOsSockLen());

    return sock;
}

const TermSize = struct {
    rows: u16,
    cols: u16,
};

fn getTerminalSize() !TermSize {
    const TIOCGWINSZ = 0x5413;

    const Winsize = extern struct {
        ws_row: u16,
        ws_col: u16,
        ws_xpixel: u16,
        ws_ypixel: u16,
    };

    var ws: Winsize = undefined;
    const result = linux.ioctl(@intCast(STDOUT), TIOCGWINSZ, @intFromPtr(&ws));
    if (@as(isize, @bitCast(result)) < 0) {
        return .{ .rows = 24, .cols = 80 };
    }
    return .{ .rows = ws.ws_row, .cols = ws.ws_col };
}

fn setRawMode() !posix.termios {
    var termios = try posix.tcgetattr(STDIN);
    const old = termios;

    termios.lflag.ECHO = false;
    termios.lflag.ICANON = false;
    termios.lflag.ISIG = false;
    termios.lflag.IEXTEN = false;

    termios.iflag.IXON = false;
    termios.iflag.ICRNL = false;
    termios.iflag.BRKINT = false;
    termios.iflag.INPCK = false;
    termios.iflag.ISTRIP = false;

    termios.oflag.OPOST = false;

    termios.cc[@intFromEnum(posix.V.MIN)] = 1;
    termios.cc[@intFromEnum(posix.V.TIME)] = 0;

    try posix.tcsetattr(STDIN, .FLUSH, termios);

    return old;
}

fn restoreTermios(termios: posix.termios) void {
    posix.tcsetattr(STDIN, .FLUSH, termios) catch {};
}
