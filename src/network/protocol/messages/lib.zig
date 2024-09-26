const std = @import("std");
pub const VersionMessage = @import("version.zig").VersionMessage;
pub const VerackMessage = @import("verack.zig").VerackMessage;
pub const MempoolMessage = @import("mempool.zig").MempoolMessage;
pub const GetaddrMessage = @import("getaddr.zig").GetaddrMessage;
pub const GetblocksMessage = @import("getblocks.zig").GetblocksMessage;
pub const PingMessage = @import("ping.zig").PingMessage;
pub const PongMessage = @import("pong.zig").PongMessage;

pub const MessageTypes = enum {
    version,
    verack,
    mempool,
    getaddr,
    getblocks,
    ping,
    pong,
};

pub const Message = union(MessageTypes) {
    version: VersionMessage,
    verack: VerackMessage,
    mempool: MempoolMessage,
    getaddr: GetaddrMessage,
    getblocks: GetblocksMessage,
    ping: PingMessage,
    pong: PongMessage,

    pub fn name(self: Message) *const [12]u8 {
        return switch (self) {
            .version => |m| @TypeOf(m).name(),
            .verack => |m| @TypeOf(m).name(),
            .mempool => |m| @TypeOf(m).name(),
            .getaddr => |m| @TypeOf(m).name(),
            .getblocks => |m| @TypeOf(m).name(),
            .ping => |m| @TypeOf(m).name(),
            .pong => |m| @TypeOf(m).name(),
        };
    }

    pub fn deinit(self: Message, allocator: std.mem.Allocator) void {
        switch (self) {
            .version => |m| m.deinit(allocator),
            .verack => {},
            .mempool => {},
            .getaddr => {},
            .getblocks => |m| m.deinit(allocator),
            .ping => {},
            .pong => {},
        }
    }
    pub fn checksum(self: Message) [4]u8 {
        return switch (self) {
            .version => |m| m.checksum(),
            .verack => |m| m.checksum(),
            .mempool => |m| m.checksum(),
            .getaddr => |m| m.checksum(),
            .getblocks => |m| m.checksum(),
            .ping => |m| m.checksum(),
            .pong => |m| m.checksum(),
        };
    }

    pub fn hintSerializedLen(self: Message) usize {
        return switch (self) {
            .version => |m| m.hintSerializedLen(),
            .verack => |m| m.hintSerializedLen(),
            .mempool => |m| m.hintSerializedLen(),
            .getaddr => |m| m.hintSerializedLen(),
            .getblocks => |m| m.hintSerializedLen(),
            .ping => |m| m.hintSerializedLen(),
            .pong => |m| m.hintSerializedLen(),
        };
    }
};
