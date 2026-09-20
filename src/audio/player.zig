const std = @import("std");

const Pcm = @import("pcm").Pcm;

const Player = @This();

pcm: Pcm,
