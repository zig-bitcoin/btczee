const std = @import("std");
const protocol = @import("../lib.zig");
const default_checksum = @import("lib.zig").default_checksum;

/// MempoolMessage represents the "mempool" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#mempool
pub const MempoolMessage = struct {
    // mempool message do not contain any payload, thus there is no field

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.MEMPOOL ++ [_]u8{0} ** 5;
    }

    pub fn checksum(self: MempoolMessage) [4]u8 {
        _ = self;
        return default_checksum;
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const MempoolMessage, allocator: std.mem.Allocator) ![]u8 {
        _ = self;
        _ = allocator;
        return &.{};
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !MempoolMessage {
        _ = allocator;
        _ = r;
        return MempoolMessage{};
    }

    pub fn hintSerializedLen(self: MempoolMessage) usize {
        _ = self;
        return 0;
    }
};

// TESTS

test "ok_full_flow_MempoolMessage" {
    const allocator = std.testing.allocator;

    {
        const msg = MempoolMessage{};

        const payload = try msg.serialize(allocator);
        defer allocator.free(payload);
        const deserialized_msg = try MempoolMessage.deserializeReader(allocator, payload);
        _ = deserialized_msg;

        try std.testing.expect(payload.len == 0);
    }
}
