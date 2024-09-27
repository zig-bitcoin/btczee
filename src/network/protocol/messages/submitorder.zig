const std = @import("std");
const protocol = @import("../lib.zig");
const Sha256 = std.crypto.hash.sha2.Sha256;

pub const SubmitOrderMessage = struct {
    version: u32,
    order_id: [32]u8,
    item_type: [16]u8,
    item_amount: u64,
    payment_type: [16]u8,
    payment_amount: u64,
    expiration_time: u64,

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.SUBMITORDER;
    }

    pub fn serialize(self: *const SubmitOrderMessage, allocator: std.mem.Allocator) ![]u8 {
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

    pub fn deserializeReader(allocator: std.mem.Allocator, reader: anytype) !SubmitOrderMessage {
        _ = allocator;
        var msg: SubmitOrderMessage = undefined;

        msg.version = try reader.readInt(u32, .little);
        try reader.readNoEof(&msg.order_id);
        try reader.readNoEof(&msg.item_type);
        msg.item_amount = try reader.readInt(u64, .little);
        try reader.readNoEof(&msg.payment_type);
        msg.payment_amount = try reader.readInt(u64, .little);
        msg.expiration_time = try reader.readInt(u64, .little);

        return msg;
    }

    pub fn checksum(self: *const SubmitOrderMessage) [4]u8 {
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

        return digest[0..4].*;
    }

    pub fn hintSerializedLen(self: *const SubmitOrderMessage) usize {
        _ = self;
        return 4 + 32 + 16 + 8 + 16 + 8 + 8;
    }
};
