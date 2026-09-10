const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

const Paplay = @import("paplay.zig").Paplay;
const Phase = @import("phase.zig").Phase;
const PhaseConfig = @import("phase.zig").PhaseConfig;
const PollFds = @import("pollfds.zig").PollFds;
const TimerFd = @import("timerfd.zig").TimerFd;

const clear_screen = "\x1b[2J";
const clear_line = "\x1b[2K";
const hide_cursor = "\x1b[?25l";
const show_cursor = "\x1b[?25h";
const move_cursor = "\x1b[{d};{d}H";

pub fn main(init: std.process.Init) !void {
    var args_iter = try init.minimal.args.iterateAllocator(init.gpa);
    defer args_iter.deinit();

    _ = args_iter.skip();

    var phase_config = PhaseConfig{};
    if (args_iter.next()) |fl| {
        phase_config.focus_length_min = try std.fmt.parseInt(u32, fl, 10);
    }
    if (args_iter.next()) |sb| {
        phase_config.short_break_length_min = try std.fmt.parseInt(u32, sb, 10);
    }
    if (args_iter.next()) |lb| {
        phase_config.long_break_length_min = try std.fmt.parseInt(u32, lb, 10);
    }
    if (args_iter.next()) |cblb| {
        phase_config.completed_before_long_break =
            try std.fmt.parseInt(u32, cblb, 10);
    }
    var phase = Phase.init(phase_config);

    const termios_orig = try posix.tcgetattr(posix.STDIN_FILENO);
    var termios = termios_orig;

    termios.lflag.ECHO = false;
    termios.lflag.ICANON = false;

    try posix.tcsetattr(posix.STDIN_FILENO, .NOW, termios);
    defer posix.tcsetattr(posix.STDIN_FILENO, .NOW, termios_orig) catch |err| {
        std.log.err("tcsetattr: {s}", .{@errorName(err)});
    };

    var stdin_buffer: [256]u8 = undefined;
    var stdout_buffer: [256]u8 = undefined;

    var stdout_writer: std.Io.File.Writer =
        .init(.stdout(), init.io, &stdout_buffer);
    const stdout = &stdout_writer.interface;

    try stdout.print(hide_cursor, .{});
    defer {
        stdout.print(clear_screen, .{}) catch {};
        stdout.print(move_cursor, .{ 0, 0 }) catch {};
        stdout.print(show_cursor, .{}) catch {};
        stdout.flush() catch {};
    }

    var timer_fd = TimerFd.init(.fromSeconds(1));
    defer timer_fd.deinit();

    timer_fd.arm();

    var pfds = PollFds.init(posix.STDIN_FILENO, timer_fd.fd);

    var ding = Paplay.init(init.io, "../assets/ding.wav", false);
    var windup = Paplay.init(init.io, "../assets/windup.wav", false);
    var ticking = Paplay.init(init.io, "../assets/ticking.wav", true);
    defer {
        ding.kill();
        windup.kill();
        ticking.kill();
    }

    var should_update = true;
    var is_paused = false;
    var is_ticking_muted = false;
    var completed: u32 = 0;

    outer: while (true) {
        if (phase.id == .focus) {
            pfds.get(.windup).fd = try windup.play_and_get_fd();
            if (!is_ticking_muted) {
                pfds.get(.ticking).fd = try ticking.play_and_get_fd();
            }
        }

        var remaining: u32 = phase.totalSeconds();
        while (remaining > 0) {
            if (should_update) {
                try printStatus(stdout, phase, remaining);
                should_update = false;
            }

            _ = try posix.poll(pfds.slice(), -1);

            try pfds.checkError();

            if (pfds.hasEvent(.stdin)) {
                _ = try posix.read(pfds.get(.stdin).fd, &stdin_buffer);
                const char = stdin_buffer[0];

                // quit
                if (char == 'q') {
                    break :outer;
                }

                // restart current phase
                if (char == 'r') {
                    timer_fd.arm();
                    should_update = true;
                    remaining = phase.totalSeconds();
                }

                // next phase
                if (char == 'n') {
                    timer_fd.arm();
                    should_update = true;
                    break;
                }

                // mute ticking
                if (char == 'm') {
                    is_ticking_muted = !is_ticking_muted;

                    if (phase.id == .focus) {
                        if ((is_ticking_muted or is_paused) and
                            ticking.process != null)
                        {
                            ticking.kill();
                            pfds.get(.ticking).fd = -1;
                        }
                        if (!is_ticking_muted and !is_paused and
                            ticking.process == null)
                        {
                            pfds.get(.ticking).fd =
                                try ticking.play_and_get_fd();
                        }
                    }
                }

                // pause
                if (char == ' ') {
                    is_paused = !is_paused;
                    timer_fd.pause();

                    // NOTE: this is repeated so that it doesn't fire without
                    // pressing pause/mute, but maybe there's a better way?
                    if (phase.id == .focus) {
                        if ((is_ticking_muted or is_paused) and
                            ticking.process != null)
                        {
                            ticking.kill();
                            pfds.get(.ticking).fd = -1;
                        }
                        if (!is_ticking_muted and !is_paused and
                            ticking.process == null)
                        {
                            pfds.get(.ticking).fd =
                                try ticking.play_and_get_fd();
                        }
                    }
                }
            }

            if (pfds.hasEvent(.timer)) {
                timer_fd.consume();
                remaining -= 1;
                should_update = true;
            }

            if (pfds.hasEvent(.ticking)) {
                try ticking.wait();
                pfds.get(.ticking).fd = try ticking.play_and_get_fd();
            }

            if (pfds.hasEvent(.windup)) {
                try windup.wait();
                pfds.get(.windup).fd = -1;
            }

            if (pfds.hasEvent(.ding)) {
                try ding.wait();
                pfds.get(.ding).fd = -1;
            }
        }

        if (phase.id == .focus) {
            completed += 1;

            ticking.kill();
            pfds.get(.ticking).fd = -1;

            pfds.get(.ding).fd = try ding.play_and_get_fd();
        }

        phase.next(completed);
    }
}

fn printStatus(w: *std.Io.Writer, phase: Phase, remaining: u32) !void {
    const wsz = try getWinsize();
    const text_len = phase.label().len + 1 + 5; // label + space + xx:xx

    try w.print(clear_screen, .{});
    try w.print(move_cursor, .{ wsz.row / 2, wsz.col / 2 - text_len / 2 });
    try w.print(
        "{s} {d:0>2}:{d:0>2}",
        .{ phase.label(), remaining / 60, remaining % 60 },
    );

    try w.flush();
}

fn getWinsize() !posix.winsize {
    var winsize: posix.winsize = undefined;
    var attempts: u8 = 5;

    while (attempts > 0) : (attempts -= 1) {
        const res = linux.ioctl(
            posix.STDOUT_FILENO,
            linux.T.IOCGWINSZ,
            @intFromPtr(&winsize),
        );
        const errno = linux.errno(res);

        return switch (errno) {
            .SUCCESS => winsize,
            .INTR => continue,
            .BADF => error.InvalidFileDescriptor,
            .FAULT => error.ArgReferencesInvalidMemoryArea,
            .INVAL => error.InvalidRequestOrArg,
            .NOTTY => error.FdNotAssociatedWithCharacterSpecialDevice,
            else => |err| posix.unexpectedErrno(err),
        };
    }

    return error.TooManyInterruptions;
}
