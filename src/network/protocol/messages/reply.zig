const std = @import("std");
const protocol = @import("../lib.zig");

const Sha256 = std.crypto.hash.sha2.Sha256;

/// ReplyMessage represents the "reply" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#reply
pub const ReplyMessage = struct {
    reply: []const u8,

    const Self = @This();

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.REPLY ++ [_]u8{0} ** 7;
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

    /// Serialize the message as bytes and write them to the Writer.
    pub fn serializeToWriter(self: *const Self, w: anytype) !void {
        try w.writeAll(self.reply);
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        const serialized_len = self.hintSerializedLen();

        const buffer = try allocator.alloc(u8, serialized_len);
        errdefer allocator.free(buffer);

        var fbs = std.io.fixedBufferStream(buffer);
        try self.serializeToWriter(fbs.writer());

        return buffer;
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
        const reply = try r.readAllAlloc(allocator, std.math.maxInt(usize));
        return Self{ .reply = reply };
    }

    pub fn hintSerializedLen(self: *const Self) usize {
        return self.reply.len;
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.reply);
    }
};

// TESTS
test "ok_fullflow_reply_message" {
    const allocator = std.testing.allocator;

    const reply_text = "This is a reply message";
    const msg = ReplyMessage{ .reply = reply_text };

    const payload = try msg.serialize(allocator);
    defer allocator.free(payload);

    const deserialized_msg = try ReplyMessage.deserializeReader(allocator, std.io.fixedBufferStream(payload).reader());
    defer deserialized_msg.deinit(allocator);

    try std.testing.expectEqualStrings(reply_text, deserialized_msg.reply);
}
