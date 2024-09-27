const std = @import("std");
const readBytesExact = @import("../util/mem/read.zig").readBytesExact;

/// A bitcoin block with additonal usefull data
pub const Block = struct {
    hash: [32]u8,
    height: i32,

    pub fn serizalize(self: *Block, allocator: std.mem.Allocator) ![]u8 {
        _ = self;
        const ret = try allocator.alloc(u8, 0);
        return ret;
    }
};

pub const BlockHeader = struct {
    version: i32,
    prev_block: [32]u8,
    merkle_root: [32]u8,
    timestamp: i32,
    nbits: i32,
    nonce: i32,

    const Self = @This();

    pub fn serializeToWriter(self: *const Self, w: anytype) !void {
        comptime {
            if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects r to have fn 'writeInt'.");
            if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects r to have fn 'writeAll'.");
        }

        try w.writeInt(i32, self.version, .little);
        try w.writeAll(&self.prev_block);
        try w.writeAll(&self.merkle_root);
        try w.writeInt(i32, self.timestamp, .little);
        try w.writeInt(i32, self.nbits, .little);
        try w.writeInt(i32, self.nonce, .little);
    }

    /// Serialize a header as bytes and write them to the buffer.
    ///
    /// buffer.len must be >= than self
    pub fn serializeToSlice(self: *const Self, buffer: []u8) !void {
        var fbs = std.io.fixedBufferStream(buffer);
        try self.serializeToWriter(fbs.writer());
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        const serialized_len = @sizeOf(self);

        const ret = try allocator.alloc(u8, serialized_len);
        errdefer allocator.free(ret);

        try self.serializeToSlice(ret);

        return ret;
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
        comptime {
            if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
            if (!std.meta.hasFn(@TypeOf(r), "read")) @compileError("Expects r to have fn 'read'.");
        }

        var header: Self = undefined;

        header.version = try r.readInt(i32, .little);
        const raw_prev_block = (try readBytesExact(allocator, r, 32))[0..32];
        defer allocator.free(raw_prev_block);
        @memcpy(&header.prev_block, raw_prev_block);

        const raw_merkle_root = (try readBytesExact(allocator, r, 32))[0..32];
        defer allocator.free(raw_merkle_root);
        @memcpy(&header.merkle_root, raw_merkle_root);
        header.timestamp = try r.readInt(i32, .little);

        header.nbits = try r.readInt(i32, .little);
        header.nonce = try r.readInt(i32, .little);

        return header;
    }

    /// Deserialize bytes into a `VersionMessage`
    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
        var fbs = std.io.fixedBufferStream(bytes);
        return try Self.deserializeReader(allocator, fbs.reader());
    }
};
