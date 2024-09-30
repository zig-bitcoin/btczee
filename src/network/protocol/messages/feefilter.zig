const std = @import("std");
const protocol = @import("../lib.zig");
const Sha256 = std.crypto.hash.sha2.Sha256;
const genericChecksum = @import("lib.zig").genericChecksum;

/// FeeFilterMessage represents the "feefilter" message
///
/// https://github.com/bitcoin/bips/blob/master/bip-0133.mediawiki
pub const FeeFilterMessage = struct {
    feerate: u64,

    const Self = @This();

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.FEEFILTER ++ [_]u8{0} ** 4;
    }

    /// Returns the message checksum
    ///
    /// Computed as `Sha256(Sha256(self.serialize()))[0..4]`
    pub fn checksum(self: *const Self) [4]u8 {
        return genericChecksum(self, true);
    }

    /// Serialize a message as bytes and write them to the buffer.
    ///
    /// buffer.len must be >= than self.hintSerializedLen()
    pub fn serializeToSlice(self: *const Self, buffer: []u8) !void {
        var fbs = std.io.fixedBufferStream(buffer);
        try self.serializeToWriter(fbs.writer());
    }

    /// Serialize the message as bytes and write them to the Writer.
    pub fn serializeToWriter(self: *const Self, w: anytype) !void {
        try w.writeInt(u64, self.feerate, .little);
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        const serialized_len = self.hintSerializedLen();

        const ret = try allocator.alloc(u8, serialized_len);
        errdefer allocator.free(ret);

        try self.serializeToSlice(ret);

        return ret;
    }

    /// Deserialize a Reader bytes as a `FeeFilterMessage`
    pub fn deserializeReader(_: std.mem.Allocator, r: anytype) !Self {
        comptime {
            if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
        }

        var fm: Self = undefined;
        fm.feerate = try r.readInt(u64, .little);
        return fm;
    }

    /// Deserialize bytes into a `FeeFilterMessage`
    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
        var fbs = std.io.fixedBufferStream(bytes);
        const reader = fbs.reader();

        return try Self.deserializeReader(allocator, reader);
    }

    pub fn hintSerializedLen(_: *const Self) usize {
        return 8; // feerate is u64 (8 bytes)
    }

    pub fn new(feerate: u64) Self {
        return .{
            .feerate = feerate,
        };
    }
};

// TESTS
test "ok_fullflow_feefilter_message" {
    const allocator = std.testing.allocator;

    {
        const msg = FeeFilterMessage.new(48508);
        const payload = try msg.serialize(allocator);
        defer allocator.free(payload);
        const deserialized_msg = try FeeFilterMessage.deserializeSlice(allocator, payload);
        try std.testing.expectEqual(msg.feerate, deserialized_msg.feerate);
    }
}
