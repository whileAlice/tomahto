const std = @import("std");
const posix = std.posix;

const PollFd = enum {
    stdin,
    timer,
    ticking,
    windup,
    ding,
};

pub const PollFds = @This();

items: [5]posix.pollfd,

pub fn init(stdin_fd: posix.fd_t, timer_fd: posix.fd_t) PollFds {
    return .{
        .items = .{
            .{ .fd = stdin_fd, .events = posix.POLL.IN, .revents = 0 },
            .{ .fd = timer_fd, .events = posix.POLL.IN, .revents = 0 },
            .{ .fd = -1, .events = posix.POLL.IN, .revents = 0 },
            .{ .fd = -1, .events = posix.POLL.IN, .revents = 0 },
            .{ .fd = -1, .events = posix.POLL.IN, .revents = 0 },
        },
    };
}

pub fn get(self: *PollFds, comptime which: PollFd) *posix.pollfd {
    return &self.items[@intFromEnum(which)];
}

pub fn slice(self: *PollFds) []posix.pollfd {
    return &self.items;
}

pub fn checkError(self: *const PollFds) !void {
    const poll_error =
        posix.POLL.ERR |
        posix.POLL.HUP |
        posix.POLL.NVAL;

    for (self.items) |pfd| {
        if (pfd.fd >= 0 and pfd.revents & poll_error != 0) {
            return error.PollError;
        }
    }
}

pub fn hasEvent(self: *const PollFds, comptime which: PollFd) bool {
    return self.items[@intFromEnum(which)].revents & posix.POLL.IN != 0;
}
