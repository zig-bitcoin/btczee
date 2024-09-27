const std = @import("std");
const native_endian = @import("builtin").target.cpu.arch.endian();
const protocol = @import("../lib.zig");

const ServiceFlags = protocol.ServiceFlags;

const readBytesExact = @import("../../../util/mem/read.zig").readBytesExact;

const Endian = std.builtin.Endian;
const Sha256 = std.crypto.hash.sha2.Sha256;

const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;
const BlockHeader = @import("../../../types/block.zig").BlockHeader;
const Transaction = @import("../../../types/transaction.zig").Transaction;

/// BlockMessage represents the "block" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#block
pub const BlockMessage = struct {
    block_header: BlockHeader,
    txns: std.ArrayList(Transaction),

    const Self = @This();

    pub inline fn name() *const [12]u8 {
        return protocol.CommandNames.BLOCK ++ [_]u8{0} ** 7;
    }

    pub fn checksum(self: BlockMessage) [4]u8 {
        var digest: [32]u8 = undefined;
        var hasher = Sha256.init(.{});
        const writer = hasher.writer();
        self.serializeToWriter(writer) catch unreachable; // Sha256.write is infaible
        hasher.final(&digest);

        Sha256.hash(&digest, &digest, .{});

        return digest[0..4].*;
    }

    pub fn deinit(self: *BlockMessage, allocator: std.mem.Allocator) void {
        _ = allocator;
        for (self.txns.items) |*txn| {
            txn.deinit();
        }
        self.txns.deinit();
    }

    /// Serialize the message as bytes and write them to the Writer.
    ///
    /// `w` should be a valid `Writer`.
    pub fn serializeToWriter(self: *const Self, w: anytype) !void {
        comptime {
            if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects r to have fn 'writeInt'.");
            if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects r to have fn 'writeAll'.");
        }

        try self.block_header.serializeToWriter(w);

        try CompactSizeUint.new(self.txns.items.len).encodeToWriter(w);
        // try .encodeToWriter(w);

        for (self.txns.items) |txn| {
            try txn.serializeToWriter(w);
        }
    }

    /// Serialize a message as bytes and write them to the buffer.
    ///
    /// buffer.len must be >= than self.hintSerializedLen()
    pub fn serializeToSlice(self: *const Self, buffer: []u8) !void {
        var fbs = std.io.fixedBufferStream(buffer);
        try self.serializeToWriter(fbs.writer());
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const BlockMessage, allocator: std.mem.Allocator) ![]u8 {
        const serialized_len = self.hintSerializedLen();

        const ret = try allocator.alloc(u8, serialized_len);
        errdefer allocator.free(ret);

        try self.serializeToSlice(ret);

        return ret;
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !BlockMessage {
        comptime {
            if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
            if (!std.meta.hasFn(@TypeOf(r), "readNoEof")) @compileError("Expects r to have fn 'readNoEof'.");
            if (!std.meta.hasFn(@TypeOf(r), "readAll")) @compileError("Expects r to have fn 'readAll'.");
            if (!std.meta.hasFn(@TypeOf(r), "readByte")) @compileError("Expects r to have fn 'readByte'.");
        }

        var block_message: Self = undefined;

        block_message.block_header = try BlockHeader.deserializeReader(allocator, r);

        const txns_count = try CompactSizeUint.decodeReader(r);

        block_message.txns = std.ArrayList(Transaction).init(allocator);
        errdefer block_message.txns.deinit();

        const txns_count_u32 = txns_count.value();
        while (block_message.txns.items.len < txns_count_u32) {
            try block_message.txns.append(try Transaction.deserializeReader(allocator, r));
        }

        return block_message;
    }

    /// Deserialize bytes into a `VersionMessage`
    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
        var fbs = std.io.fixedBufferStream(bytes);
        return try Self.deserializeReader(allocator, fbs.reader());
    }

    pub fn hintSerializedLen(self: BlockMessage) usize {
        const header_length = @sizeOf(BlockHeader);
        const txs_number_length = CompactSizeUint.new(self.txns.items.len).hint_encoded_len();
        var txs_length: usize = 0;
        for (self.txns.items) |txn| {
            txs_length += txn.virtual_size();
        }
        return header_length + txs_number_length + txs_length;
    }
};

// TESTS

test "ok_full_flow_BlockMessage" {
    const allocator = std.testing.allocator;
    const OutPoint = @import("../../../types/transaction.zig").OutPoint;
    const Hash = @import("../../../types/transaction.zig").Hash;
    const Script = @import("../../../types/transaction.zig").Script;

    {
        var tx = try Transaction.init(allocator);

        try tx.addInput(OutPoint{ .hash = Hash.zero(), .index = 0 });

        {
            var script_pubkey = try Script.init(allocator);
            defer script_pubkey.deinit();
            try script_pubkey.push(&[_]u8{ 0x76, 0xa9, 0x14 }); // OP_DUP OP_HASH160 Push14
            try tx.addOutput(50000, script_pubkey);
        }

        var txns = std.ArrayList(Transaction).init(allocator);
        try txns.append(tx);

        var msg = BlockMessage{
            .block_header = BlockHeader{
                .version = 1,
                .prev_block = [_]u8{0} ** 32,
                .merkle_root = [_]u8{0} ** 32,
                .timestamp = 1,
                .nbits = 1,
                .nonce = 1,
            },
            .txns = txns,
        };
        defer msg.deinit(allocator);

        const payload = try msg.serialize(allocator);
        defer allocator.free(payload);
        var deserialized_msg = try BlockMessage.deserializeSlice(allocator, payload);
        defer deserialized_msg.deinit(allocator);

        try std.testing.expectEqual(msg.block_header.version, deserialized_msg.block_header.version);
        try std.testing.expect(std.mem.eql(u8, &msg.block_header.prev_block, &deserialized_msg.block_header.prev_block));
        try std.testing.expect(std.mem.eql(u8, &msg.block_header.merkle_root, &deserialized_msg.block_header.merkle_root));
        try std.testing.expect(msg.block_header.timestamp == deserialized_msg.block_header.timestamp);
        try std.testing.expect(msg.block_header.nbits == deserialized_msg.block_header.nbits);
        try std.testing.expect(msg.block_header.nonce == deserialized_msg.block_header.nonce);

        for (msg.txns.items, 0..) |txn, i| {
            const deserialized_txn = deserialized_msg.txns.items[i];
            try std.testing.expect(txn.eql(deserialized_txn));
        }
    }
}
