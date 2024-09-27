const std = @import("std");
const protocol = @import("../lib.zig");
const Sha256 = std.crypto.hash.sha2.Sha256;

/// CheckOrderMessage represents the "checkorder" message
///
/// Note: This message is deprecated and no longer used in the Bitcoin protocol.
/// It's implemented here for historical reasons and compatibility with older nodes.
pub const CheckOrderMessage = struct {
    // As this message is deprecated, we'll leave it empty for now
    // In a real implementation, you might want to add fields based on the original specification

    const Self = @This();

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.CHECKORDER ++ [_]u8{0} ** 3;
    }

    /// Returns the message checksum
    ///
    /// Computed as `Sha256(Sha256(self.serialize()))[0..4]`
    pub fn checksum(self: *const Self) [4]u8 {
        var digest: [32]u8 = undefined;
        var hasher = Sha256.init(.{});
        const writer = hasher.writer();
        self.serializeToWriter(writer) catch unreachable; // Sha256.write is infallible
        hasher.final(&digest);

        Sha256.hash(&digest, &digest, .{});

        return digest[0..4].*;
    }

    pub fn serializeToWriter(self: *const Self, w: anytype) !void {
        _ = self;
        _ = w;
        // As this message is deprecated, we don't need to implement serialization
    }

    pub fn serialize(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        _ = self;
        _ = allocator;
        return &.{};
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
        _ = allocator;
        _ = r;
        return Self{};
    }

    pub fn hintSerializedLen(self: *const Self) usize {
        _ = self;
        return 0;
    }
};

// TESTS

test "ok_full_flow_CheckOrderMessage" {
    const allocator = std.testing.allocator;

    {
        const msg = CheckOrderMessage{};

        const payload = try msg.serialize(allocator);
        defer allocator.free(payload);
        const deserialized_msg = try CheckOrderMessage.deserializeReader(allocator, payload);
        _ = deserialized_msg;

        try std.testing.expect(payload.len == 0);
    }
}
