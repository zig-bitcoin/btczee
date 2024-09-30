const std = @import("std");
pub const VersionMessage = @import("version.zig").VersionMessage;
pub const VerackMessage = @import("verack.zig").VerackMessage;
pub const MempoolMessage = @import("mempool.zig").MempoolMessage;
pub const GetaddrMessage = @import("getaddr.zig").GetaddrMessage;
pub const GetblocksMessage = @import("getblocks.zig").GetblocksMessage;
pub const PingMessage = @import("ping.zig").PingMessage;
pub const PongMessage = @import("pong.zig").PongMessage;
pub const MerkleBlockMessage = @import("merkleblock.zig").MerkleBlockMessage;
pub const FeeFilterMessage = @import("feefilter.zig").FeeFilterMessage;
pub const SendCmpctMessage = @import("sendcmpct.zig").SendCmpctMessage;
pub const FilterClearMessage = @import("filterclear.zig").FilterClearMessage;
pub const FilterAddMessage = @import("filteradd.zig").FilterAddMessage;
const Sha256 = std.crypto.hash.sha2.Sha256;

pub const MessageTypes = enum {
    version,
    verack,
    mempool,
    getaddr,
    getblocks,
    ping,
    pong,
    merkleblock,
    sendcmpct,
    feefilter,
    filterclear,
    filteradd,
};

pub const Message = union(MessageTypes) {
    version: VersionMessage,
    verack: VerackMessage,
    mempool: MempoolMessage,
    getaddr: GetaddrMessage,
    getblocks: GetblocksMessage,
    ping: PingMessage,
    pong: PongMessage,
    merkleblock: MerkleBlockMessage,
    sendcmpct: SendCmpctMessage,
    feefilter: FeeFilterMessage,
    filterclear: FilterClearMessage,
    filteradd: FilterAddMessage,

    pub fn name(self: Message) *const [12]u8 {
        return switch (self) {
            .version => |m| @TypeOf(m).name(),
            .verack => |m| @TypeOf(m).name(),
            .mempool => |m| @TypeOf(m).name(),
            .getaddr => |m| @TypeOf(m).name(),
            .getblocks => |m| @TypeOf(m).name(),
            .ping => |m| @TypeOf(m).name(),
            .pong => |m| @TypeOf(m).name(),
            .merkleblock => |m| @TypeOf(m).name(),
            .sendcmpct => |m| @TypeOf(m).name(),
            .feefilter => |m| @TypeOf(m).name(),
            .filterclear => |m| @TypeOf(m).name(),
            .filteradd => |m| @TypeOf(m).name(),
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
            .merkleblock => |m| m.deinit(allocator),
            .sendcmpct => {},
            .feefilter => {},
            .filterclear => {},
            .filteradd => |m| m.deinit(allocator),
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
            .merkleblock => |m| m.checksum(),
            .sendcmpct => |m| m.checksum(),
            .feefilter => |m| m.checksum(),
            .filterclear => |m| m.checksum(),
            .filteradd => |m| m.checksum(),
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
            .merkleblock => |m| m.hintSerializedLen(),
            .sendcmpct => |m| m.hintSerializedLen(),
            .feefilter => |m| m.hintSerializedLen(),
            .filterclear => |m| m.hintSerializedLen(),
            .filteradd => |m| m.hintSerializedLen(),
        };
    }
};

pub fn checksum(m: anytype, hasPayload: bool) [4]u8 {
    comptime {
        if (!std.meta.hasFn(@TypeOf(m), "serializeToWriter")) @compileError("Expects m to have fn 'serializeToWriter'.");
    }
    if (!hasPayload) {
        return [4]u8{ 0x5d, 0xf6, 0xe0, 0xe2 };
    }

    var digest: [32]u8 = undefined;
    var hasher = Sha256.init(.{});
    m.serializeToWriter(hasher.writer()) catch unreachable;
    hasher.final(&digest);

    Sha256.hash(&digest, &digest, .{});

    return digest[0..4].*;
}
