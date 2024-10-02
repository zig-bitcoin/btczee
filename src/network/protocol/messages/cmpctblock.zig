const std = @import("std");
const protocol = @import("../lib.zig");
const Transaction = @import("../../../types/transaction.zig");

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

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.short_ids);
        for (self.prefilled_txns) |*txn| {
            txn.tx.deinit();
        }
        allocator.free(self.prefilled_txns);
    }

    pub fn serializeToWriter(self: *const Self, w: anytype) !void {
        comptime {
            if (!@hasDecl(@TypeOf(w), "writeInt")) {
                @compileError("Writer must have a writeInt method");
            }
        }

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
            try CompactSizeUint.new(txn.index).encodeToWriter(w);
            try txn.tx.serializeToWriter(w);
        }
    }

    pub fn serializeToSlice(self: *const Self, buffer: []u8) !void {
        var fbs = std.io.fixedBufferStream(buffer);
        try self.serializeToWriter(fbs.writer());
    }

    pub fn serialize(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        const serialized_len = self.hintSerializedLen();
        if (serialized_len == 0) return &.{};
        const ret = try allocator.alloc(u8, serialized_len);
        errdefer allocator.free(ret);

        try self.serializeToSlice(ret);

        return ret;
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
        comptime {
            if (!@hasDecl(@TypeOf(r), "readInt")) {
                @compileError("Reader must have a readInt method");
            }
        }

        const header = try BlockHeader.deserializeReader(r);
        const nonce = try r.readInt(u64, .little);

        const short_ids_count = try CompactSizeUint.decodeReader(r);
        const short_ids = try allocator.alloc(u64, short_ids_count.value());
        errdefer allocator.free(short_ids);

        for (short_ids) |*id| {
            id.* = try r.readInt(u64, .little);
        }

        const prefilled_txns_count = try CompactSizeUint.decodeReader(r);
        const prefilled_txns = try allocator.alloc(PrefilledTransaction, prefilled_txns_count.value());
        errdefer allocator.free(prefilled_txns);

        for (prefilled_txns) |*txn| {
            const index = try CompactSizeUint.decodeReader(r);
            const tx = try Transaction.deserializeReader(allocator, r);

            txn.* = PrefilledTransaction{
                .index = index.value(),
                .tx = tx,
            };
        }

        return Self{
            .header = header,
            .nonce = nonce,
            .short_ids = short_ids,
            .prefilled_txns = prefilled_txns,
        };
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
            len += CompactSizeUint.new(txn.index).hint_encoded_len();
            len += txn.tx.hintEncodedLen();
        }
        return len;
    }
};

test "CmpctBlockMessage serialization and deserialization" {
    const testing = std.testing;
    const Hash = @import("../../../types/hash.zig");
    const Script = @import("../../../types/script.zig");
    const OutPoint = @import("../../../types/outpoint.zig");
    const OpCode = @import("../../../script/opcodes/constant.zig").Opcode;

    const test_allocator = testing.allocator;

    // Create a sample BlockHeader
    const header = BlockHeader{
        .version = 1,
        .prev_block = [_]u8{0} ** 32, // Zero-filled array of 32 bytes
        .merkle_root = [_]u8{0} ** 32, // Zero-filled array of 32 bytes
        .timestamp = 1631234567,
        .nbits = 0x1d00ffff,
        .nonce = 12345,
    };

    // Create sample short_ids
    const short_ids = try test_allocator.alloc(u64, 2);
    defer test_allocator.free(short_ids);
    short_ids[0] = 123456789;
    short_ids[1] = 987654321;

    // Create a sample Transaction
    var tx = try Transaction.init(test_allocator);
    defer tx.deinit();
    try tx.addInput(OutPoint{ .hash = Hash.newZeroed(), .index = 0 });
    {
        var script_pubkey = try Script.init(test_allocator);
        defer script_pubkey.deinit();
        try script_pubkey.push(&[_]u8{ OpCode.OP_DUP.toBytes(), OpCode.OP_HASH160.toBytes(), OpCode.OP_EQUALVERIFY.toBytes(), OpCode.OP_CHECKSIG.toBytes() });
        try tx.addOutput(50000, script_pubkey);
    }

    // Create sample prefilled_txns
    const prefilled_txns = try test_allocator.alloc(CmpctBlockMessage.PrefilledTransaction, 1);
    defer test_allocator.free(prefilled_txns);
    prefilled_txns[0] = .{
        .index = 0,
        .tx = tx,
    };

    // Create CmpctBlockMessage
    const msg = CmpctBlockMessage{
        .header = header,
        .nonce = 9876543210,
        .short_ids = short_ids,
        .prefilled_txns = prefilled_txns,
    };

    // Test serialization
    const serialized = try msg.serialize(test_allocator);
    defer test_allocator.free(serialized);

    // Test deserialization
    var deserialized = try CmpctBlockMessage.deserializeSlice(test_allocator, serialized);
    defer deserialized.deinit(test_allocator);

    // Verify deserialized data
    try testing.expectEqual(msg.header, deserialized.header);
    try testing.expectEqual(msg.nonce, deserialized.nonce);
    try testing.expectEqualSlices(u64, msg.short_ids, deserialized.short_ids);
    try testing.expectEqual(msg.prefilled_txns.len, deserialized.prefilled_txns.len);
    try testing.expectEqual(msg.prefilled_txns[0].index, deserialized.prefilled_txns[0].index);
    try testing.expect(msg.prefilled_txns[0].tx.eql(deserialized.prefilled_txns[0].tx));

    // Test checksum
    const checksum = msg.checksum();
    try testing.expect(checksum.len == 4);

    // Test hintSerializedLen
    const hint_len = msg.hintSerializedLen();
    try testing.expect(hint_len > 0);
    try testing.expect(hint_len >= serialized.len);
}
