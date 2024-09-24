const std = @import("std");
pub const VersionMessage = @import("version.zig").VersionMessage;
pub const VerackMessage = @import("verack.zig").VerackMessage;
pub const MempoolMessage = @import("mempool.zig").MempoolMessage;
pub const GetaddrMessage = @import("getaddr.zig").GetaddrMessage;
pub const PingMessage = @import("ping.zig").PingMessage;

pub const MessageTypes = enum {
    Version,
    Verack,
    Mempool,
    Getaddr,
    Ping,
};

pub const Message = union(MessageTypes) {
    Version: VersionMessage,
    Verack: VerackMessage,
    Mempool: MempoolMessage,
    Getaddr: GetaddrMessage,
    Ping: PingMessage,

    pub fn deinit(self: Message, allocator: std.mem.Allocator) void {
        switch (self) {
            .Version => |m| m.deinit(allocator),
            .Verack => {},
            .Mempool => {},
            .Getaddr => {},
            .Ping => {},
        }
    }
    pub fn checksum(self: Message) [4]u8 {
        return switch (self) {
            .Version => |m| m.checksum(),
            .Verack => |m| m.checksum(),
            .Mempool => |m| m.checksum(),
            .Getaddr => |m| m.checksum(),
            .Ping => |m| m.checksum(),
        };
    }

    pub fn hintSerializedLen(self: Message) usize {
        return switch (self) {
            .Version => |m| m.hintSerializedLen(),
            .Verack => |m| m.hintSerializedLen(),
            .Mempool => |m| m.hintSerializedLen(),
            .Getaddr => |m| m.hintSerializedLen(),
            .Ping => |m| m.hintSerializedLen(),
        };
    }
};
