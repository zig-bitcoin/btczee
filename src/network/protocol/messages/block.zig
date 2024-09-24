const std = @import("std");
const native_endian = @import("builtin").target.cpu.arch.endian();
const protocol = @import("../lib.zig");

const ServiceFlags = protocol.ServiceFlags;

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
    txn_count: CompactSizeUint,
    txns: std.ArrayList(Transaction),

    const Self = @This();

    pub inline fn name() *const [12]u8 {
        return protocol.CommandNames.BLOCK ++ [_]u8{0} ** 8;
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

    pub fn deinit(self: *const Self, allocator: std.mem.Allocator) void {
        _ = allocator;
        self.deinit();
    }

    /// Serialize the message as bytes and write them to the Writer.
    ///
    /// `w` should be a valid `Writer`.
    pub fn serializeToWriter(self: *const Self, w: anytype) !void {
        comptime {
            if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects r to have fn 'writeInt'.");
            if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects r to have fn 'writeAll'.");
        }

        try w.writeInt(i32, self.block_header.version, .little);
        try w.writeAll(self.block_header.prev_block[0..32]);
        try w.writeAll(self.block_header.merkle_root[0..32]);
        try w.writeInt(i32, self.block_header.timestamp, .little);
        try w.writeInt(i32, self.block_header.nbits, .little);
        try w.writeInt(i32, self.block_header.nonce, .little);

        const compact_tx_count = CompactSizeUint.new(self.txns.len);
        try compact_tx_count.encodeToWriter(w);

        for (self.txns) |txn| {
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

        var bm: Self = undefined;

        bm.block_header.version = try r.readInt(i32, .little);
        bm.block_header.prev_block = try allocator.alloc(u8, 32);
        errdefer allocator.free(bm.block_header.prev_block);
        try r.readNoEof(bm.block_header.prev_block);

        bm.block_header.merkle_root = try allocator.alloc(u8, 32);
        errdefer allocator.free(bm.block_header.merkle_root);
        try r.readNoEof(bm.block_header.merkle_root);

        bm.block_header.timestamp = try r.readInt(i32, .little);
        bm.block_header.nbits = try r.readInt(i32, .little);
        bm.block_header.nonce = try r.readInt(i32, .little);
        bm.txn_count = (try CompactSizeUint.decodeFromReader(r)).value();

        bm.txns = std.ArrayList(Transaction).init(allocator); //try allocator.alloc(Transaction, bm.txn_count);
        errdefer bm.txns.deinit();

        while (bm.txns.len < bm.txn_count) {
            bm.txns.append(try Transaction.deserializeReader(allocator, r));
        }

        return BlockMessage{};
    }

    pub fn hintSerializedLen(self: BlockMessage) usize {
        const header_length = @sizeOf(BlockHeader);
        const txs_number_length = @sizeOf(CompactSizeUint);
        var txs_length: usize = 0;
        for (self.txns) |txn| {
            txs_length += txn.virtual_size();
        }
        return header_length + txs_number_length + txs_length;
    }
};

// TESTS

test "ok_full_flow_BlockMessage" {
    const allocator = std.testing.allocator;

    {
        const msg = BlockMessage{};

        const payload = try msg.serialize(allocator);
        defer allocator.free(payload);
        const deserialized_msg = try BlockMessage.deserializeReader(allocator, payload);
        _ = deserialized_msg;

        try std.testing.expect(payload.len == 0);
    }
}
