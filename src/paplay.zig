const std = @import("std");
const linux = std.os.linux;

pub const Paplay = @This();

io: std.Io,
filename: []const u8,
fd: ?i32,
loop: bool,
process: ?std.process.Child,

pub fn init(io: std.Io, filename: []const u8, loop: bool) Paplay {
    return Paplay{
        .io = io,
        .filename = filename,
        .fd = null,
        .loop = loop,
        .process = null,
    };
}

pub fn playAndGetFd(self: *Paplay) !i32 {
    self.kill();

    const argv = .{
        "paplay",
        self.filename,
    };

    self.process = try std.process.spawn(self.io, .{
        .argv = &argv,
        .stdin = .ignore,
        .stdout = .ignore,
        .stderr = .ignore,
    });

    if (self.process.?.id) |id| {
        const pid: i32 = @intCast(id);
        self.fd = @intCast(linux.pidfd_open(pid, 0));

        return self.fd.?;
    }

    return -1;
}

pub fn kill(self: *Paplay) void {
    if (self.process) |*p| {
        p.kill(self.io);

        self.process = null;
    }

    self.closeFd();
}

pub fn wait(self: *Paplay) !void {
    if (self.process) |*p| {
        _ = try p.wait(self.io);

        self.process = null;
    }

    self.closeFd();
}

fn closeFd(self: *Paplay) void {
    if (self.fd) |fd| {
        const err = linux.close(fd);

        switch (linux.errno(err)) {
            .SUCCESS => {},
            else => |e| std.debug.panic("close: {s}", .{@tagName(e)}),
        }

        self.fd = null;
    }
}
