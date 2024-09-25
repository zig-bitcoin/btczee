const std = @import("std");
pub const VersionMessage = @import("version.zig").VersionMessage;
pub const VerackMessage = @import("verack.zig").VerackMessage;
pub const MempoolMessage = @import("mempool.zig").MempoolMessage;
pub const GetaddrMessage = @import("getaddr.zig").GetaddrMessage;
pub const BlockMessage = @import("block.zig").BlockMessage;
pub const GetblocksMessage = @import("getblocks.zig").GetblocksMessage;
pub const PingMessage = @import("ping.zig").PingMessage;

pub const MessageTypes = enum {
    Version,
    Verack,
    Mempool,
    Getaddr,
    Block,
    Getblocks,
    Ping,
};

pub const Message = union(MessageTypes) {
    Version: VersionMessage,
    Verack: VerackMessage,
    Mempool: MempoolMessage,
    Getaddr: GetaddrMessage,
    Block: BlockMessage,
    Getblocks: GetblocksMessage,
    Ping: PingMessage,

    pub fn deinit(self: *Message, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .Version => |m| m.deinit(allocator),
            .Verack => {},
            .Mempool => {},
            .Getaddr => {},
            .Block => |*m| m.deinit(allocator),
            .Getblocks => |m| m.deinit(allocator),
            .Ping => {},
        }
    }

    pub fn checksum(self: Message) [4]u8 {
        return switch (self) {
            .Version => |m| m.checksum(),
            .Verack => |m| m.checksum(),
            .Mempool => |m| m.checksum(),
            .Getaddr => |m| m.checksum(),
            .Block => |m| m.checksum(),
            .Getblocks => |m| m.checksum(),
            .Ping => |m| m.checksum(),
        };
    }

    pub fn hintSerializedLen(self: Message) usize {
        return switch (self) {
            .Version => |m| m.hintSerializedLen(),
            .Verack => |m| m.hintSerializedLen(),
            .Mempool => |m| m.hintSerializedLen(),
            .Getaddr => |m| m.hintSerializedLen(),
            .Block => |m| m.hintSerializedLen(),
            .Getblocks => |m| m.hintSerializedLen(),
            .Ping => |m| m.hintSerializedLen(),
        };
    }
};
