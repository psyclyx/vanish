const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

var sigwinch_received: bool = false;
var sigterm_received: bool = false;

fn sigwinchHandler(_: c_int) callconv(.c) void {
    sigwinch_received = true;
}

fn sigtermHandler(_: c_int) callconv(.c) void {
    sigterm_received = true;
}

pub fn setup() void {
    var sa_winch: posix.Sigaction = .{
        .handler = .{ .handler = sigwinchHandler },
        .mask = posix.sigemptyset(),
        .flags = 0,
    };
    posix.sigaction(posix.SIG.WINCH, &sa_winch, null);

    var sa_term: posix.Sigaction = .{
        .handler = .{ .handler = sigtermHandler },
        .mask = posix.sigemptyset(),
        .flags = 0,
    };
    posix.sigaction(posix.SIG.TERM, &sa_term, null);
    posix.sigaction(posix.SIG.INT, &sa_term, null);
}

pub fn checkWinch() bool {
    if (sigwinch_received) {
        sigwinch_received = false;
        return true;
    }
    return false;
}

pub fn checkTerm() bool {
    return sigterm_received;
}

pub fn reset() void {
    sigwinch_received = false;
    sigterm_received = false;
}
