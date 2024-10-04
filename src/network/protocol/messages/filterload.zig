const std = @import("std");
const protocol = @import("../lib.zig");
const genericChecksum = @import("lib.zig").genericChecksum;
const genericSerialize = @import("lib.zig").genericSerialize;
const genericDeserializeSlice = @import("lib.zig").genericDeserializeSlice;

const Sha256 = std.crypto.hash.sha2.Sha256;
const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;

/// FilterLoadMessage represents the "filterload" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#filterload
pub const FilterLoadMessage = struct {
    filter: []const u8,
    hash_func: u32,
    tweak: u32,
    flags: u8,

    const Self = @This();

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.FILTERLOAD ++ [_]u8{0} ** 2;
    }

    /// Returns the message checksum
    pub fn checksum(self: *const Self) [4]u8 {
        return genericChecksum(self);
    }

    /// Serialize the message as bytes and write them to the Writer.
    pub fn serializeToWriter(self: *const Self, w: anytype) !void {
        comptime {
            if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects w to have fn 'writeInt'.");
            if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects w to have fn 'writeAll'.");
        }

        const compact_filter_len = CompactSizeUint.new(self.filter.len);
        try compact_filter_len.encodeToWriter(w);

        try w.writeAll(self.filter);
        try w.writeInt(u32, self.hash_func, .little);
        try w.writeInt(u32, self.tweak, .little);
        try w.writeInt(u8, self.flags, .little);
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        return genericSerialize(self, allocator);
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
        comptime {
            if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
            if (!std.meta.hasFn(@TypeOf(r), "readNoEof")) @compileError("Expects r to have fn 'readNoEof'.");
        }

        const filter_len = (try CompactSizeUint.decodeReader(r)).value();
        const filter = try allocator.alloc(u8, filter_len);
        errdefer allocator.free(filter);
        try r.readNoEof(filter);

        const hash_func = try r.readInt(u32, .little);
        const tweak = try r.readInt(u32, .little);
        const flags = try r.readInt(u8, .little);

        return Self{
            .filter = filter,
            .hash_func = hash_func,
            .tweak = tweak,
            .flags = flags,
        };
    }

    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
        return genericDeserializeSlice(Self, allocator, bytes);
    }

    pub fn hintSerializedLen(self: *const Self) usize {
        const fixed_length = 4 + 4 + 1; // hash_func (4 bytes) + tweak (4 bytes) + flags (1 byte)
        const compact_filter_len = CompactSizeUint.new(self.filter.len).hint_encoded_len();
        return compact_filter_len + self.filter.len + fixed_length;
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.filter);
    }
};

test "ok_fullflow_filterload_message" {
    const allocator = std.testing.allocator;

    const filter = "this is a test filter";
    var fl = FilterLoadMessage{
        .filter = filter,
        .hash_func = 0xdeadbeef,
        .tweak = 0xfeedface,
        .flags = 0x02,
    };

    const payload = try fl.serialize(allocator);
    defer allocator.free(payload);

    var deserialized_fl = try FilterLoadMessage.deserializeSlice(allocator, payload);
    defer deserialized_fl.deinit(allocator);

    try std.testing.expectEqualSlices(u8, filter, deserialized_fl.filter);
    try std.testing.expect(fl.hash_func == deserialized_fl.hash_func);
    try std.testing.expect(fl.tweak == deserialized_fl.tweak);
    try std.testing.expect(fl.flags == deserialized_fl.flags);
}
