const std = @import("std");

version: i32,
prev_block: [32]u8,
merkle_root: [32]u8,
timestamp: u32,
bits: u32,
nonce: u32,

const Self = @This();

pub fn serializeToWriter(self: *const Self, writer: anytype) !void {
    comptime {
        if (!std.meta.hasFn(@TypeOf(writer), "writeInt")) @compileError("Expects r to have fn 'writeInt'.");
        if (!std.meta.hasFn(@TypeOf(writer), "writeAll")) @compileError("Expects r to have fn 'writeAll'.");
    }

    try writer.writeInt(i32, self.version, .little);
    try writer.writeAll(std.mem.asBytes(&self.prev_block));
    try writer.writeAll(std.mem.asBytes(&self.merkle_root));
    try writer.writeInt(u32, self.timestamp, .little);
    try writer.writeInt(u32, self.bits, .little);
    try writer.writeInt(u32, self.nonce, .little);
}

pub fn deserializeReader(r: anytype) !Self {
    var bh: Self = undefined;
    bh.version = try r.readInt(i32, .little);
    try r.readNoEof(&bh.prev_block);
    try r.readNoEof(&bh.merkle_root);
    bh.timestamp = try r.readInt(u32, .little);
    bh.bits = try r.readInt(u32, .little);
    bh.nonce = try r.readInt(u32, .little);

    return bh;
}

pub fn serializedLen() usize {
    return 80;
}
