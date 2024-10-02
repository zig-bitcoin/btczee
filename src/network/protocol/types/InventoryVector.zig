const std = @import("std");

type: u32,
hash: [32]u8,

pub fn serializeToWriter(self: @This(), writer: anytype) !void {
    comptime {
        if (!std.meta.hasFn(@TypeOf(writer), "writeInt")) @compileError("Expects writer to have fn 'writeInt'.");
        if (!std.meta.hasFn(@TypeOf(writer), "writeAll")) @compileError("Expects writer to have fn 'writeAll'.");
    }
    try writer.writeInt(u32, self.type, .little);
    try writer.writeAll(&self.hash);
}

pub fn deserializeReader(r: anytype) !@This() {
    comptime {
        if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
        if (!std.meta.hasFn(@TypeOf(r), "readBytesNoEof")) @compileError("Expects r to have fn 'readBytesNoEof'.");
    }

    const type_value = try r.readInt(u32, .little);
    var hash: [32]u8 = undefined;
    try r.readNoEof(&hash);

    return @This(){
        .type = type_value,
        .hash = hash,
    };
}