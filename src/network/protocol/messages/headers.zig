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
            if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects r to have fn 'writeInt'.");
            if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects r to have fn 'writeAll'.");
            if (!std.meta.hasFn(@TypeOf(w), "writeByte")) @compileError("Expects r to have fn 'writeByte'.");
        }
        if (self.headers.len != 0) {
            try CompactSizeUint.new(self.headers.len).encodeToWriter(w);

            for (self.headers) |header| {
                try header.serializeToWriter(w);
                try w.writeByte(0);
            }
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
            if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
            if (!std.meta.hasFn(@TypeOf(r), "readNoEof")) @compileError("Expects r to have fn 'readNoEof'.");
            if (!std.meta.hasFn(@TypeOf(r), "readAll")) @compileError("Expects r to have fn 'readAll'.");
            if (!std.meta.hasFn(@TypeOf(r), "readByte")) @compileError("Expects r to have fn 'readByte'.");
        }

        var headers_message: Self = undefined;

        const headers_count = try CompactSizeUint.decodeReader(r);

        headers_message.headers = try allocator.alloc(BlockHeader, headers_count.value());
        errdefer allocator.free(headers_message.headers);

        var i: usize = 0;
        while (i < headers_count.value()) : (i += 1) {
            const header = try BlockHeader.deserializeReader(allocator, r);
            headers_message.headers[i] = header;
            _ = r.readByte();
        }

        return headers_message;
    }

    /// Deserialize bytes into a `HeaderMessage`
    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
        var fbs = std.io.fixedBufferStream(bytes);
        return try Self.deserializeReader(allocator, fbs.reader());
    }

    pub fn hintSerializedLen(self: Self) usize {
        if (self.headers.len != 0) {
            const headers_number_length = CompactSizeUint.new(self.headers.len).hint_encoded_len();
            var headers_length: usize = 0;
            for (self.headers) |_| {
                headers_length += BlockHeader.serializedLen();
                headers_length += 1; // 0 transactions
            }
            return headers_number_length + headers_length;
        } else {
            return 0;
        }
    }
};
