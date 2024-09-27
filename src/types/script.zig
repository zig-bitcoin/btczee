const std = @import("std");
const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;
const readBytesExact = @import("../util/mem/read.zig").readBytesExact;

bytes: []u8,
allocator: std.mem.Allocator,

const Self = @This();

/// Initialize a new script
pub fn init(allocator: std.mem.Allocator) !Self {
    return Self{
        .bytes = try allocator.alloc(u8, 0),
        .allocator = allocator,
    };
}

/// Deinitialize the script
pub fn deinit(self: *Self) void {
    self.allocator.free(self.bytes);
}

/// Add data to the script
pub fn push(self: *Self, data: []const u8) !void {
    const new_len = self.bytes.len + data.len;
    self.bytes = try self.allocator.realloc(self.bytes, new_len);
    @memcpy(self.bytes[self.bytes.len - data.len ..], data);
}

pub fn serializeToWriter(self: *const Self, w: anytype) !void {
    comptime {
        if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects w to have field 'writeInt'.");
        if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects w to have field 'writeAll'.");
    }

    const script_len = CompactSizeUint.new(self.bytes.len);
    try script_len.encodeToWriter(w);
    try w.writeAll(self.bytes);
}

pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
    comptime {
        if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
        if (!std.meta.hasFn(@TypeOf(r), "readNoEof")) @compileError("Expects r to have fn 'readNoEof'.");
        if (!std.meta.hasFn(@TypeOf(r), "readAll")) @compileError("Expects r to have fn 'readAll'.");
        if (!std.meta.hasFn(@TypeOf(r), "readByte")) @compileError("Expects r to have fn 'readByte'.");
    }

    var script: Self = undefined;

    const script_len = try CompactSizeUint.decodeReader(r);
    script.bytes = try readBytesExact(allocator, r, script_len.value());
    script.allocator = allocator;

    return script;
}
