const std = @import("std");
const protocol = @import("../lib.zig");

const Sha256 = std.crypto.hash.sha2.Sha256;
const BlockHeader = @import("../../../types/block_header.zig");
const Transaction = @import("../../../types/transaction.zig");
const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;
const genericChecksum = @import("lib.zig").genericChecksum;
const genericDeserializeSlice = @import("lib.zig").genericDeserializeSlice;
const genericSerialize = @import("lib.zig").genericSerialize;

/// BlockTxnMessage represents the "BlockTxn" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#blocktxn
pub const BlockTxnMessage = struct {
    block_hash: [32]u8,
    transactions: []Transaction,

    const Self = @This();

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.BLOCKTXN ++ [_]u8{0} ** 4;
    }

    /// Returns the message checksum
    pub fn checksum(self: *const Self) [4]u8 {
        return genericChecksum(self);
    }

    /// Free the allocated memory
    pub fn deinit(self: *const Self, allocator: std.mem.Allocator) void {
        allocator.free(self.transactions);
    }

    /// Serialize the message as bytes and write them to the Writer.
    pub fn serializeToWriter(self: *const Self, w: anytype) !void {
        comptime {
            if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects r to have fn 'writeInt'.");
            if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects r to have fn 'writeAll'.");
        }
        try w.writeAll(&self.block_hash);
        const indexes_count = CompactSizeUint.new(self.transactions.len);
        try indexes_count.encodeToWriter(w);
        for (self.transactions) |*index| {
            try index.encodeToWriter(w);
        }
    }
    /// Serialize a message as bytes and write them to the buffer.
    ///
    /// buffer.len must be >= than self.hintSerializedLen()
    pub fn serializeToSlice(self: *const Self, buffer: []u8) !void {
        var fbs = std.io.fixedBufferStream(buffer);
        try self.serializeToWriter(fbs.writer());
    }

    /// Returns the hint of the serialized length of the message.
    pub fn hintSerializedLen(self: *const Self) usize {
        // 32 bytes for the block hash
        const fixed_length = 32;

        const indexes_count_length: usize = CompactSizeUint.new(self.transactions.len).hint_encoded_len();

        var compact_indexes_length: usize = 0;
        for (self.transactions) |index| {
            compact_indexes_length += index.hint_encoded_len();
        }

        const variable_length = indexes_count_length + compact_indexes_length;

        return fixed_length + variable_length;
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
        var blocktxn_message: Self = undefined;
        try r.readNoEof(&blocktxn_message.block_hash);

        const indexes_count = try Transaction.deserializeReader(allocator, r);
        blocktxn_message.transactions = try allocator.alloc(Transaction, indexes_count.value());
        errdefer allocator.free(blocktxn_message.transactions);

        for (blocktxn_message.transactions) |*index| {
            index.* = try Transaction.deserializeReader(allocator, r);
        }

        return blocktxn_message;
    }

    pub fn new(block_hash: [32]u8, transactions: []Transaction) Self {
        return .{
            .block_hash = block_hash,
            .transactions = transactions,
        };
    }
};

test "BlockTxnMessage serialization and deserialization" {
    const test_allocator = std.testing.allocator;

    const block_hash: [32]u8 = [_]u8{0} ** 32;
    const transaction = try test_allocator.alloc(Transaction, 1);
    transaction[0] = Transaction.init(test_allocator);
    const msg = BlockTxnMessage.new(block_hash, transaction);

    defer msg.deinit(test_allocator);

    const serialized = try msg.genericSerialize(test_allocator);
    defer test_allocator.free(serialized);

    const deserialized = try BlockTxnMessage.genericDeserializeSlice(test_allocator, serialized);
    defer deserialized.deinit(test_allocator);

    try std.testing.expectEqual(msg.block_hash, deserialized.block_hash);
    try std.testing.expectEqual(msg.transaction[0].value(), msg.transaction[0].value());
    try std.testing.expectEqual(msg.hintSerializedLen(), 32 + 1 + 1);
}
