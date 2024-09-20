
const std = @import("std");
const native_endian = @import("builtin").target.cpu.arch.endian();
const protocol = @import("../lib.zig");

const ServiceFlags = protocol.ServiceFlags;

const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;

/// MempoolMessage represents the "mempool" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#version
pub const MempoolMessage = struct {
    // mempool message do not contain any payload, thus there is no field

    pub inline fn name() *const [12]u8 {
        return protocol.CommandNames.MEMPOOL ++ [_]u8{0} ** 5;
    }

    pub fn checksum(self: MempoolMessage) [4]u8 {
        _ = self;
        // If payload is empty, the checksum is always 0x5df6e0e2 (SHA256(SHA256("")))
        return [4]u8{ 0x5d, 0xf6, 0xe0, 0xe2 };
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
