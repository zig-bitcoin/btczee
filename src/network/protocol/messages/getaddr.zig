const std = @import("std");
const protocol = @import("../lib.zig");
const genericChecksum = @import("lib.zig").genericChecksum;

/// GetaddrMessage represents the "getaddr" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#getaddr
pub const GetaddrMessage = struct {
    // getaddr message do not contain any payload, thus there is no field

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.GETADDR ++ [_]u8{0} ** 5;
    }

    pub fn checksum(self: GetaddrMessage) [4]u8 {
        return genericChecksum(self, false);
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const GetaddrMessage, allocator: std.mem.Allocator) ![]u8 {
        _ = self;
        _ = allocator;
        return &.{};
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !GetaddrMessage {
        _ = allocator;
        _ = r;
        return GetaddrMessage{};
    }

    pub fn hintSerializedLen(self: GetaddrMessage) usize {
        _ = self;
        return 0;
    }
};

// TESTS

test "ok_full_flow_GetaddrMessage" {
    const allocator = std.testing.allocator;

    {
        const msg = GetaddrMessage{};

        const payload = try msg.serialize(allocator);
        defer allocator.free(payload);
        const deserialized_msg = try GetaddrMessage.deserializeReader(allocator, payload);
        _ = deserialized_msg;

        try std.testing.expect(payload.len == 0);
    }
}
