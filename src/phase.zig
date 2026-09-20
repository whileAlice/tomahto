const std = @import("std");

const PhaseId = enum {
    focus,
    short_break,
    long_break,
};

pub const PhaseConfig = struct {
    focus_length_min: u32 = 25,
    short_break_length_min: u32 = 5,
    long_break_length_min: u32 = 15,
    completed_before_long_break: u32 = 4,
};

pub const Phase = @This();

id: PhaseId,
config: PhaseConfig,

pub fn init(phase_config: PhaseConfig) Phase {
    return Phase{
        .id = .focus,
        .config = phase_config,
    };
}

pub fn totalSeconds(self: Phase) u32 {
    const c = &self.config;
    return switch (self.id) {
        .focus => c.focus_length_min * std.time.s_per_min,
        .short_break => c.short_break_length_min * std.time.s_per_min,
        .long_break => c.long_break_length_min * std.time.s_per_min,
    };
}

pub fn next(self: *Phase, completed: u32) void {
    const c = &self.config;
    self.id = switch (self.id) {
        .focus => if (completed % c.completed_before_long_break == 0)
            .long_break
        else
            .short_break,
        .short_break, .long_break => .focus,
    };
}

pub fn label(self: Phase) []const u8 {
    return switch (self.id) {
        .focus => "FOCUS",
        .short_break => "SHORT BREAK",
        .long_break => "LONG BREAK",
    };
}
