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

header: WavHeader,
samples: []u8,

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
    const samples = try reader.readAlloc(allocator, header.subchunk_2_size);

    return .{
        .header = header,
        .samples = samples,
    };
}

pub fn deinit(self: *Wav, allocator: std.mem.Allocator) void {
    allocator.free(self.samples);
}
