const std = @import("std");
const Hash = @import("hash.zig");
const readBytesExact = @import("../util/mem/read.zig").readBytesExact;

hash: Hash,
index: u32,

const Self = @This();

pub fn serializeToWriter(self: *const Self, w: anytype) !void {
    comptime {
        if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects w to have field 'writeInt'.");
        if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects w to have field 'writeAll'.");
    }

    try w.writeAll(&self.hash.bytes);
    try w.writeInt(u32, self.index, .little);
}

pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
    comptime {
        if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
        if (!std.meta.hasFn(@TypeOf(r), "readNoEof")) @compileError("Expects r to have fn 'readNoEof'.");
        if (!std.meta.hasFn(@TypeOf(r), "readAll")) @compileError("Expects r to have fn 'readAll'.");
        if (!std.meta.hasFn(@TypeOf(r), "readByte")) @compileError("Expects r to have fn 'readByte'.");
    }

    var outpoint: Self = undefined;

    const hash_raw_bytes = try readBytesExact(allocator, r, 32);
    defer allocator.free(hash_raw_bytes);
    @memcpy(&outpoint.hash.bytes, hash_raw_bytes);

    outpoint.index = try r.readInt(u32, .little);

    return outpoint;
}
