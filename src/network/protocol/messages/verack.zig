const std = @import("std");
const protocol = @import("../lib.zig");
const genericChecksum = @import("lib.zig").genericChecksum;

/// VerackMessage represents the "verack" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#verack
pub const VerackMessage = struct {
    // verack message do not contain any payload, thus there is no field

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.VERACK ++ [_]u8{0} ** 6;
    }

    pub fn checksum(self: VerackMessage) [4]u8 {
        return genericChecksum(self, false);
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const VerackMessage, allocator: std.mem.Allocator) ![]u8 {
        _ = self;
        _ = allocator;
        return &.{};
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !VerackMessage {
        _ = allocator;
        _ = r;
        return VerackMessage{};
    }

    pub fn hintSerializedLen(self: VerackMessage) usize {
        _ = self;
        return 0;
    }
};

// TESTS

test "ok_full_flow_VerackMessage" {
    const allocator = std.testing.allocator;

    {
        const msg = VerackMessage{};

        const payload = try msg.serialize(allocator);
        defer allocator.free(payload);
        const deserialized_msg = try VerackMessage.deserializeReader(allocator, payload);
        _ = deserialized_msg;

        try std.testing.expect(payload.len == 0);
    }
}
