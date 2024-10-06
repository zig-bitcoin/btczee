const std = @import("std");
const native_endian = @import("builtin").target.cpu.arch.endian();
const protocol = @import("../lib.zig");
const genericChecksum = @import("lib.zig").genericChecksum;
const genericSerialize = @import("lib.zig").genericSerialize;
const genericDeserializeSlice = @import("lib.zig").genericDeserializeSlice;

const ServiceFlags = protocol.ServiceFlags;

const readBytesExact = @import("../../../util/mem/read.zig").readBytesExact;

const Endian = std.builtin.Endian;
const Sha256 = std.crypto.hash.sha2.Sha256;

const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;
const Types = @import("../../../types/lib.zig");
const Transaction = Types.Transaction;
const BlockHeader = Types.BlockHeader;

/// BlockMessage represents the "block" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#block
pub const BlockMessage = struct {
    block_header: BlockHeader,
    txns: []Transaction,

    const Self = @This();

    pub inline fn name() *const [12]u8 {
        return protocol.CommandNames.BLOCK ++ [_]u8{0} ** 7;
    }

    pub fn checksum(self: BlockMessage) [4]u8 {
        return genericChecksum(self);
    }

    pub fn deinit(self: *BlockMessage, allocator: std.mem.Allocator) void {
        for (self.txns) |*txn| {
            txn.deinit();
        }
        allocator.free(self.txns);
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

        try CompactSizeUint.new(self.txns.len).encodeToWriter(w);

        for (self.txns) |txn| {
            try txn.serializeToWriter(w);
        }
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const BlockMessage, allocator: std.mem.Allocator) ![]u8 {
        return genericSerialize(self, allocator);
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !BlockMessage {
        comptime {
            if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
            if (!std.meta.hasFn(@TypeOf(r), "readNoEof")) @compileError("Expects r to have fn 'readNoEof'.");
            if (!std.meta.hasFn(@TypeOf(r), "readAll")) @compileError("Expects r to have fn 'readAll'.");
            if (!std.meta.hasFn(@TypeOf(r), "readByte")) @compileError("Expects r to have fn 'readByte'.");
        }

        var block_message: Self = undefined;

        block_message.block_header = try BlockHeader.deserializeReader(r);

        const txns_count = try CompactSizeUint.decodeReader(r);

        block_message.txns = try allocator.alloc(Transaction, txns_count.value());
        errdefer allocator.free(block_message.txns);

        var i: usize = 0;
        while (i < txns_count.value()) : (i += 1) {
            const tx = try Transaction.deserializeReader(allocator, r);
            block_message.txns[i] = tx;
        }

        return block_message;
    }

    /// Deserialize bytes into a `VersionMessage`
    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
        return genericDeserializeSlice(Self, allocator, bytes);
    }

    pub fn hintSerializedLen(self: BlockMessage) usize {
        const header_length = BlockHeader.serializedLen();
        const txs_number_length = CompactSizeUint.new(self.txns.len).hint_encoded_len();
        var txs_length: usize = 0;
        for (self.txns) |txn| {
            txs_length += txn.hintEncodedLen();
        }
        return header_length + txs_number_length + txs_length;
    }
};

// TESTS
test "ok_full_flow_BlockMessage" {
    const OpCode = @import("../../../script/opcodes/constant.zig").Opcode;
    const allocator = std.testing.allocator;
    const OutPoint = Types.OutPoint;
    const Hash = Types.Hash;
    const Script = Types.Script;

    {
        var tx = try Transaction.init(allocator);

        try tx.addInput(OutPoint{ .hash = Hash.newZeroed(), .index = 0 });

        {
            var script_pubkey = try Script.init(allocator);
            defer script_pubkey.deinit();
            try script_pubkey.push(&[_]u8{ OpCode.OP_DUP.toBytes(), OpCode.OP_0.toBytes(), OpCode.OP_1.toBytes() });
            try tx.addOutput(50000, script_pubkey);
        }

        var txns = try allocator.alloc(Transaction, 1);
        // errdefer allocator.free(txns);
        txns[0] = tx;

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

        for (msg.txns, 0..) |txn, i| {
            const deserialized_txn = deserialized_msg.txns[i];
            try std.testing.expect(txn.eql(deserialized_txn));
        }
    }
}
