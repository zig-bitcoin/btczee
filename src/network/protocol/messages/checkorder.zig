const std = @import("std");
const protocol = @import("../lib.zig");
const Sha256 = std.crypto.hash.sha2.Sha256;

pub const CheckOrderMessage = struct {
    version: u32,
    order_id: [32]u8,
    item_type: [16]u8,
    item_amount: u64,
    payment_type: [16]u8,
    payment_amount: u64,
    expiration_time: u64,

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.CHECKORDER ++ [_]u8{0} ** 3;
    }

    pub fn serialize(self: *const CheckOrderMessage, allocator: std.mem.Allocator) ![]u8 {
        const buffer = try allocator.alloc(u8, self.hintSerializedLen());
        var fbs = std.io.fixedBufferStream(buffer);
        var writer = fbs.writer();

        try writer.writeInt(u32, self.version, .little);
        try writer.writeAll(&self.order_id);
        try writer.writeAll(&self.item_type);
        try writer.writeInt(u64, self.item_amount, .little);
        try writer.writeAll(&self.payment_type);
        try writer.writeInt(u64, self.payment_amount, .little);
        try writer.writeInt(u64, self.expiration_time, .little);

        return buffer;
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, reader: anytype) !CheckOrderMessage {
        _ = allocator;
        var msg: CheckOrderMessage = undefined;

        msg.version = try reader.readInt(u32, .little);
        try reader.readNoEof(&msg.order_id);
        try reader.readNoEof(&msg.item_type);
        msg.item_amount = try reader.readInt(u64, .little);
        try reader.readNoEof(&msg.payment_type);
        msg.payment_amount = try reader.readInt(u64, .little);
        msg.expiration_time = try reader.readInt(u64, .little);

        return msg;
    }

    pub fn checksum(self: *const CheckOrderMessage) [4]u8 {
        var hasher = Sha256.init(.{});
        var digest: [32]u8 = undefined;

        hasher.update(std.mem.asBytes(&self.version));
        hasher.update(&self.order_id);
        hasher.update(&self.item_type);
        hasher.update(std.mem.asBytes(&self.item_amount));
        hasher.update(&self.payment_type);
        hasher.update(std.mem.asBytes(&self.payment_amount));
        hasher.update(std.mem.asBytes(&self.expiration_time));

        hasher.final(&digest);

        Sha256.hash(&digest, &digest, .{});

        return digest[0..4].*;
    }

    pub fn hintSerializedLen(self: *const CheckOrderMessage) usize {
        _ = self;
        return 4 + 32 + 16 + 8 + 16 + 8 + 8;
    }

    pub fn deinit(self: *CheckOrderMessage, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
        // No dynamic allocation, so nothing to free
    }
};

// TESTS

test "ok_full_flow_CheckOrderMessage" {
    const allocator = std.testing.allocator;

    var msg = CheckOrderMessage{
        .version = 1,
        .order_id = [_]u8{0x01} ** 32,
        .item_type = [_]u8{0x02} ** 16,
        .item_amount = 100,
        .payment_type = [_]u8{0x03} ** 16,
        .payment_amount = 1000,
        .expiration_time = 1234567890,
    };

    const payload = try msg.serialize(allocator);
    defer allocator.free(payload);

    var fbs = std.io.fixedBufferStream(payload);
    var deserialized_msg = try CheckOrderMessage.deserializeReader(allocator, fbs.reader());

    try std.testing.expectEqual(msg.version, deserialized_msg.version);
    try std.testing.expectEqualSlices(u8, &msg.order_id, &deserialized_msg.order_id);
    try std.testing.expectEqualSlices(u8, &msg.item_type, &deserialized_msg.item_type);
    try std.testing.expectEqual(msg.item_amount, deserialized_msg.item_amount);
    try std.testing.expectEqualSlices(u8, &msg.payment_type, &deserialized_msg.payment_type);
    try std.testing.expectEqual(msg.payment_amount, deserialized_msg.payment_amount);
    try std.testing.expectEqual(msg.expiration_time, deserialized_msg.expiration_time);
}
