const std = @import("std");
const protocol = @import("../lib.zig");

/// SendHeaders represents the "getaddr" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#sendheaders
pub const SendHeadersMessage = struct {
    // sendheaders message do not contain any payload, thus there is no field
    const Self = @This();

    pub fn new() Self {
        return .{};
    }

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.SENDHEADERS;
    }

    pub fn checksum(self: Self) [4]u8 {
        _ = self;
        // If payload is empty, the checksum is always 0x5df6e0e2 (SHA256(SHA256("")))
        return [4]u8{ 0x5d, 0xf6, 0xe0, 0xe2 };
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        _ = self;
        _ = allocator;
        return &.{};
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
        _ = allocator;
        _ = r;
        return SendHeadersMessage{};
    }

    pub fn hintSerializedLen(self: Self) usize {
        _ = self;
        return 0;
    }
};

// TESTS

test "ok_full_flow_SendHeaders" {
    const allocator = std.testing.allocator;

    {
        const msg = SendHeadersMessage{};

        const payload = try msg.serialize(allocator);
        defer allocator.free(payload);
        const deserialized_msg = try SendHeadersMessage.deserializeReader(allocator, payload);
        _ = deserialized_msg;

        try std.testing.expect(payload.len == 0);
    }
}
