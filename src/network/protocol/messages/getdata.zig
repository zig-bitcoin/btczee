const std = @import("std");
const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;
const message = @import("./lib.zig");
const genericChecksum = @import("lib.zig").genericChecksum;
const genericDeserializeSlice = @import("lib.zig").genericDeserializeSlice;
const genericSerialize = @import("lib.zig").genericSerialize;

const Sha256 = std.crypto.hash.sha2.Sha256;

const protocol = @import("../lib.zig");

pub const GetdataMessage = struct {
    inventory: []const protocol.InventoryItem,
    const Self = @This();

    pub inline fn name() *const [12]u8 {
        return protocol.CommandNames.GETDATA ++ [_]u8{0} ** 5;
    }

    /// Returns the message checksum
    ///
    /// Computed as `Sha256(Sha256(self.serialize()))[0..4]`
    pub fn checksum(self: *const GetdataMessage) [4]u8 {
        return genericChecksum(self);
    }

    /// Free the `inventory`
    pub fn deinit(self: GetdataMessage, allocator: std.mem.Allocator) void {
        allocator.free(self.inventory);
    }

    /// Serialize the message as bytes and write them to the Writer.
    ///
    /// `w` should be a valid `Writer`.
    pub fn serializeToWriter(self: *const GetdataMessage, w: anytype) !void {
        const count = CompactSizeUint.new(self.inventory.len);
        try count.encodeToWriter(w);

        for (self.inventory) |item| {
            try item.encodeToWriter(w);
        }
    }

    pub fn serialize(self: *const GetdataMessage, allocator: std.mem.Allocator) ![]u8 {
        return genericSerialize(self, allocator);
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

        const compact_count = try CompactSizeUint.decodeReader(r);
        const count = compact_count.value();
        if (count == 0) {
            return GetdataMessage{
                .inventory = &[_]protocol.InventoryItem{},
            };
        }

        const inventory = try allocator.alloc(protocol.InventoryItem, count);
        errdefer allocator.free(inventory);

        for (inventory) |*item| {
            item.* = try protocol.InventoryItem.decodeReader(r);
        }

        return GetdataMessage{
            .inventory = inventory,
        };
    }

    /// Deserialize bytes into a `GetdataMessage`
    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
        return genericDeserializeSlice(Self, allocator, bytes);
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
        const inventory_items = [_]protocol.InventoryItem{
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