const std = @import("std");
const OutPoint = @import("outpoint.zig");
const Script = @import("script.zig");

previous_outpoint: OutPoint,
script_sig: Script,
sequence: u32,

const Self = @This();

pub fn serializeToWriter(self: *const Self, w: anytype) !void {
    comptime {
        if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects w to have field 'writeInt'.");
        if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects w to have field 'writeAll'.");
    }

    try self.previous_outpoint.serializeToWriter(w);
    try self.script_sig.serializeToWriter(w);
    try w.writeInt(u32, self.sequence, .little);
}

pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
    comptime {
        if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
        if (!std.meta.hasFn(@TypeOf(r), "readNoEof")) @compileError("Expects r to have fn 'readNoEof'.");
        if (!std.meta.hasFn(@TypeOf(r), "readAll")) @compileError("Expects r to have fn 'readAll'.");
        if (!std.meta.hasFn(@TypeOf(r), "readByte")) @compileError("Expects r to have fn 'readByte'.");
    }

    var input: Self = undefined;
    input.previous_outpoint = try OutPoint.deserializeReader(allocator, r);
    input.script_sig = try Script.deserializeReader(allocator, r);
    input.sequence = try r.readInt(u32, .little);

    return input;
}

pub fn deinit(self: *Self) void {
    self.script_sig.deinit();
}
