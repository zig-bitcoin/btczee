const std = @import("std");
const protocol = @import("../lib.zig");
const Sha256 = std.crypto.hash.sha2.Sha256;
const InventoryVector = @import("lib.zig").InventoryVector;
const genericChecksum = @import("lib.zig").genericChecksum;

/// NotFoundMessage represents the "notfound" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#notfound
pub const NotFoundMessage = struct {
    inventory: []const protocol.InventoryItem,

    const Self = @This();

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.NOTFOUND ++ [_]u8{0} ** 4;
    }

    /// Returns the message checksum
    ///
    /// Computed as `Sha256(Sha256(self.serialize()))[0..4]`
    pub fn checksum(self: *const Self) [4]u8 {
        return genericChecksum(self);
    }

    /// Serialize a message as bytes and write them to the buffer.
    ///
    /// buffer.len must be >= than self.hintSerializedLen()
    pub fn serializeToSlice(self: *const Self, buffer: []u8) !void {
        var fbs = std.io.fixedBufferStream(buffer);
        try self.serializeToWriter(fbs.writer());
    }

    /// Serialize the message as bytes and write them to the Writer.
    pub fn serializeToWriter(self: *const Self, writer: anytype) !void {
        try writer.writeInt(u32, @intCast(self.inventory.len), .little);
        for (self.inventory) |inv| {
            try inv.encodeToWriter(writer);
        }
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        const serialized_len = self.hintSerializedLen();

        const ret = try allocator.alloc(u8, serialized_len);
        errdefer allocator.free(ret);

        try self.serializeToSlice(ret);

        return ret;
    }

    /// Deserialize a Reader bytes as a `NotFoundMessage`
    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
        comptime {
            if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
        }

        const count = try r.readInt(u32, .little);
        const inventory = try allocator.alloc(protocol.InventoryItem, count);
        errdefer allocator.free(inventory);

        for (inventory) |*inv| {
            inv.* = try protocol.InventoryItem.decodeReader(r);
        }

        return Self{
            .inventory = inventory,
        };
    }

    /// Deserialize bytes into a `NotFoundMessage`
    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
        var fbs = std.io.fixedBufferStream(bytes);
        const reader = fbs.reader();

        return try Self.deserializeReader(allocator, reader);
    }

    pub fn hintSerializedLen(self: *const Self) usize {
        return 4 + self.inventory.len * (4 + 32); // count (4 bytes) + (type (4 bytes) + hash (32 bytes)) * count
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.inventory);
    }

    pub fn new(inventory: []const protocol.InventoryItem) Self {
        return .{
            .inventory = inventory,
        };
    }
};

// TESTS
// TESTS
test "ok_fullflow_notfound_message" {
    const allocator = std.testing.allocator;

    {
        const inventory = [_]protocol.InventoryItem{
            .{ .type = 1, .hash = [_]u8{0xab} ** 32 },
            .{ .type = 2, .hash = [_]u8{0xcd} ** 32 },
        };
        var msg = NotFoundMessage.new(&inventory);
        const payload = try msg.serialize(allocator);
        defer allocator.free(payload);
        var deserialized_msg = try NotFoundMessage.deserializeSlice(allocator, payload);
        defer deserialized_msg.deinit(allocator);

        try std.testing.expectEqual(msg.inventory.len, deserialized_msg.inventory.len);
        for (msg.inventory, deserialized_msg.inventory) |orig, deserialized| {
            try std.testing.expectEqual(orig.type, deserialized.type);
            try std.testing.expectEqualSlices(u8, &orig.hash, &deserialized.hash);
        }
    }
}
