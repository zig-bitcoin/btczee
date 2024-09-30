const std = @import("std");
const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;
const message = @import("./lib.zig");

const Sha256 = std.crypto.hash.sha2.Sha256;

const protocol = @import("../lib.zig");

pub const GetdataMessage = struct {
    inventory: []const message.InventoryItem,

    pub inline fn name() *const [12]u8 {
        return protocol.CommandNames.GETDATA ++ [_]u8{0} ** 5;
    }

    /// Returns the message checksum
    ///
    /// Computed as `Sha256(Sha256(self.serialize()))[0..4]`
    pub fn checksum(self: *const GetdataMessage) [4]u8 {
        var digest: [32]u8 = undefined;
        var hasher = Sha256.init(.{});
        const writer = hasher.writer();
        self.serializeToWriter(writer) catch unreachable; // Sha256.write is infaible
        hasher.final(&digest);

        Sha256.hash(&digest, &digest, .{});

        return digest[0..4].*;
    }

    /// Free the `inventory`
    pub fn deinit(self: GetdataMessage, allocator: std.mem.Allocator) void {
        allocator.free(self.inventory);
    }

    /// Serialize the message as bytes and write them to the Writer.
    ///
    /// `w` should be a valid `Writer`.
    pub fn serializeToWriter(self: *const GetdataMessage, w: anytype) !void {
        comptime {
            if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects writer to have fn 'writeInt'.");
            if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects writer to have fn 'writeAll'.");
        }

        const count = CompactSizeUint.new(self.inventory.len);
        try count.encodeToWriter(w);

        for (self.inventory) |item| {
            try item.serialize(w);
        }
    }

    pub fn serialize(self: *const GetdataMessage, allocator: std.mem.Allocator) ![]u8 {
        const serialized_len = self.hintSerializedLen();

        const ret = try allocator.alloc(u8, serialized_len);
        errdefer allocator.free(ret);

        try self.serializeToSlice(ret);

        return ret;
    }

    /// Serialize a message as bytes and write them to the buffer.
   ///
   /// buffer.len must be >= than self.hintSerializedLen()
    pub fn serializeToSlice(self: *const GetdataMessage, buffer: []u8) !void {
        var fbs = std.io.fixedBufferStream(buffer);
        const writer = fbs.writer();
        try self.serializeToWriter(writer);
    }

    pub fn hintSerializedLen(self: *const GetdataMessage) usize {
        var length: usize = 0;

        // Adding the length of CompactSizeUint for the count
        const count = CompactSizeUint.new(self.inventory.len);
        length += count.hint_encoded_len();

        // Adding the length of each inventory item
        length += self.inventory.len * (4 + 32); // Type (4 bytes) + Hash (32 bytes)

        return length;
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !GetdataMessage {
        comptime {
            if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects reader to have fn 'readInt'.");
            if (!std.meta.hasFn(@TypeOf(r), "readNoEof")) @compileError("Expects reader to have fn 'readNoEof'.");
        }

        const compact_count = try CompactSizeUint.decodeReader(r);
        const count = compact_count.value();

        const inventory = try allocator.alloc(message.InventoryItem, count);

        for (inventory) |*item| {
            item.* = try message.InventoryItem.deserialize(r);
        }

        return GetdataMessage{
            .inventory = inventory,
        };
    }

    /// Deserialize bytes into a `GetdataMessage`
    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !GetdataMessage {
        var fbs = std.io.fixedBufferStream(bytes);
        const reader = fbs.reader();
        return try GetdataMessage.deserializeReader(allocator, reader);
    }


    pub fn eql(self: *const GetdataMessage, other: *const GetdataMessage) bool {
        if (self.inventory.len != other.inventory.len) return false;

        for (0..self.inventory.len) |i| {
            const item_self = self.inventory[i];
            const item_other = other.inventory[i];
            if (!item_self.eql(&item_other)) {
                return false;
            }
        }

        return true;
    }
};


// TESTS

test "ok_full_flow_GetdataMessage" {
    const allocator = std.testing.allocator;

    // With some inventory items
    {
        const inventory_items = [_]message.InventoryItem{
            .{ .type = 1, .hash = [_]u8{0xab} ** 32 },
            .{ .type = 2, .hash = [_]u8{0xcd} ** 32 },
            .{ .type = 2, .hash = [_]u8{0xef} ** 32 },
        };

        const gd = GetdataMessage{
            .inventory = inventory_items[0..],
        };

        const payload = try gd.serialize(allocator);
        defer allocator.free(payload);

        const deserialized_gd = try GetdataMessage.deserializeSlice(allocator, payload);

        try std.testing.expect(gd.eql(&deserialized_gd));

        // Free allocated memory for deserialized inventory
        defer allocator.free(deserialized_gd.inventory);
    }
}