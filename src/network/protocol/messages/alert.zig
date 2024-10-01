const std = @import("std");
const protocol = @import("../lib.zig");
const genericChecksum = @import("lib.zig").genericChecksum;

const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;
const Types = @import("../../../types/lib.zig");
const Alert = Types.Alert;

/// AlertMessage represents the "alert" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#alert
pub const AlertMessage = struct {
    payload: Alert,
    serialized_payload: []const u8,
    signature: []const u8,

    const Self = @This();

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.ALERT ++ [_]u8{0} ** 7;
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

        try self.payload.serializeToWriter(w);

        const compact_serialized_payload_len = CompactSizeUint.new(self.serialized_payload.len);
        try compact_serialized_payload_len.encodeToWriter(w);
        try w.writeAll(self.serialized_payload);

        const compact_signature_len = CompactSizeUint.new(self.signature.len);
        try compact_signature_len.encodeToWriter(w);
        try w.writeAll(self.signature);
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
            if (!std.meta.hasFn(@TypeOf(r), "readNoEof")) @compileError("Expects r to have fn 'readNoEof'.");
        }

        const payload = try Alert.deserializeReader(allocator, r);

        const serialized_payload_len = (try CompactSizeUint.decodeReader(r)).value();
        const serialized_payload = try allocator.alloc(u8, serialized_payload_len);
        errdefer allocator.free(serialized_payload);
        try r.readNoEof(serialized_payload);

        const signature_len = (try CompactSizeUint.decodeReader(r)).value();
        const signature = try allocator.alloc(u8, signature_len);
        errdefer allocator.free(signature);
        try r.readNoEof(signature);

        return Self{
            .serialized_payload = serialized_payload,
            .signature = signature,
            .payload = payload,
        };
    }

    /// Deserialize bytes into a `VersionMessage`
    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
        var fbs = std.io.fixedBufferStream(bytes);
        return try Self.deserializeReader(allocator, fbs.reader());
    }

    pub fn hintSerializedLen(self: *const Self) usize {
        const compact_serialized_payload_len = CompactSizeUint.new(self.serialized_payload.len).hint_encoded_len();
        const compact_signature_len = CompactSizeUint.new(self.serialized_payload.len).hint_encoded_len();

        var size: usize = 0;

        size += self.payload.serializedLen();
        size += compact_serialized_payload_len + self.serialized_payload.len;
        size += compact_signature_len + self.signature.len;

        return size;
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.serialized_payload);
        allocator.free(self.signature);
        self.payload.deinit(allocator);
    }
};

test "ok_fullflow_alert_message" {
    const allocator = std.testing.allocator;
    
    var set_cancel: [2]u32 = .{ 1000, 2000 };
    var sub_ver: [2][]const u8 = .{ "/Satoshi:0.7.2/", "/Satoshi:0.7.3/" };

    const signature: []const u8 = &[_]u8{
        0x30, 0x45, 0x02, 0x20, 0x75, 0x61, 0x90, 0x93, 0xE6, 0x3A, 0xDD, 0x99,
        0xD7, 0xAE, 0xC1, 0x4C, 0x53, 0x10, 0x7B, 0xAC, 0xF5, 0xE9, 0x3E, 0x28,
        0x7E, 0x39, 0x69, 0x3A, 0xBD, 0x9C, 0xE1, 0x91, 0xC5, 0x42, 0x8C, 0xA3,
        0x02, 0x21, 0x00, 0xA3, 0xB9, 0xB1, 0x35, 0xE7, 0x4D, 0xDB, 0x47, 0xA6,
        0x4F, 0xB6, 0x0B, 0x8A, 0x67, 0x6C, 0x3D, 0x76, 0xDC, 0x52, 0x7E, 0x72,
        0x0F, 0xA1, 0x97, 0xD9, 0x6B, 0x8C, 0x24, 0x74, 0x37, 0xA9, 0x0E
    };

    const payload = Alert{
        .version = 1,
        .relay_until = 1622509200,
        .expiration = 1622595600,
        .id = 1001,
        .cancel = 0,
        .set_cancel = set_cancel[0..],
        .min_ver = 70000,
        .max_ver = 80000,
        .set_sub_ver = sub_ver[0..],
        .priority = 1000,
        .comment = "Network upgrade required",
        .status_bar = "Please upgrade to avoid network disruptions.",
        .reserved = "",
    };

    const serialized_payload = try payload.serialize(allocator);
    defer allocator.free(serialized_payload);

    var deserialized_alert = try Alert.deserializeSlice(allocator, serialized_payload);
    defer deserialized_alert.deinit(allocator);

    const am = AlertMessage {
        .serialized_payload = serialized_payload,
        .signature = signature,
        .payload = payload,
    };

    const am_payload = try am.serialize(allocator);
    defer allocator.free(am_payload);

    var deserialized_payload = try AlertMessage.deserializeSlice(allocator, am_payload);
    defer deserialized_payload.deinit(allocator);

    try std.testing.expectEqualSlices(u8, serialized_payload, deserialized_payload.serialized_payload);
    try std.testing.expect(deserialized_alert.version == deserialized_payload.payload.version);
    try std.testing.expect(deserialized_alert.set_cancel.len == deserialized_payload.payload.set_cancel.len);
    try std.testing.expect(deserialized_payload.payload.max_ver == deserialized_alert.max_ver);
    try std.testing.expectEqualSlices(u8, deserialized_alert.status_bar, deserialized_payload.payload.status_bar);
    try std.testing.expectEqualSlices(u8, deserialized_alert.reserved, deserialized_payload.payload.reserved);
}