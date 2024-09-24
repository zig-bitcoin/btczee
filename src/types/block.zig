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

pub const BlockHeader = struct {
    version: i32,
    prev_block: [32]u8,
    merkle_root: [32]u8,
    timestamp: i32,
    nbits: i32,
    nonce: i32,
};
