const std = @import("std");

/// A bitcoin block with additonal usefull data
pub const Block = struct {
    hash: [32]u8,
    height: i32,

    pub fn serizalize(self: *Block, allocator: std.mem.Allocator) ![]u8 {
        _ = self;
        const ret = try allocator.alloc(u8, 0);
        return ret;
    }
};

const std = @import("std");

pub const BlockHeader = struct {
    version: i32,
    prev_block: [32]u8,
    merkle_root: [32]u8,
    timestamp: i32,
    bits: i32,
    nonce: i32,

    const Self = @This();

    pub fn serializeToWriter(self: *const Self, writer: anytype) !void {
        comptime {
            if (!std.meta.hasFn(@TypeOf(writer), "writeInt")) @compileError("Expects r to have fn 'writeInt'.");
            if (!std.meta.hasFn(@TypeOf(writer), "writeAll")) @compileError("Expects r to have fn 'writeAll'.");
        }

        try writer.writeInt(i32, self.version, .little);
        try writer.writeAll(std.mem.asBytes(&self.prev_block));
        try writer.writeAll(std.mem.asBytes(&self.merkle_root));
        try writer.writeInt(i32, self.timestamp, .little);
        try writer.writeInt(i32, self.bits, .little);
        try writer.writeInt(i32, self.nonce, .little);
    }

    pub fn deserializeReader(r: anytype) !BlockHeader {
        var bh: Self = undefined;
        bh.version = try r.readInt(i32, .little);
        try r.readNoEof(&bh.prev_block);
        try r.readNoEof(&bh.merkle_root);
        bh.timestamp = try r.readInt(i32, .little);
        bh.bits = try r.readInt(i32, .little);
        bh.nonce = try r.readInt(i32, .little);

        return bh;
    }

    pub fn serializedLen() usize {
        return 80;
    }
};
