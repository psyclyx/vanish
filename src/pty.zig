const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

pub const Pty = @This();

master: posix.fd_t,
slave_path: [std.fs.max_path_bytes:0]u8,
child_pid: ?posix.pid_t = null,

pub const Size = extern struct {
    rows: u16,
    cols: u16,
    xpixel: u16 = 0,
    ypixel: u16 = 0,
};

pub fn open() !Pty {
    const master = try posix.open("/dev/ptmx", .{ .ACCMODE = .RDWR, .NOCTTY = true, .CLOEXEC = true }, 0);
    errdefer posix.close(master);

    try grantpt(master);
    try unlockpt(master);

    var slave_path: [std.fs.max_path_bytes:0]u8 = undefined;
    try ptsname(master, &slave_path);

    return .{
        .master = master,
        .slave_path = slave_path,
    };
}

pub fn close(self: *Pty) void {
    posix.close(self.master);
    self.master = -1;
}

pub fn resize(self: *Pty, size: Size) !void {
    const TIOCSWINSZ = 0x5414;
    const result = linux.ioctl(@intCast(self.master), TIOCSWINSZ, @intFromPtr(&size));
    if (@as(isize, @bitCast(result)) < 0) {
        return error.IoctlFailed;
    }
}

pub fn spawn(self: *Pty, argv: []const []const u8, env: ?[*:null]const ?[*:0]const u8) !void {
    const pid = try posix.fork();
    if (pid == 0) {
        self.childSetup(argv, env);
    } else {
        self.child_pid = pid;
    }
}

fn childSetup(self: *Pty, argv: []const []const u8, env: ?[*:null]const ?[*:0]const u8) noreturn {
    _ = posix.setsid() catch {};

    const path_end = std.mem.indexOfScalar(u8, &self.slave_path, 0) orelse self.slave_path.len;
    const slave_path_slice: [:0]const u8 = self.slave_path[0..path_end :0];

    const slave = posix.openZ(slave_path_slice, .{ .ACCMODE = .RDWR }, 0) catch
        std.process.exit(1);

    const TIOCSCTTY = 0x540E;
    _ = linux.ioctl(@intCast(slave), TIOCSCTTY, 0);

    posix.dup2(slave, 0) catch std.process.exit(1);
    posix.dup2(slave, 1) catch std.process.exit(1);
    posix.dup2(slave, 2) catch std.process.exit(1);

    if (slave > 2) posix.close(slave);
    posix.close(self.master);

    const argv_buf = std.heap.page_allocator.alloc(?[*:0]const u8, argv.len + 1) catch
        std.process.exit(1);
    for (argv, 0..) |arg, i| {
        argv_buf[i] = std.heap.page_allocator.dupeZ(u8, arg) catch std.process.exit(1);
    }
    argv_buf[argv.len] = null;

    const actual_env = env orelse std.c.environ;

    posix.execvpeZ(argv_buf[0].?, argv_buf[0..argv.len :null], actual_env) catch {};
    std.process.exit(127);
}

pub fn wait(self: *Pty) !u32 {
    if (self.child_pid) |pid| {
        const result = posix.waitpid(pid, 0);
        self.child_pid = null;
        return result.status;
    }
    return 0;
}

fn grantpt(fd: posix.fd_t) !void {
    _ = fd;
}

fn unlockpt(fd: posix.fd_t) !void {
    const TIOCSPTLCK = 0x40045431;
    var unlock: c_int = 0;
    const result = linux.ioctl(@intCast(fd), TIOCSPTLCK, @intFromPtr(&unlock));
    if (@as(isize, @bitCast(result)) < 0) {
        return error.UnlockFailed;
    }
}

fn ptsname(fd: posix.fd_t, buf: *[std.fs.max_path_bytes:0]u8) !void {
    const TIOCGPTN = 0x80045430;
    var ptn: c_uint = 0;
    const result = linux.ioctl(@intCast(fd), TIOCGPTN, @intFromPtr(&ptn));
    if (@as(isize, @bitCast(result)) < 0) {
        return error.PtsnameFailed;
    }
    _ = std.fmt.bufPrintZ(buf, "/dev/pts/{d}", .{ptn}) catch return error.BufferTooSmall;
}

test "pty open" {
    var pty = try open();
    defer pty.close();

    try std.testing.expect(pty.master >= 0);
    try std.testing.expect(std.mem.startsWith(u8, &pty.slave_path, "/dev/pts/"));
}

test "pty resize" {
    var pty = try open();
    defer pty.close();

    try pty.resize(.{ .rows = 24, .cols = 80 });
    try pty.resize(.{ .rows = 50, .cols = 120 });
}
