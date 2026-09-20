const std = @import("std");

const asound_c = @import("asound_c");
const Wav = @import("wav").Wav;

pub const Pcm = @This();

pcm: *asound_c.snd_pcm_t,
hw_params: *asound_c.snd_pcm_hw_params_t,

pub fn init() !Pcm {
    var pcm: ?*asound_c.snd_pcm_t = null;
    var hw_params: ?*asound_c.snd_pcm_hw_params_t = null;

    var res = asound_c.snd_pcm_open(
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

    res = asound_c.snd_pcm_hw_params_malloc(&hw_params);
    if (res < 0) {
        std.log.err("snd_pcm_hw_params_malloc: {s}", .{
            asound_c.snd_strerror(res),
        });

        return error.AlsaHwParamsMallocFailed;
    }

    res = asound_c.snd_pcm_hw_params_any(pcm.?, hw_params.?);
    if (res < 0) {
        std.log.err("snd_pcm_hw_params_any: {s}", .{
            asound_c.snd_strerror(res),
        });

        return error.AlsaHwParamsAnyFailed;
    }

    res = asound_c.snd_pcm_hw_params_set_access(
        pcm.?,
        hw_params.?,
        asound_c.SND_PCM_ACCESS_RW_INTERLEAVED,
    );
    if (res < 0) {
        std.log.err("snd_pcm_hw_params_set_access: {s}", .{
            asound_c.snd_strerror(res),
        });

        return error.AlsaHwParamsSetAccessFailed;
    }

    return Pcm{
        .pcm = pcm.?,
        .hw_params = hw_params.?,
    };
}

pub fn deinit(self: *Pcm) void {
    asound_c.snd_pcm_hw_params_free(self.hw_params);

    const res = asound_c.snd_pcm_close(self.pcm);
    if (res < 0) {
        std.log.err("snd_pcm_close: {s}", .{
            asound_c.snd_strerror(res),
        });
    }
}

pub fn play(self: *Pcm, wav: Wav) !void {
    const format = switch (wav.header.bits_per_sample) {
        16 => asound_c.SND_PCM_FORMAT_S16_LE,
        24 => asound_c.SND_PCM_FORMAT_S24_3LE,
        else => unreachable,
    };

    var res = asound_c.snd_pcm_hw_params_set_format(
        self.pcm,
        self.hw_params,
        format,
    );
    if (res < 0) {
        std.log.err("snd_pcm_hw_params_set_format: {s}", .{
            asound_c.snd_strerror(res),
        });

        return error.AlsaHwParamsSetFormatFailed;
    }

    res = asound_c.snd_pcm_hw_params_set_channels(
        self.pcm,
        self.hw_params,
        wav.header.channel_count,
    );
    if (res < 0) {
        std.log.err("snd_pcm_hw_params_set_channels: {s}", .{
            asound_c.snd_strerror(res),
        });

        return error.AlsaHwParamsSetChannelsFailed;
    }

    var sample_rate = wav.header.sample_rate;
    res = asound_c.snd_pcm_hw_params_set_rate_near(
        self.pcm,
        self.hw_params,
        &sample_rate,
        0,
    );
    if (res < 0) {
        std.log.err("snd_pcm_hw_params_set_rate_near: {s}", .{
            asound_c.snd_strerror(res),
        });

        return error.AlsaHwParamsSetRateFailed;
    }

    res = asound_c.snd_pcm_hw_params(self.pcm, self.hw_params);
    if (res < 0) {
        std.log.err("snd_pcm_hw_params: {s}", .{
            asound_c.snd_strerror(res),
        });

        return error.AlsaHwParamsFailed;
    }

    const frames_to_write = wav.header.subchunk_2_size / wav.header.block_align;
    const frames_written =
        asound_c.snd_pcm_writei(
            self.pcm,
            @ptrCast(wav.samples),
            frames_to_write,
        );

    // TODO: handle problems here.
    if (frames_written < 0) {
        std.log.err("snd_pcm_writei: {d}", .{frames_written});
    }

    if (frames_written < frames_to_write) {
        std.log.err(
            "written {d} frames, expected {d}",
            .{ frames_written, frames_to_write },
        );
    }
}
