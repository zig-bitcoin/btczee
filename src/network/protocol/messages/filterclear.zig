const std = @import("std");
const protocol = @import("../lib.zig");
const genericChecksum = @import("lib.zig").genericChecksum;

/// FilterClear represents the "filterclear" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#filterclear
pub const FilterClearMessage = struct {
    // FilterClear message do not contain any payload, thus there is no field

    pub inline fn name() *const [12]u8 {
        return protocol.CommandNames.FILTERCLEAR;
    }

    pub fn checksum(self: FilterClearMessage) [4]u8 {
        return genericChecksum(self, false);
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const FilterClearMessage, allocator: std.mem.Allocator) ![]u8 {
        _ = self;
        _ = allocator;
        return &.{};
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !FilterClearMessage {
        _ = allocator;
        _ = r;
        return FilterClearMessage{};
    }

    pub fn hintSerializedLen(self: FilterClearMessage) usize {
        _ = self;
        return 0;
    }
};

// TESTS

test "ok_full_flow_FilterClearMessage" {
    const allocator = std.testing.allocator;

    {
        const msg = FilterClearMessage{};

        const payload = try msg.serialize(allocator);
        defer allocator.free(payload);
        const deserialized_msg = try FilterClearMessage.deserializeReader(allocator, payload);
        _ = deserialized_msg;

        try std.testing.expect(payload.len == 0);
    }
}
