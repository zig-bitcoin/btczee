const std = @import("std");
const protocol = @import("../lib.zig");

const Sha256 = std.crypto.hash.sha2.Sha256;

/// FilterLoadMessage represents the "filterload" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#filterload
pub const FilterLoadMessage = struct {
    hash_func: u32,
    tweak: u32,
    flags: u8,
    filter: []const u8,

    const Self = @This();

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.FILTERLOAD ++ [_]u8{0} ** 2;
    }

    /// Returns the message checksum
    pub fn checksum(self: *const Self) [4]u8 {
        var digest: [32]u8 = undefined;
        var hasher = Sha256.init(.{});
        const writer = hasher.writer();
        self.serializeToWriter(writer) catch unreachable; // Sha256.write is infaible
        hasher.final(&digest);

        Sha256.hash(&digest, &digest, .{});

        return digest[0..4].*;
    }

    /// Serialize the message as bytes and write them to the Writer.
    pub fn serializeToWriter(self: *const Self, w: anytype) !void {
        comptime {
            if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects w to have fn 'writeInt'.");
            if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects w to have fn 'writeAll'.");
        }

        try w.writeInt(u32, self.hash_func, .little);
        try w.writeInt(u32, self.tweak, .little);
        try w.writeInt(u8, self.flags, .little);
        try w.writeAll(self.filter);
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        const serialized_len = self.hintSerializedLen();

        const ret = try allocator.alloc(u8, serialized_len);
        errdefer allocator.free(ret);

        try self.serializeToSlice(ret);

        return ret;
    }

    /// Serialize a message as bytes and write them to the buffer.
    pub fn serializeToSlice(self: *const Self, buffer: []u8) !void {
        var fbs = std.io.fixedBufferStream(buffer);
        try self.serializeToWriter(fbs.writer());
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
        comptime {
            if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
            if (!std.meta.hasFn(@TypeOf(r), "readAllAlloc")) @compileError("Expects r to have fn 'readAllAlloc'.");
        }

        var fl: Self = undefined;

        fl.hash_func = try r.readInt(u32, .little);
        fl.tweak = try r.readInt(u32, .little);
        fl.flags = try r.readInt(u8, .little);
        fl.filter = try r.readAllAlloc(allocator, 36000);

        return fl;
    }

    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
        var fbs = std.io.fixedBufferStream(bytes);
        return try Self.deserializeReader(allocator, fbs.reader());
    }

    pub fn hintSerializedLen(self: *const Self) usize {
        const fixed_length = 4 + 4 + 1; // hash_func (4 bytes) + tweak (4 bytes) + flags (1 byte)
        return self.filter.len + fixed_length; 
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.filter);
    }
};

test "ok_fullflow_filterload_message" {
    const allocator = std.testing.allocator;

    const filter = "this is a test filter";
    var fl = FilterLoadMessage{
        .hash_func = 0xdeadbeef,
        .tweak = 0xfeedface,
        .flags = 0x02,
        .filter = filter,
    };

    const payload = try fl.serialize(allocator);
    defer allocator.free(payload);

    var deserialized_fl = try FilterLoadMessage.deserializeSlice(allocator, payload);
    defer deserialized_fl.deinit(allocator);

    try std.testing.expect(fl.hash_func == deserialized_fl.hash_func);
    try std.testing.expect(fl.tweak == deserialized_fl.tweak);
    try std.testing.expect(fl.flags == deserialized_fl.flags);
    try std.testing.expectEqualSlices(u8, filter, deserialized_fl.filter);
}
