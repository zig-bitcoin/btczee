const std = @import("std");
pub const VersionMessage = @import("version.zig").VersionMessage;
pub const VerackMessage = @import("verack.zig").VerackMessage;
pub const MempoolMessage = @import("mempool.zig").MempoolMessage;
pub const GetaddrMessage = @import("getaddr.zig").GetaddrMessage;
pub const BlockMessage = @import("block.zig").BlockMessage;

pub const MessageTypes = enum {
    Version,
    Verack,
    Mempool,
    Getaddr,
    Block,
};

pub const Message = union(MessageTypes) {
    Version: VersionMessage,
    Verack: VerackMessage,
    Mempool: MempoolMessage,
    Getaddr: GetaddrMessage,
    Block: BlockMessage,

    pub fn deinit(self: *Message, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .Version => |m| m.deinit(allocator),
            .Verack => {},
            .Mempool => {},
            .Getaddr => {},
            .Block => |*m| @constCast(m).deinit(allocator),
        }
    }
    pub fn checksum(self: Message) [4]u8 {
        return switch (self) {
            .Version => |m| m.checksum(),
            .Verack => |m| m.checksum(),
            .Mempool => |m| m.checksum(),
            .Getaddr => |m| m.checksum(),
            .Block => |m| m.checksum(),
        };
    }

    pub fn hintSerializedLen(self: Message) usize {
        return switch (self) {
            .Version => |m| m.hintSerializedLen(),
            .Verack => |m| m.hintSerializedLen(),
            .Mempool => |m| m.hintSerializedLen(),
            .Getaddr => |m| m.hintSerializedLen(),
            .Block => |m| m.hintSerializedLen(),
        };
    }
};
