const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const tfd_flags: linux.TFD.TIMER = .{
    .ABSTIME = false,
    .CANCEL_ON_SET = false,
};
const zero_itimerspec: linux.itimerspec = .{
    .it_interval = .{ .nsec = 0, .sec = 0 },
    .it_value = .{ .nsec = 0, .sec = 0 },
};

pub const TimerFd = @This();

fd: i32,
interval: linux.timespec,
saved: linux.itimerspec,

pub fn init(interval: std.Io.Duration) TimerFd {
    return TimerFd{
        .fd = createFd(),
        .interval = nsToTimespec(interval.nanoseconds),
        .saved = zero_itimerspec,
    };
}

pub fn deinit(self: TimerFd) void {
    const res = linux.close(self.fd);
    switch (linux.errno(res)) {
        .SUCCESS => {},
        else => |e| std.debug.panic("close: {s}", .{@tagName(e)}),
    }
}

fn nsToTimespec(ns: i96) linux.timespec {
    return .{
        .sec = @as(isize, @intCast(@divTrunc(ns, std.time.ns_per_s))),
        .nsec = @as(isize, @intCast(@mod(ns, std.time.ns_per_s))),
    };
}

pub fn arm(self: TimerFd) void {
    const rc = linux.timerfd_settime(
        self.fd,
        tfd_flags,
        &linux.itimerspec{
            .it_interval = self.interval,
            .it_value = self.interval,
        },
        null,
    );
    switch (linux.errno(rc)) {
        .SUCCESS => {},
        else => |err| std.debug.panic(
            "timerfd_settime: {s}",
            .{@tagName(err)},
        ),
    }
}

fn createFd() i32 {
    return @as(i32, @intCast(linux.timerfd_create(
        .MONOTONIC,
        linux.TFD{ .NONBLOCK = false, .CLOEXEC = true },
    )));
}

pub fn consume(self: TimerFd) void {
    var expiry: u64 = undefined;
    _ = posix.read(
        self.fd,
        std.mem.asBytes(&expiry),
    ) catch |err| std.debug.panic("read: {s}", .{@errorName(err)});
}

pub fn pause(self: *TimerFd) void {
    const is_unpause = !std.meta.eql(self.saved, zero_itimerspec);

    const rc = linux.timerfd_settime(
        self.fd,
        tfd_flags,
        &self.saved,
        if (is_unpause) null else &self.saved,
    );

    switch (linux.errno(rc)) {
        .SUCCESS => {},
        else => |err| std.debug.panic(
            "timerfd_settime: {s}",
            .{@tagName(err)},
        ),
    }

    if (is_unpause) self.saved = zero_itimerspec;
}
