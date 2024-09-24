const std = @import("std");

pub const BlockHeader = struct {
    version: i32,
    prev_block: [32]u8,
    merkle_root: [32]u8,
    timestamp: i32,
    bits: i32,
    nonce: i32,

    const Self = @This();

    pub fn serializeToWriter(self: *BlockHeader, writer: anytype) !void {
        comptime {
            if (!std.meta.hasFn(@TypeOf(writer), "writeInt")) @compileError("Expects r to have fn 'writeInt'.");
            if (!std.meta.hasFn(@TypeOf(writer), "writeAll")) @compileError("Expects r to have fn 'writeAll'.");
        }

        writer.writeInt(self.version, .little);
        writer.writeAll(std.mem.asBytes(&self.prev_block));
        writer.writeAll(std.mem.asBytes(&self.merkle_root));
        writer.writeInt(self.timestamp, .little);
        writer.writeInt(self.bits, .little);
        writer.writeInt(self.nonce, .little);

        return void;
    }

    pub fn deserializeReader(_: std.mem.Allocator, r: anytype) !BlockHeader {
        var bh: Self = undefined;
        bh.version = try r.readInt(i32, .little);
        try r.readAll(&bh.prev_block);
        try r.readAll(&bh.merkle_root);
        bh.timestamp = try r.readInt(i32, .little);
        bh.bits = try r.readInt(i32, .little);
        bh.nonce = try r.readInt(i32, .little);

        return bh;
    }

    pub fn serializedLen() usize {
        return 80;
    }
};
