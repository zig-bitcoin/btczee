const std = @import("std");

hash: [32]u8,
height: i32,

const Self = @This();

pub fn serizalize(self: *Self, allocator: std.mem.Allocator) ![]u8 {
    _ = self;
    const ret = try allocator.alloc(u8, 0);
    return ret;
}