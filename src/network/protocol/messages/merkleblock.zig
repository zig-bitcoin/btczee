const std = @import("std");
const protocol = @import("../lib.zig");

const Sha256 = std.crypto.hash.sha2.Sha256;
const BlockHeader = protocol.BlockHeader;
const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;

/// MerkleBlockMessage represents the "MerkleBlock" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#merkleblock
pub const MerkleBlockMessage = struct {
    block_header: BlockHeader,
    transaction_count: u32,
    hash_count: CompactSizeUint,
    hashes: []const [32]u8,
    flag_bytes: CompactSizeUint,
    flags: []const u8,

    const Self = @This();

    pub inline fn name() *const [12]u8 {
        return protocol.CommandNames.MERKLEBLOCK ++ [_]u8{0} ** 6;
    }

    /// Returns the message checksum
    pub fn checksum(self: *const Self) [4]u8 {
        var digest: [32]u8 = undefined;
        var hasher = Sha256.init(.{});
        self.serializeToWriter(hasher.writer()) catch unreachable;
        hasher.final(&digest);

        Sha256.hash(&digest, &digest, .{});

        return digest[0..4].*;
    }

    /// Free the allocated memory
    pub fn deinit(self: *const Self, allocator: std.mem.Allocator) void {
        allocator.free(self.flags);
        allocator.free(self.hashes);
    }

    /// Serialize the message as bytes and write them to the Writer.
    pub fn serializeToWriter(self: *const Self, w: anytype) !void {
        try self.block_header.serializeToWriter(w);
        try w.writeInt(u32, self.transaction_count, .little);
        try self.hash_count.encodeToWriter(w);
        for (self.hashes) |hash| {
            try w.writeAll(&hash);
        }
        try self.flag_bytes.encodeToWriter(w);
        try w.writeAll(self.flags);
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        var list = std.ArrayList(u8).init(allocator);
        errdefer list.deinit();
        try self.serializeToWriter(list.writer());
        return list.toOwnedSlice();
    }

    /// Returns the hint of the serialized length of the message.
    pub fn hintSerializedLen(self: *const Self) usize {
        // 80 bytes for the block header, 4 bytes for the transaction count
        const fixed_length = 84;
        const hash_count_len: usize = self.hash_count.hint_encoded_len();
        const compact_hashes_len = 32 * self.hashes.len;
        const flags_byte_ken: usize = self.flag_bytes.hint_encoded_len();
        const flags_len = self.flags.len;
        const variable_length = hash_count_len + compact_hashes_len + flags_byte_ken + flags_len;
        return fixed_length + variable_length;
    }

    /// Deserialize a `MerkleBlockMessage` from a Reader.
    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
        var mb: Self = undefined;
        mb.block_header = try BlockHeader.deserializeReader(r);
        mb.transaction_count = try r.readInt(u32, .little);
        mb.hash_count = try CompactSizeUint.decodeReader(r);

        const hash_count = mb.hash_count.value();
        const hashes = try allocator.alloc([32]u8, hash_count);
        errdefer allocator.free(hashes);

        for (hashes) |*hash| {
            try r.readNoEof(hash);
        }
        mb.hashes = hashes;

        mb.flag_bytes = try CompactSizeUint.decodeReader(r);
        const flag_count = mb.flag_bytes.value();

        const flags = try allocator.alloc(u8, flag_count);
        try r.readNoEof(flags);
        mb.flags = flags;
        return mb;
    }

    /// Deserialize bytes into a `MerkleBlockMessage`
    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
        var fbs = std.io.fixedBufferStream(bytes);
        return try Self.deserializeReader(allocator, fbs.reader());
    }

    pub fn new(block_header: BlockHeader, transaction_count: u32, hashes: []const [32]u8, flags: []const u8) Self {
        return .{
            .block_header = block_header,
            .transaction_count = transaction_count,
            .hash_count = CompactSizeUint.new(hashes.len),
            .hashes = hashes,
            .flag_bytes = CompactSizeUint.new(flags.len),
            .flags = flags,
        };
    }
};

test "MerkleBlockMessage serialization and deserialization" {
    const allocator = std.testing.allocator;

    const block_header = BlockHeader{
        .version = 1,
        .prev_block = [_]u8{0} ** 32,
        .merkle_root = [_]u8{1} ** 32,
        .timestamp = 1234567890,
        .bits = 0x1d00ffff,
        .nonce = 987654321,
    };
    const hashes = &[_][32]u8{[_]u8{2} ** 32};
    const flags = &[_]u8{0b10101010};

    const msg = MerkleBlockMessage.new(block_header, 1, hashes, flags);

    const serialized = try msg.serialize(allocator);
    defer allocator.free(serialized);

    const deserialized = try MerkleBlockMessage.deserializeSlice(allocator, serialized);
    defer deserialized.deinit(allocator);

    try std.testing.expectEqual(msg.block_header, deserialized.block_header);
    try std.testing.expectEqual(msg.transaction_count, deserialized.transaction_count);
    try std.testing.expectEqualSlices([32]u8, msg.hashes, deserialized.hashes);
    try std.testing.expectEqualSlices(u8, msg.flags, deserialized.flags);

    try std.testing.expectEqual(msg.hintSerializedLen(), 84 + 1 + 32 + 1 + 1);
}
