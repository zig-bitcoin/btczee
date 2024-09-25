const std = @import("std");
const native_endian = @import("builtin").target.cpu.arch.endian();
const protocol = @import("../lib.zig");

const ServiceFlags = protocol.ServiceFlags;

const Endian = std.builtin.Endian;
const Sha256 = std.crypto.hash.sha2.Sha256;

const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;

/// GetblocksMessage represents the "getblocks" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#getblocks
pub const GetblocksMessage = struct {

    version: i32,
    header_hashes: [] [32]u8,
    stop_hash: [32]u8,

    pub inline fn name() *const [12]u8 {
        return protocol.CommandNames.GETBLOCKS ++ [_]u8{0} ** 5;
    }

    /// Returns the message checksum
    ///
    /// Computed as `Sha256(Sha256(self.serialize()))[0..4]`
    pub fn checksum(self: *const GetblocksMessage) [4]u8 {
        var digest: [32]u8 = undefined;
        var hasher = Sha256.init(.{});
        const writer = hasher.writer();
        self.serializeToWriter(writer) catch unreachable; // Sha256.write is infaible
        hasher.final(&digest);

        Sha256.hash(&digest, &digest, .{});

        return digest[0..4].*;
    }

    /// Free the `header_hashes`
    pub fn deinit(self: GetblocksMessage, allocator: std.mem.Allocator) void {
        allocator.free(self.header_hashes);
    }

    /// Serialize the message as bytes and write them to the Writer.
    ///
    /// `w` should be a valid `Writer`.
    pub fn serializeToWriter(self: *const GetblocksMessage, w: anytype) !void {
        comptime {
            if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects r to have fn 'writeInt'.");
            if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects r to have fn 'writeAll'.");
        }

        try w.writeInt(i32, self.version, .little);
        const compact_hash_count = CompactSizeUint.new(self.header_hashes.len);
        try compact_hash_count.encodeToWriter(w);
        for (self.header_hashes) |header_hash| {
            try w.writeAll(&header_hash);
        }
        try w.writeAll(&self.stop_hash);
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const GetblocksMessage, allocator: std.mem.Allocator) ![]u8 {
        const serialized_len = self.hintSerializedLen();

        const ret = try allocator.alloc(u8, serialized_len);
        errdefer allocator.free(ret);

        try self.serializeToSlice(ret);

        return ret;
    }

    /// Serialize a message as bytes and write them to the buffer.
    ///
    /// buffer.len must be >= than self.hintSerializedLen()
    pub fn serializeToSlice(self: *const GetblocksMessage, buffer: []u8) !void {
        var fbs = std.io.fixedBufferStream(buffer);
        const writer = fbs.writer();
        try self.serializeToWriter(writer);
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !GetblocksMessage {
        comptime {
            if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
            if (!std.meta.hasFn(@TypeOf(r), "readNoEof")) @compileError("Expects r to have fn 'readNoEof'.");
        }

        var gb: GetblocksMessage = undefined;

        gb.version = try r.readInt(i32, .little);

        // Read CompactSize hash_count
        const compact_hash_count = try CompactSizeUint.decodeReader(r);

        // Allocate space for header_hashes based on hash_count
        const header_hashes = try allocator.alloc([32]u8, compact_hash_count.value());

        for (header_hashes) |*hash| {
            try r.readNoEof(hash);
        }
        gb.header_hashes = header_hashes;

        // Read the stop_hash (32 bytes)
        try r.readNoEof(&gb.stop_hash);
        return gb;
    }

    /// Deserialize bytes into a `GetblocksMessage`
    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !GetblocksMessage {
        var fbs = std.io.fixedBufferStream(bytes);
        const reader = fbs.reader();

        return try GetblocksMessage.deserializeReader(allocator, reader);
    }

    pub fn hintSerializedLen(self: *const GetblocksMessage) usize {
        const fixed_length = 4 + 32; // version (4 bytes) + stop_hash (32 bytes)
        const compact_hash_count_len = CompactSizeUint.new(self.header_hashes.len).hint_encoded_len();
        const header_hashes_len = self.header_hashes.len * 32; // hash (32 bytes)
        return fixed_length + compact_hash_count_len + header_hashes_len;
    }

    pub fn eql(self: *const GetblocksMessage, other: *const GetblocksMessage) bool {
        if (self.version != other.version or self.header_hashes.len != other.header_hashes.len) {
            return false;
        }

        if (self.header_hashes.len != other.header_hashes.len) {
            return false;
        }

        for (0..self.header_hashes.len) |i| {
            if (!std.mem.eql(u8, self.header_hashes[i][0..], other.header_hashes[i][0..])) {
                return false;
            }
        }

        if (!std.mem.eql(u8, &self.stop_hash, &other.stop_hash)) {
            return false;
        }

        return true;
    }
};

// TESTS

test "ok_full_flow_GetBlocksMessage" {
    const allocator = std.testing.allocator;

    // With some header_hashes
    {

        const gb = GetblocksMessage{
            .version = 42,
            .header_hashes = try allocator.alloc([32]u8, 2),
            .stop_hash = [_]u8{0} ** 32,
        };

        defer allocator.free(gb.header_hashes);

        // Fill in the header_hashes
        for (gb.header_hashes) |*hash| {
            for (hash) |*byte| {
                byte.* = 0xab;
            }
        }

        const payload = try gb.serialize(allocator);
        defer allocator.free(payload);

        const deserialized_gb = try GetblocksMessage.deserializeSlice(allocator, payload);

        try std.testing.expect(gb.eql(&deserialized_gb));
        defer allocator.free(deserialized_gb.header_hashes);

    }

}
