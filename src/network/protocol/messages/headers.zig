const std = @import("std");
const protocol = @import("../lib.zig");
const genericChecksum = @import("lib.zig").genericChecksum;

const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;

const BlockHeader = @import("../../../types/lib.zig").BlockHeader;

/// HeadersMessage represents the "headers" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#headers
pub const HeadersMessage = struct {
    headers: []BlockHeader,

    const Self = @This();

    pub inline fn name() *const [12]u8 {
        return protocol.CommandNames.HEADERS ++ [_]u8{0} ** 5;
    }

    pub fn checksum(self: HeadersMessage) [4]u8 {
        return genericChecksum(self);
    }

    pub fn deinit(self: *HeadersMessage, allocator: std.mem.Allocator) void {
        allocator.free(self.headers);
    }

    /// Serialize the message as bytes and write them to the Writer.
    ///
    /// `w` should be a valid `Writer`.
    pub fn serializeToWriter(self: *const Self, w: anytype) !void {
        comptime {
            if (!std.meta.hasFn(@TypeOf(w), "writeByte")) @compileError("Expects r to have fn 'writeByte'.");
        }
        try CompactSizeUint.new(self.headers.len).encodeToWriter(w);

        for (self.headers) |header| {
            try header.serializeToWriter(w);
            try w.writeByte(0);
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
    pub fn serialize(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        const serialized_len = self.hintSerializedLen();
        if (serialized_len != 0) {
            const ret = try allocator.alloc(u8, serialized_len);
            errdefer allocator.free(ret);

            try self.serializeToSlice(ret);

            return ret;
        } else {
            return &.{};
        }
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
        comptime {
            if (!std.meta.hasFn(@TypeOf(r), "readByte")) @compileError("Expects r to have fn 'readByte'.");
        }

        const headers_count = try CompactSizeUint.decodeReader(r);

        var headers = try allocator.alloc(BlockHeader, headers_count.value());
        errdefer allocator.free(headers);

        for (0..headers_count.value()) |i| {
            headers[i] = try BlockHeader.deserializeReader(r);
            _ = try r.readByte();
        }

        return Self{ .headers = headers };
    }

    /// Deserialize bytes into a `HeaderMessage`
    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
        var fbs = std.io.fixedBufferStream(bytes);
        return try Self.deserializeReader(allocator, fbs.reader());
    }

    pub fn hintSerializedLen(self: Self) usize {
        const headers_number_length = CompactSizeUint.new(self.headers.len).hint_encoded_len();
        const headers_length = self.headers.len * (BlockHeader.serializedLen() + 1);
        return headers_number_length + headers_length;
    }
};

// TESTS

test "ok_fullflow_headers_message" {
    const allocator = std.testing.allocator;

    {
        // payload example from https://developer.bitcoin.org/reference/p2p_networking.html#headers
        const payload = [_]u8{
            0x01, // header count
            // block header
            0x02, 0x00, 0x00, 0x00, // block version: 2
            0xb6, 0xff, 0x0b, 0x1b, 0x16, 0x80, 0xa2, 0x86, // hash of previous block
            0x2a, 0x30, 0xca, 0x44, 0xd3, 0x46, 0xd9, 0xe8, // hash of previous block
            0x91, 0x0d, 0x33, 0x4b, 0xeb, 0x48, 0xca, 0x0c, // hash of previous block
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // hash of previous block
            0x9d, 0x10, 0xaa, 0x52, 0xee, 0x94, 0x93, 0x86, // merkle root
            0xca, 0x93, 0x85, 0x69, 0x5f, 0x04, 0xed, 0xe2, // merkle root
            0x70, 0xdd, 0xa2, 0x08, 0x10, 0xde, 0xcd, 0x12, // merkle root
            0xbc, 0x9b, 0x04, 0x8a, 0xaa, 0xb3, 0x14, 0x71, // merkle root
            0x24, 0xd9, 0x5a, 0x54, // unix time (1415239972)
            0x30, 0xc3, 0x1b, 0x18, // bits
            0xfe, 0x9f, 0x08, 0x64, // nonce
            // end of block header
            0x00, // transaction count
        };

        var deserialized_msg = try HeadersMessage.deserializeSlice(allocator, &payload);
        defer deserialized_msg.deinit(allocator);

        const expected_block_header = BlockHeader{
            .version = 2,
            .prev_block = [_]u8{
                0xb6, 0xff, 0x0b, 0x1b, 0x16, 0x80, 0xa2, 0x86,
                0x2a, 0x30, 0xca, 0x44, 0xd3, 0x46, 0xd9, 0xe8,
                0x91, 0x0d, 0x33, 0x4b, 0xeb, 0x48, 0xca, 0x0c,
                0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            },
            .merkle_root = [_]u8{
                0x9d, 0x10, 0xaa, 0x52, 0xee, 0x94, 0x93, 0x86,
                0xca, 0x93, 0x85, 0x69, 0x5f, 0x04, 0xed, 0xe2,
                0x70, 0xdd, 0xa2, 0x08, 0x10, 0xde, 0xcd, 0x12,
                0xbc, 0x9b, 0x04, 0x8a, 0xaa, 0xb3, 0x14, 0x71,
            },
            .timestamp = 1415239972,
            .nbits = 404472624,
            .nonce = 1678286846,
        };

        try std.testing.expectEqual(1, deserialized_msg.headers.len);
        try std.testing.expect(expected_block_header.eql(&deserialized_msg.headers[0]));

        const serialized_payload = try deserialized_msg.serialize(allocator);
        defer allocator.free(serialized_payload);

        try std.testing.expect(std.mem.eql(u8, &payload, serialized_payload));
    }
}
