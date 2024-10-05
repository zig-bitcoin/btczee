const std = @import("std");
const protocol = @import("../lib.zig");
const Sha256 = std.crypto.hash.sha2.Sha256;
const genericChecksum = @import("lib.zig").genericChecksum;
const genericSerialize = @import("lib.zig").genericSerialize;
const genericDeserializeSlice = @import("lib.zig").genericDeserializeSlice;

/// PongMessage represents the "Pong" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#pong
pub const PongMessage = struct {
    nonce: u64,

    const Self = @This();

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.PONG ++ [_]u8{0} ** 8;
    }

    /// Returns the message checksum
    ///
    /// Computed as `Sha256(Sha256(self.serialize()))[0..4]`
    pub fn checksum(self: *const Self) [4]u8 {
        return genericChecksum(self);
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        return genericSerialize(self, allocator);
    }

    /// Serialize the message as bytes and write them to the Writer.
    ///
    /// `w` should be a valid `Writer`.
    pub fn serializeToWriter(self: *const Self, w: anytype) !void {
        comptime {
            if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects r to have fn 'writeInt'.");
        }

        try w.writeInt(u64, self.nonce, .little);
    }

    /// Returns the hint of the serialized length of the message
    pub fn hintSerializedLen(_: *const Self) usize {
        // 8 bytes for nonce
        return 8;
    }

    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
        return genericDeserializeSlice(Self, allocator, bytes);
    }

    /// Deserialize a Reader bytes as a `VersionMessage`
    pub fn deserializeReader(_: std.mem.Allocator, r: anytype) !Self {
        comptime {
            if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
        }

        var vm: Self = undefined;

        vm.nonce = try r.readInt(u64, .little);
        return vm;
    }

    pub fn new(nonce: u64) Self {
        return .{
            .nonce = nonce,
        };
    }
};

// TESTS
test "ok_fullflow_pong_message" {
    const allocator = std.testing.allocator;

    {
        const msg = PongMessage.new(0x1234567890abcdef);
        const payload = try msg.serialize(allocator);
        defer allocator.free(payload);
        const deserialized_msg = try PongMessage.deserializeSlice(allocator, payload);
        try std.testing.expectEqual(msg.nonce, deserialized_msg.nonce);
    }
}
