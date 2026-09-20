const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const asound_c = b.addTranslateC(.{
        .root_source_file = b.path("src/audio/asound.h"),
        .target = target,
        .optimize = optimize,
    });
    const asound_c_module = asound_c.createModule();

    const wav_module = b.createModule(.{
        .root_source_file = b.path("src/audio/wav.zig"),
    });
    const pcm_module = b.createModule(.{
        .root_source_file = b.path("src/audio/pcm.zig"),
        .imports = &.{
            .{ .name = "asound_c", .module = asound_c_module },
            .{ .name = "wav", .module = wav_module },
        },
    });
    const player_module = b.createModule(.{
        .root_source_file = b.path("src/audio/player.zig"),
        .imports = &.{
            .{ .name = "pcm", .module = pcm_module },
        },
    });

    const assets_module = b.createModule(.{
        .root_source_file = b.path("src/assets.zig"),
    });
    const paplay_module = b.createModule(.{
        .root_source_file = b.path("src/paplay.zig"),
    });
    const phase_module = b.createModule(.{
        .root_source_file = b.path("src/phase.zig"),
    });
    const poll_fds_module = b.createModule(.{
        .root_source_file = b.path("src/poll_fds.zig"),
    });
    const timer_fd_module = b.createModule(.{
        .root_source_file = b.path("src/timer_fd.zig"),
    });

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "assets", .module = assets_module },
            .{ .name = "paplay", .module = paplay_module },
            .{ .name = "phase", .module = phase_module },
            .{ .name = "player", .module = player_module },
            .{ .name = "poll_fds", .module = poll_fds_module },
            .{ .name = "timer_fd", .module = timer_fd_module },
        },
    });

    root_module.linkSystemLibrary("asound", .{});

    const exe = b.addExecutable(.{
        .name = "tomahto",
        .root_module = root_module,
    });

    b.installArtifact(exe);

    const run_exe = b.addRunArtifact(exe);

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_exe.step);
}
