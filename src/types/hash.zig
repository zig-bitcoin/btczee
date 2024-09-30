const std = @import("std");

const Self = @This();

bytes: [32]u8,

/// Create a zero hash
pub fn newZeroed() Self {
    return Self{ .bytes = [_]u8{0} ** 32 };
}

/// Check if two hashes are equal
pub fn eql(self: Self, other: Self) bool {
    return std.mem.eql(u8, &self.bytes, &other.bytes);
}
