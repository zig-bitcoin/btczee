const std = @import("std");
const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;
const readBytesExact = @import("../util/mem/read.zig").readBytesExact;

bytes: std.ArrayList(u8),
allocator: std.mem.Allocator,

const Self = @This();

/// Initialize a new script
pub fn init(allocator: std.mem.Allocator) !Self {
    return Self{
        .bytes = std.ArrayList(u8).init(allocator),
        .allocator = allocator,
    };
}

/// Deinitialize the script
pub fn deinit(self: *Self) void {
    self.bytes.deinit();
}

/// Add data to the script
pub fn push(self: *Self, data: []const u8) !void {
    try self.bytes.appendSlice(data);
}

pub fn serializeToWriter(self: *const Self, w: anytype) !void {
    comptime {
        if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects w to have field 'writeInt'.");
        if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects w to have field 'writeAll'.");
    }

    const script_len = CompactSizeUint.new(self.bytes.items.len);
    try script_len.encodeToWriter(w);
    try w.writeAll(self.bytes.items);
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
    script.bytes = try std.ArrayList(u8).initCapacity(allocator, script_len.value());
    try r.readNoEof(script.bytes.items);

    const bytes = try readBytesExact(allocator, r, script_len.value());
    defer allocator.free(bytes);
    errdefer allocator.free(bytes);

    try script.bytes.appendSlice(bytes);

    return script;
}
