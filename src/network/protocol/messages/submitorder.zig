const std = @import("std");
const protocol = @import("../lib.zig");

const Sha256 = std.crypto.hash.sha2.Sha256;

/// SubmitOrderMessage represents the "submitorder" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#submitorder
pub const SubmitOrderMessage = struct {
    // TODO: Define the fields for the submitorder message
    // For now, we'll use a placeholder field
    placeholder: u32,

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.SUBMITORDER;
    }

    /// Returns the message checksum
    pub fn checksum(self: *const SubmitOrderMessage) [4]u8 {
        var digest: [32]u8 = undefined;
        var hasher = Sha256.init(.{});
        const writer = hasher.writer();
        self.serializeToWriter(writer) catch unreachable;
        hasher.final(&digest);

        Sha256.hash(&digest, &digest, .{});

        return digest[0..4].*;
    }

    /// Serialize the message as bytes and write them to the Writer.
    pub fn serializeToWriter(self: *const SubmitOrderMessage, w: anytype) !void {
        try w.writeInt(u32, self.placeholder, .little);
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const SubmitOrderMessage, allocator: std.mem.Allocator) ![]u8 {
        const serialized_len = self.hintSerializedLen();

        const buffer = try allocator.alloc(u8, serialized_len);
        errdefer allocator.free(buffer);

        var fbs = std.io.fixedBufferStream(buffer);
        try self.serializeToWriter(fbs.writer());

        return buffer;
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !SubmitOrderMessage {
        _ = allocator;
        var msg: SubmitOrderMessage = undefined;
        msg.placeholder = try r.readInt(u32, .little);
        return msg;
    }

    pub fn hintSerializedLen(self: *const SubmitOrderMessage) usize {
        _ = self;
        return 4; // placeholder is u32 (4 bytes)
    }
};

// TESTS
test "ok_full_flow_SubmitOrderMessage" {
    const allocator = std.testing.allocator;

    const msg = SubmitOrderMessage{ .placeholder = 42 };

    const payload = try msg.serialize(allocator);
    defer allocator.free(payload);

    var fbs = std.io.fixedBufferStream(payload);
    const deserialized_msg = try SubmitOrderMessage.deserializeReader(allocator, fbs.reader());

    try std.testing.expectEqual(msg.placeholder, deserialized_msg.placeholder);
}
