const std = @import("std");
const protocol = @import("../lib.zig");
const Sha256 = std.crypto.hash.sha2.Sha256;

/// PingMessage represents the "Ping" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#ping
pub const PingMessage = struct {
    nonce: u64,

    const Self = @This();

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.PING ++ [_]u8{0} ** 8;
    }

    /// Returns the message checksum
    ///
    /// Computed as `Sha256(Sha256(self.serialize()))[0..4]`
    pub fn checksum(self: *const Self) [4]u8 {
        var digest: [32]u8 = undefined;
        var hasher = Sha256.init(.{});
        const writer = hasher.writer();
        self.serializeToWriter(writer) catch unreachable; // Sha256.write is infaible
        hasher.final(&digest);

        Sha256.hash(&digest, &digest, .{});

        return digest[0..4].*;
    }

    /// Serialize a message as bytes and write them to the buffer.
    ///
    /// buffer.len must be >= than self.hintSerializedLen()
    pub fn serializeToSlice(self: *const Self, buffer: []u8) !void {
        var fbs = std.io.fixedBufferStream(buffer);
        try self.serializeToWriter(fbs.writer());
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        const serialized_len = self.hintSerializedLen();

        const ret = try allocator.alloc(u8, serialized_len);
        errdefer allocator.free(ret);

        try self.serializeToSlice(ret);

        return ret;
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
        var fbs = std.io.fixedBufferStream(bytes);
        return try Self.deserializeReader(allocator, fbs.reader());
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
test "ok_fullflow_ping_message" {
    const allocator = std.testing.allocator;

    {
        const msg = PingMessage.new(0x1234567890abcdef);
        const payload = try msg.serialize(allocator);
        defer allocator.free(payload);
        const deserialized_msg = try PingMessage.deserializeSlice(allocator, payload);
        try std.testing.expectEqual(msg.nonce, deserialized_msg.nonce);
    }
}
