const std = @import("std");
const protocol = @import("../lib.zig");
const genericChecksum = @import("lib.zig").genericChecksum;

/// FilterAddMessage represents the "filteradd" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#filteradd
pub const FilterAddMessage = struct {
    element: []const u8,

    const Self = @This();

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.FILTERADD ++ [_]u8{0} ** 3;
    }

    /// Returns the message checksum
    pub fn checksum(self: *const Self) [4]u8 {
        return genericChecksum(self, true);
    }

    /// Serialize the message as bytes and write them to the Writer.
    pub fn serializeToWriter(self: *const Self, w: anytype) !void {
        comptime {
            if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects w to have fn 'writeAll'.");
        }
        try w.writeAll(self.element);
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
            if (!std.meta.hasFn(@TypeOf(r), "readAllAlloc")) @compileError("Expects r to have fn 'readAllAlloc'.");
        }
        const element = try r.readAllAlloc(allocator, 520);
        return Self{ .element = element };
    }

    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
        var fbs = std.io.fixedBufferStream(bytes);
        return try Self.deserializeReader(allocator, fbs.reader());
    }

    pub fn hintSerializedLen(self: *const Self) usize {
        return self.element.len;
    }

    pub fn deinit(self: *const Self, allocator: std.mem.Allocator) void {
        allocator.free(self.element);
    }
};

// TESTS
test "ok_fullflow_filteradd_message" {
    const allocator = std.testing.allocator;

    const element = "test_element";
    var msg = FilterAddMessage{ .element = element };

    const payload = try msg.serialize(allocator);
    defer allocator.free(payload);

    var deserialized_msg = try FilterAddMessage.deserializeSlice(allocator, payload);
    defer deserialized_msg.deinit(allocator);

    try std.testing.expectEqualSlices(u8, element, deserialized_msg.element);
}
