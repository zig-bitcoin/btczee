const std = @import("std");
const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;

version: u32,
relay_until: u64,
expiration: u64,
id: u32,
cancel: u32,
set_cancel: []u32,
min_ver: u32,
max_ver: u32,
set_sub_ver: [][]const u8,
priority: u32,
comment: []const u8,
status_bar: []const u8,
reserved: []const u8,

const Self = @This();

pub fn serializeToWriter(self: *const Self, w: anytype) !void {
    comptime {
        if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects w to have field 'writeInt'.");
        if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects w to have field 'writeAll'.");
    }

    try w.writeInt(u32, self.version, .little);
    try w.writeInt(u64, self.relay_until, .little);
    try w.writeInt(u64, self.expiration, .little);
    try w.writeInt(u32, self.id, .little);
    try w.writeInt(u32, self.cancel, .little);

    const compact_set_cancel_len = CompactSizeUint.new(self.set_cancel.len);
    try compact_set_cancel_len.encodeToWriter(w);
    for (self.set_cancel) |fuck_cancel| {
        try w.writeInt(u32, fuck_cancel, .little);
    }

    try w.writeInt(u32, self.min_ver, .little);
    try w.writeInt(u32, self.max_ver, .little);

    // const compact_set_sub_ver_len = CompactSizeUint.new(self.set_sub_ver.len);
    // try compact_set_sub_ver_len.encodeToWriter(w);
    // for (self.set_sub_ver) |set_sub_ver| {
    //     try CompactSizeUint.new(set_sub_ver.len).encodeToWriter(w);
    //     try w.writeAll(set_sub_ver);
    // }

    try w.writeInt(u32, self.priority, .little);

    const compact_comment_len = CompactSizeUint.new(self.comment.len);
    try compact_comment_len.encodeToWriter(w);
    try w.writeAll(self.comment);

    const compact_status_bar_len = CompactSizeUint.new(self.status_bar.len);
    try compact_status_bar_len.encodeToWriter(w);
    try w.writeAll(self.status_bar);

    const compact_reserved_len = CompactSizeUint.new(self.reserved.len);
    try compact_reserved_len.encodeToWriter(w);
    try w.writeAll(self.reserved);
}

/// Serialize a message as bytes and write them to the buffer.
pub fn serializeToSlice(self: *const Self, buffer: []u8) !void {
    var fbs = std.io.fixedBufferStream(buffer);
    try self.serializeToWriter(fbs.writer());
}

/// Serialize a message as bytes and return them.
pub fn serialize(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
    const serialized_len = self.serializedLen();

    const ret = try allocator.alloc(u8, serialized_len);
    errdefer allocator.free(ret);

    try self.serializeToSlice(ret);

    return ret;
}

pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
    comptime {
        if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
        if (!std.meta.hasFn(@TypeOf(r), "readNoEof")) @compileError("Expects r to have fn 'readNoEof'.");
    }

    var alert: Self = undefined;

    alert.version = try r.readInt(u32, .little);
    alert.relay_until = try r.readInt(u64, .little);
    alert.expiration = try r.readInt(u64, .little);
    alert.id = try r.readInt(u32, .little);
    alert.cancel = try r.readInt(u32, .little);

    const set_cancel_len = (try CompactSizeUint.decodeReader(r)).value();
    const set_cancel = try allocator.alloc(u32, set_cancel_len);
    errdefer allocator.free(set_cancel);
    for (set_cancel) |*cancel| {
        cancel.* = try r.readInt(u32, .little);
    }
    alert.set_cancel = set_cancel;

    alert.min_ver = try r.readInt(u32, .little);
    alert.max_ver = try r.readInt(u32, .little);

    // const set_sub_ver_len = (try CompactSizeUint.decodeReader(r)).value();
    // const set_sub_ver = try allocator.alloc([]const u8, set_sub_ver_len);
    // errdefer allocator.free(set_sub_ver);
    // for (set_sub_ver) |*ver| {
    //     const index = (try CompactSizeUint.decodeReader(r)).value();
    //     const sub_ver = try allocator.alloc(u8, index);
    //     errdefer allocator.free(sub_ver);
    //     try r.readNoEof(sub_ver);
    //     ver.* = sub_ver;
    // }

    alert.priority = try r.readInt(u32, .little);

    const comment_len = (try CompactSizeUint.decodeReader(r)).value();
    const comment = try allocator.alloc(u8, comment_len);
    errdefer allocator.free(comment);
    try r.readNoEof(comment);
    alert.comment = comment;

    const status_bar_len = (try CompactSizeUint.decodeReader(r)).value();
    const status_bar = try allocator.alloc(u8, status_bar_len);
    errdefer allocator.free(status_bar);
    try r.readNoEof(status_bar);
    alert.status_bar = status_bar;

    const reserved_len = (try CompactSizeUint.decodeReader(r)).value();
    const reserved = try allocator.alloc(u8, reserved_len);
    errdefer allocator.free(reserved);
    try r.readNoEof(reserved);
    alert.reserved = reserved;

    return alert;
}

/// Deserialize bytes into Self
pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
    var fbs = std.io.fixedBufferStream(bytes);
    return try Self.deserializeReader(allocator, fbs.reader());
}

pub fn serializedLen(self: *const Self) usize {
    var size: usize = 0;
    size += 40; // Fixed length

    size += CompactSizeUint.new(self.set_cancel.len).hint_encoded_len() + (4 * self.set_cancel.len);

    // size += CompactSizeUint.new(self.set_sub_ver.len).hint_encoded_len() + self.set_sub_ver.len;
    // for (self.set_sub_ver) |sub_ver| {
    //     size += CompactSizeUint.new(sub_ver.len).hint_encoded_len() + sub_ver.len;
    // }

    size += CompactSizeUint.new(self.comment.len).hint_encoded_len() + self.comment.len;
    size += CompactSizeUint.new(self.status_bar.len).hint_encoded_len() + self.status_bar.len;
    size += CompactSizeUint.new(self.reserved.len).hint_encoded_len() + self.reserved.len;

    return size;
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    allocator.free(self.set_cancel);
    // for (self.set_sub_ver) |sub_ver| {
    //     allocator.free(sub_ver);
    // }
    // allocator.free(self.set_sub_ver);
    allocator.free(self.comment);
    allocator.free(self.status_bar);
    allocator.free(self.reserved);
}
