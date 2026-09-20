const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const asound_c = b.addTranslateC(.{
        .root_source_file = b.path("src/sound/asound.h"),
        .target = target,
        .optimize = optimize,
    });
    const asound_c_module = asound_c.createModule();

    const assets_module = b.createModule(.{
        .root_source_file = b.path("src/assets.zig"),
    });
    const paplay_module = b.createModule(.{
        .root_source_file = b.path("src/paplay.zig"),
    });
    const phase_module = b.createModule(.{
        .root_source_file = b.path("src/phase.zig"),
    });
    const pollfds_module = b.createModule(.{
        .root_source_file = b.path("src/pollfds.zig"),
    });
    const sound_module = b.createModule(.{
        .root_source_file = b.path("src/sound/sound.zig"),
        .imports = &.{
            .{
                .name = "asound_c",
                .module = asound_c_module,
            },
        },
    });
    const timerfd_module = b.createModule(.{
        .root_source_file = b.path("src/timerfd.zig"),
    });

    const root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "assets", .module = assets_module },
            .{ .name = "paplay", .module = paplay_module },
            .{ .name = "phase", .module = phase_module },
            .{ .name = "pollfds", .module = pollfds_module },
            .{ .name = "sound", .module = sound_module },
            .{ .name = "timerfd", .module = timerfd_module },
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
