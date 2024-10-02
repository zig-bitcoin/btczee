const std = @import("std");
const protocol = @import("../lib.zig");

const Sha256 = std.crypto.hash.sha2.Sha256;
const BlockHeader = @import("../../../types/block_header.zig");
const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;
const genericChecksum = @import("lib.zig").genericChecksum;
/// MerkleBlockMessage represents the "MerkleBlock" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#merkleblock
pub const MerkleBlockMessage = struct {
    block_header: BlockHeader,
    transaction_count: u32,
    hashes: [][32]u8,
    flags: []u8,

    const Self = @This();

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.MERKLEBLOCK;
    }

    /// Returns the message checksum
    pub fn checksum(self: *const Self) [4]u8 {
        return genericChecksum(self);
    }

    /// Free the allocated memory
    pub fn deinit(self: *const Self, allocator: std.mem.Allocator) void {
        allocator.free(self.flags);
        allocator.free(self.hashes);
    }

    /// Serialize the message as bytes and write them to the Writer.
    pub fn serializeToWriter(self: *const Self, w: anytype) !void {
        comptime {
            if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects w to have fn 'writeInt'.");
            if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects w to have fn 'writeAll'.");
        }
        try self.block_header.serializeToWriter(w);
        try w.writeInt(u32, self.transaction_count, .little);
        const hash_count = CompactSizeUint.new(self.hashes.len);
        try hash_count.encodeToWriter(w);

        for (self.hashes) |*hash| {
            try w.writeAll(hash);
        }
        const flag_bytes = CompactSizeUint.new(self.flags.len);

        try flag_bytes.encodeToWriter(w);
        try w.writeAll(self.flags);
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

    /// Returns the hint of the serialized length of the message.
    pub fn hintSerializedLen(self: *const Self) usize {
        // 80 bytes for the block header, 4 bytes for the transaction count
        const fixed_length = 84;
        const hash_count_len: usize = CompactSizeUint.new(self.hashes.len).hint_encoded_len();
        const compact_hashes_len = 32 * self.hashes.len;
        const flag_bytes_len: usize = CompactSizeUint.new(self.flags.len).hint_encoded_len();
        const flags_len = self.flags.len;
        const variable_length = hash_count_len + compact_hashes_len + flag_bytes_len + flags_len;
        return fixed_length + variable_length;
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
        comptime {
            if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
            if (!std.meta.hasFn(@TypeOf(r), "readNoEof")) @compileError("Expects r to have fn 'readNoEof'.");
        }

        var merkle_block_message: Self = undefined;
        merkle_block_message.block_header = try BlockHeader.deserializeReader(r);
        merkle_block_message.transaction_count = try r.readInt(u32, .little);

        // Read CompactSize hash_count
        const hash_count = try CompactSizeUint.decodeReader(r);
        merkle_block_message.hashes = try allocator.alloc([32]u8, hash_count.value());
        errdefer allocator.free(merkle_block_message.hashes);

        for (merkle_block_message.hashes) |*hash| {
            try r.readNoEof(hash);
        }

        // Read CompactSize flags_count
        const flags_count = try CompactSizeUint.decodeReader(r);
        merkle_block_message.flags = try allocator.alloc(u8, flags_count.value());
        errdefer allocator.free(merkle_block_message.flags);

        try r.readNoEof(merkle_block_message.flags);
        return merkle_block_message;
    }

    /// Deserialize bytes into a `MerkleBlockMessage`
    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
        var fbs = std.io.fixedBufferStream(bytes);
        return try Self.deserializeReader(allocator, fbs.reader());
    }

    pub fn new(block_header: BlockHeader, transaction_count: u32, hashes: [][32]u8, flags: []u8) Self {
        return .{
            .block_header = block_header,
            .transaction_count = transaction_count,
            .hashes = hashes,
            .flags = flags,
        };
    }
};

test "MerkleBlockMessage serialization and deserialization" {
    const test_allocator = std.testing.allocator;

    const block_header = BlockHeader{
        .version = 1,
        .prev_block = [_]u8{0} ** 32,
        .merkle_root = [_]u8{1} ** 32,
        .timestamp = 1234567890,
        .nbits = 0x1d00ffff,
        .nonce = 987654321,
    };
    const hashes = try test_allocator.alloc([32]u8, 3);

    const flags = try test_allocator.alloc(u8, 1);
    const transaction_count = 1;
    const msg = MerkleBlockMessage.new(block_header, transaction_count, hashes, flags);

    defer msg.deinit(test_allocator);

    // Fill in the header_hashes
    for (msg.hashes) |*hash| {
        for (hash) |*byte| {
            byte.* = 0xab;
        }
    }

    flags[0] = 0x1;

    const serialized = try msg.serialize(test_allocator);
    defer test_allocator.free(serialized);

    const deserialized = try MerkleBlockMessage.deserializeSlice(test_allocator, serialized);
    defer deserialized.deinit(test_allocator);

    try std.testing.expectEqual(msg.block_header, deserialized.block_header);
    try std.testing.expectEqual(msg.transaction_count, deserialized.transaction_count);
    try std.testing.expectEqualSlices([32]u8, msg.hashes, deserialized.hashes);
    try std.testing.expectEqualSlices(u8, msg.flags, deserialized.flags);

    try std.testing.expectEqual(msg.hintSerializedLen(), 84 + 1 + 32 * 3 + 1 + 1);
}
