const std = @import("std");
const Script = @import("script.zig");

value: i64,
script_pubkey: Script,

const Self = @This();

pub fn serializeToWriter(self: *const Self, w: anytype) !void {
    comptime {
        if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects w to have field 'writeInt'.");
        if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects w to have field 'writeAll'.");
    }

    try w.writeInt(i64, self.value, .little);
    try self.script_pubkey.serializeToWriter(w);
}

pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
    comptime {
        if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
        if (!std.meta.hasFn(@TypeOf(r), "readNoEof")) @compileError("Expects r to have fn 'readNoEof'.");
        if (!std.meta.hasFn(@TypeOf(r), "readAll")) @compileError("Expects r to have fn 'readAll'.");
        if (!std.meta.hasFn(@TypeOf(r), "readByte")) @compileError("Expects r to have fn 'readByte'.");
    }

    var output: Self = undefined;

    output.value = try r.readInt(i64, .little);
    output.script_pubkey = try Script.deserializeReader(allocator, r);

    return output;
}

pub fn deinit(self: *Self) void {
    self.script_pubkey.deinit();
}
