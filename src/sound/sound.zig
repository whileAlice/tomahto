const std = @import("std");

const asound_c = @import("asound_c");

pub const Sound = @This();

pcm: *asound_c.snd_pcm_t,

pub fn init() !Sound {
    var pcm: ?*asound_c.snd_pcm_t = null;

    const res = asound_c.snd_pcm_open(
        &pcm,
        "default",
        asound_c.SND_PCM_STREAM_PLAYBACK,
        0,
    );

    if (res < 0) {
        std.log.err("snd_pcm_open: {s}", .{
            asound_c.snd_strerror(res),
        });

        return error.AlsaOpenFailed;
    }

    return Sound{
        .pcm = pcm.?,
    };
}

pub fn deinit(self: Sound) void {
    const res = asound_c.snd_pcm_close(self.pcm);

    if (res < 0) {
        std.log.err("snd_pcm_close: {s}", .{
            asound_c.snd_strerror(res),
        });
    }
}
