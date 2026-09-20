const std = @import("std");

const WavHeader = extern struct {
    chunk_id: [4]u8,
    chunk_size: u32,
    format: [4]u8,
    subchunk_1_id: [4]u8,
    subchunk_1_size: u32,
    audio_format: u16,
    channel_count: u16,
    sample_rate: u32,
    byte_rate: u32,
    block_align: u16,
    bits_per_sample: u16,
    subchunk_2_id: [4]u8,
    subchunk_2_size: u32,
};

comptime {
    std.debug.assert(@sizeOf(WavHeader) == 44);
}

pub const Wav = @This();

samples: []i16,
sample_rate: u32,
channel_count: u16,

pub fn init(
    allocator: std.mem.Allocator,
    io: std.Io,
    filename: []const u8,
) !Wav {
    const file = try std.Io.Dir.cwd().openFile(io, filename, .{});
    defer file.close(io);

    var file_reader = file.reader(io, &.{});
    const reader = &file_reader.interface;

    const header = try reader.takeStruct(WavHeader, .little);
    const sample_count = header.subchunk_2_size / @sizeOf(i16);
    const samples =
        try reader.readSliceEndianAlloc(allocator, i16, sample_count, .little);

    return .{
        .samples = samples,
        .sample_rate = header.sample_rate,
        .channel_count = header.channel_count,
    };
}

pub fn deinit(self: *Wav, allocator: std.mem.Allocator) void {
    allocator.free(self.samples);
}
