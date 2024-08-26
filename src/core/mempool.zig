const std = @import("std");

const crypto = std.crypto;

pub const Mempool = struct {
    const Self = @This();
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Self {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(_: Self) void {}
};
