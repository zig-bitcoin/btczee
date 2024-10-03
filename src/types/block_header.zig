const std = @import("std");

version: i32,
prev_block: [32]u8,
merkle_root: [32]u8,
timestamp: u32,
nbits: u32,
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
    try writer.writeInt(u32, self.nbits, .little);
    try writer.writeInt(u32, self.nonce, .little);
}

pub fn deserializeReader(r: anytype) !Self {
    var bh: Self = undefined;
    bh.version = try r.readInt(i32, .little);
    try r.readNoEof(&bh.prev_block);
    try r.readNoEof(&bh.merkle_root);
    bh.timestamp = try r.readInt(u32, .little);
    bh.nbits = try r.readInt(u32, .little);
    bh.nonce = try r.readInt(u32, .little);

    return bh;
}

pub fn serializedLen() usize {
    return 80;
}

pub fn eql(self: *const Self, other: *const Self) bool {
    if (self.version != other.version) {
        return false;
    }

    if (!std.mem.eql(u8, &self.prev_block, &other.prev_block)) {
        return false;
    }

    if (!std.mem.eql(u8, &self.merkle_root, &other.merkle_root)) {
        return false;
    }

    if (self.timestamp != other.timestamp) {
        return false;
    }

    if (self.nbits != other.nbits) {
        return false;
    }

    if (self.nonce != other.nonce) {
        return false;
    }

    return true;
}
