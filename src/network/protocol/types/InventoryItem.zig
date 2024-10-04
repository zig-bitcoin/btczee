const std = @import("std");

type: u32,
hash: [32]u8,

pub fn encodeToWriter(self: *const @This(), w: anytype) !void {
    comptime {
        if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects r to have fn 'writeInt'.");
        if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects r to have fn 'writeAll'.");
    }
    try w.writeInt(u32, self.type, .little);
    try w.writeAll(&self.hash);
}

pub fn decodeReader(r: anytype) !@This() {
    comptime {
        if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects reader to have fn 'readInt'.");
        if (!std.meta.hasFn(@TypeOf(r), "readNoEof")) @compileError("Expects reader to have fn 'readNoEof'.");
    }

    const item_type = try r.readInt(u32, .little);
    var hash: [32]u8 = undefined;
    try r.readNoEof(&hash);

    return @This(){
        .type = item_type,
        .hash = hash,
    };
}

pub fn eql(self: *const @This(), other: *const @This()) bool {
    return self.type == other.type and std.mem.eql(u8, &self.hash, &other.hash);
}