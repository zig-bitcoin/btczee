const std = @import("std");
const protocol = @import("../lib.zig");
const Transaction = @import("../../../types/Transaction.zig");

const Sha256 = std.crypto.hash.sha2.Sha256;
const BlockHeader = @import("../../../types/block_header.zig");
const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;
const genericChecksum = @import("lib.zig").genericChecksum;

pub const CmpctBlockMessage = struct {
    header: BlockHeader,
    nonce: u64,
    short_ids: []u64,
    prefilled_txns: []PrefilledTransaction,

    const Self = @This();

    pub const PrefilledTransaction = struct {
        index: usize,
        tx: Transaction,
    };

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.CMPCTBLOCK;
    }

    pub fn checksum(self: *const Self) [4]u8 {
        return genericChecksum(self);
    }

    pub fn deinit(self: *const Self, allocator: std.mem.Allocator) void {
        allocator.free(self.short_ids);
        for (self.prefilled_txns) |txn| {
            allocator.free(txn.tx);
        }
        allocator.free(self.prefilled_txns);
    }

    pub fn serializeToWriter(self: *const Self, w: anytype) !void {
        try self.header.serializeToWriter(w);
        try w.writeInt(u64, self.nonce, .little);

        const short_ids_count = CompactSizeUint.new(self.short_ids.len);
        try short_ids_count.encodeToWriter(w);
        for (self.short_ids) |id| {
            try w.writeInt(u64, id, .little);
        }

        const prefilled_txns_count = CompactSizeUint.new(self.prefilled_txns.len);
        try prefilled_txns_count.encodeToWriter(w);
        for (self.prefilled_txns) |txn| {
            try txn.index.encodeToWriter(w);
            const tx_size = CompactSizeUint.new(txn.tx.len);
            try tx_size.encodeToWriter(w);
            try w.writeAll(txn.tx);
        }
    }

    pub fn serializeToSlice(self: *const Self, buffer: []u8) !void {
        var fbs = std.io.fixedBufferStream(buffer);
        try self.serializeToWriter(fbs.writer());
    }

    pub fn serialize(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        const serialized_len = self.hintSerializedLen();
        const ret = try allocator.alloc(u8, serialized_len);
        errdefer allocator.free(ret);

        try self.serializeToSlice(ret);

        return ret;
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
        var cmpct_block_message: Self = undefined;
        cmpct_block_message.header = try BlockHeader.deserializeReader(r);
        cmpct_block_message.nonce = try r.readInt(u64, .little);

        const short_ids_count = try CompactSizeUint.decodeReader(r);
        cmpct_block_message.short_ids = try allocator.alloc(u64, short_ids_count.value());
        errdefer allocator.free(cmpct_block_message.short_ids);

        for (cmpct_block_message.short_ids) |*id| {
            id.* = try r.readInt(u64, .little);
        }

        const prefilled_txns_count = try CompactSizeUint.decodeReader(r);
        cmpct_block_message.prefilled_txns = try allocator.alloc(PrefilledTransaction, prefilled_txns_count.value());
        errdefer allocator.free(cmpct_block_message.prefilled_txns);

        for (cmpct_block_message.prefilled_txns) |*txn| {
            txn.index = try CompactSizeUint.decodeReader(r);
            const tx_size = try CompactSizeUint.decodeReader(r);
            txn.tx = try allocator.alloc(u8, tx_size.value());
            errdefer allocator.free(txn.tx);
            try r.readNoEof(txn.tx);
        }

        return cmpct_block_message;
    }

    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
        var fbs = std.io.fixedBufferStream(bytes);
        return try Self.deserializeReader(allocator, fbs.reader());
    }

    pub fn hintSerializedLen(self: *const Self) usize {
        var len: usize = 80 + 8; // BlockHeader + nonce
        len += CompactSizeUint.new(self.short_ids.len).hint_encoded_len();
        len += self.short_ids.len * 8;
        len += CompactSizeUint.new(self.prefilled_txns.len).hint_encoded_len();
        for (self.prefilled_txns) |txn| {
            len += txn.index.hint_encoded_len();
            len += CompactSizeUint.new(txn.tx.len).hint_encoded_len();
            len += txn.tx.len;
        }
        return len;
    }
};

test "CmpctBlockMessage serialization and deserialization" {
    const test_allocator = std.testing.allocator;

    const block_header = BlockHeader{
        .version = 1,
        .prev_block = [_]u8{0} ** 32,
        .merkle_root = [_]u8{1} ** 32,
        .timestamp = 1234567890,
        .bits = 0x1d00ffff,
        .nonce = 987654321,
    };

    const short_ids = try test_allocator.alloc(u64, 2);
    defer test_allocator.free(short_ids);
    short_ids[0] = 123456;
    short_ids[1] = 789012;

    const prefilled_txns = try test_allocator.alloc(CmpctBlockMessage.PrefilledTransaction, 1);
    defer test_allocator.free(prefilled_txns);
    prefilled_txns[0] = .{
        .index = CompactSizeUint.new(0),
        .tx = try test_allocator.dupe(u8, &[_]u8{ 0xde, 0xad, 0xbe, 0xef }),
    };
    defer test_allocator.free(prefilled_txns[0].tx);

    const msg = CmpctBlockMessage{
        .header = block_header,
        .nonce = 1122334455,
        .short_ids = short_ids,
        .prefilled_txns = prefilled_txns,
    };

    const serialized = try msg.serialize(test_allocator);
    defer test_allocator.free(serialized);

    const deserialized = try CmpctBlockMessage.deserializeSlice(test_allocator, serialized);
    defer deserialized.deinit(test_allocator);

    try std.testing.expectEqual(msg.header, deserialized.header);
    try std.testing.expectEqual(msg.nonce, deserialized.nonce);
    try std.testing.expectEqualSlices(u64, msg.short_ids, deserialized.short_ids);
    try std.testing.expectEqual(msg.prefilled_txns.len, deserialized.prefilled_txns.len);
    try std.testing.expectEqual(msg.prefilled_txns[0].index.value(), deserialized.prefilled_txns[0].index.value());
    try std.testing.expectEqualSlices(u8, msg.prefilled_txns[0].tx, deserialized.prefilled_txns[0].tx);
}
