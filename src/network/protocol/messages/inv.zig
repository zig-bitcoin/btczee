const std = @import("std");
const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;
const message = @import("./lib.zig");
const genericChecksum = @import("lib.zig").genericChecksum;

const Sha256 = std.crypto.hash.sha2.Sha256;

const protocol = @import("../lib.zig");

pub const InvMessage = struct {
    inventory: []const protocol.InventoryItem,

    pub inline fn name() *const [12]u8 {
        return protocol.CommandNames.INV ++ [_]u8{0} ** 5;
    }

    /// Returns the message checksum
    ///
    /// Computed as `Sha256(Sha256(self.serialize()))[0..4]`
    pub fn checksum(self: *const InvMessage) [4]u8 {
        return genericChecksum(self);
    }

    /// Free the `inventory`
    pub fn deinit(self: InvMessage, allocator: std.mem.Allocator) void {
        allocator.free(self.inventory);
    }

    /// Serialize the message as bytes and write them to the Writer.
    ///
    /// `w` should be a valid `Writer`.
    pub fn serializeToWriter(self: *const InvMessage, w: anytype) !void {
        const count = CompactSizeUint.new(self.inventory.len);
        try count.encodeToWriter(w);

        for (self.inventory) |item| {
            try item.encodeToWriter(w);
        }
    }

    pub fn serialize(self: *const InvMessage, allocator: std.mem.Allocator) ![]u8 {
        const serialized_len = self.hintSerializedLen();

        const ret = try allocator.alloc(u8, serialized_len);
        errdefer allocator.free(ret);

        try self.serializeToSlice(ret);

        return ret;
    }

    /// Serialize a message as bytes and write them to the buffer.
   ///
   /// buffer.len must be >= than self.hintSerializedLen()
    pub fn serializeToSlice(self: *const InvMessage, buffer: []u8) !void {
        var fbs = std.io.fixedBufferStream(buffer);
        const writer = fbs.writer();
        try self.serializeToWriter(writer);
    }

    pub fn hintSerializedLen(self: *const InvMessage) usize {
        var length: usize = 0;

        // Adding the length of CompactSizeUint for the count
        const count = CompactSizeUint.new(self.inventory.len);
        length += count.hint_encoded_len();

        // Adding the length of each inventory item
        length += self.inventory.len * (4 + 32); // Type (4 bytes) + Hash (32 bytes)

        return length;
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !InvMessage {

        const compact_count = try CompactSizeUint.decodeReader(r);
        const count = compact_count.value();
        if (count == 0) {
            return InvMessage{
                .inventory = &[_]protocol.InventoryItem{},
            };
        }

        const inventory = try allocator.alloc(protocol.InventoryItem, count);
        errdefer allocator.free(inventory);

        for (inventory) |*item| {
            item.* = try protocol.InventoryItem.decodeReader(r);
        }

        return InvMessage{
            .inventory = inventory,
        };
    }

    /// Deserialize bytes into a `InvMessage`
    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !InvMessage {
        var fbs = std.io.fixedBufferStream(bytes);
        const reader = fbs.reader();
        return try InvMessage.deserializeReader(allocator, reader);
    }


    pub fn eql(self: *const InvMessage, other: *const InvMessage) bool {
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
test "ok_full_flow_inv_message" {
    const allocator = std.testing.allocator;

    // With some inventory items
    {
        const inventory_items = [_]protocol.InventoryItem{
            .{ .type = 1, .hash = [_]u8{0xab} ** 32 },
            .{ .type = 2, .hash = [_]u8{0xcd} ** 32 },
            .{ .type = 2, .hash = [_]u8{0xef} ** 32 },
        };

        const gd = InvMessage{
            .inventory = inventory_items[0..],
        };

        const payload = try gd.serialize(allocator);
        defer allocator.free(payload);

        const deserialized_gd = try InvMessage.deserializeSlice(allocator, payload);

        try std.testing.expect(gd.eql(&deserialized_gd));

        // Free allocated memory for deserialized inventory
        defer allocator.free(deserialized_gd.inventory);
    }
}