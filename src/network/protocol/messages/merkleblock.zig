const std = @import("std");
const native_endian = @import("builtin").target.cpu.arch.endian();
const protocol = @import("../lib.zig");

const ServiceFlags = protocol.ServiceFlags;

const Endian = std.builtin.Endian;
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
    hashes: []const []u8,
    flag_bytes: CompactSizeUint,
    flags: []u8,

    const Self = @This();

    pub inline fn name() *const [12]u8 {
        return protocol.CommandNames.MERKLEBLOCK ++ [_]u8{0} ** 5;
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

    /// Free the `user_agent` if there is one
    pub fn deinit(self: *const Self, allocator: std.mem.Allocator) void {
        allocator.free(self.flags);
        allocator.free(self.hashes);
        allocator.free(self.hash_count);
        allocator.free(self.flag_bytes);
    }

    /// Serialize the message as bytes and write them to the Writer.
    ///
    /// `w` should be a valid `Writer`.
    pub fn serializeToWriter(self: *const Self, w: anytype) !void {
        comptime {
            if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects r to have fn 'writeInt'.");
            if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects r to have fn 'writeAll'.");
        }

        const hash_count: usize = if (self.hashes) |ua|
            ua.len
        else
            0;
        const compact_hash_count = CompactSizeUint.new(hash_count);

        self.block_header.serializeToWriter(w);

        try compact_hash_count.encodeToWriter(w);
        if (hash_count != 0) {
            try w.writeAll(self.hashes.?);
        }

        const flag_bytes_len: usize = if (self.flags) |ua|
            ua.len
        else
            0;
        const compact_flag_bytes = CompactSizeUint.new(flag_bytes_len);

        try compact_flag_bytes.encodeToWriter(w);
        if (flag_bytes_len != 0) {
            try w.writeAll(self.flags.?);
        }

        return void;
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

    /// Deserialize a Reader bytes as a `VersionMessage`
    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
        comptime {
            if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
            if (!std.meta.hasFn(@TypeOf(r), "readNoEof")) @compileError("Expects r to have fn 'readNoEof'.");
            if (!std.meta.hasFn(@TypeOf(r), "readAll")) @compileError("Expects r to have fn 'readAll'.");
            if (!std.meta.hasFn(@TypeOf(r), "readByte")) @compileError("Expects r to have fn 'readByte'.");
        }

        var mb: Self = undefined;
        mb.block_header = try BlockHeader.deserializeReader(r);
        mb.transaction_count = try r.readInt(u32, .little);
        mb.hash_count = try CompactSizeUint.decodeReader(r);
        const hashes = try allocator.alloc([32]u8, mb.hash_count.value());
        for (hashes) |h| {
            try r.readNoEof(h);
        }

        mb.flag_bytes = try CompactSizeUint.decodeReader(r);
        const flags = try allocator.alloc(u8, mb.flag_bytes.value());
        try r.readNoEof(flags);
        mb.flags = flags;

        return mb;
    }

    /// Deserialize bytes into a `MerkleBlockMessage`
    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
        var fbs = std.io.fixedBufferStream(bytes);
        return try Self.deserializeReader(allocator, fbs.reader());
    }

    pub fn hintSerializedLen(self: *const Self) usize {
        // 80 bytes for the block header, 4 bytes for the transaction count
        const fixed_length = 84;

        const hash_count_len: usize = self.hash_count.hint_encoded_len();
        const compact_hashes_len = if (self.hashes) |h| h.len * 32 else 0;
        const flags_byte_ken: usize = self.flag_bytes.hint_encoded_len();
        const flags_len = if (self.flags) |f| f.len else 0;
        const variable_length = hash_count_len + compact_hashes_len + flags_byte_ken + flags_len;

        return fixed_length + variable_length;
    }

    pub fn new(block_header: BlockHeader, transaction_count: u32, hashes: [][32]u8, flags: []u8) Self {
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

// TESTS
test "ok_full_flow_MerkleBlockMessage" {
    const allocator = std.testing.allocator;

    {
        const block_header = BlockHeader{
            .version = 1,
            .prev_block = undefined,
            .merkle_root = undefined,
            .timestamp = 1,
            .bits = 1,
            .nonce = 1,
        };
        const hashes: [][32]u8 = &[_][32]u8{
            [_]u8{0} ** 32,
            [_]u8{1} ** 32,
        };

        const flags = [_]u8{0} ** 1;
        const msg = MerkleBlockMessage.new(block_header, 1, hashes, &flags);

        const payload = try msg.serialize(allocator);
        defer allocator.free(payload);
        const deserialized_msg = try MerkleBlockMessage.deserializeReader(allocator, payload);
        _ = deserialized_msg;

        try std.testing.expect(payload.len == 11);
    }
}
