const std = @import("std");

pub const Block = struct {
    hash: [32]u8,
    height: i32,

    pub fn serizalize(self: *Block, allocator: std.mem.Allocator) ![]u8 {
        _ = self;
        const ret = try allocator.alloc(u8, 0);
        return ret;
    }
};
