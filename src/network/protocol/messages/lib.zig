const std = @import("std");
pub const VersionMessage = @import("version.zig").VersionMessage;
pub const VerackMessage = @import("verack.zig").VerackMessage;
pub const MempoolMessage = @import("mempool.zig").MempoolMessage;
pub const GetaddrMessage = @import("getaddr.zig").GetaddrMessage;
pub const BlockMessage = @import("block.zig").BlockMessage;
pub const GetblocksMessage = @import("getblocks.zig").GetblocksMessage;
pub const PingMessage = @import("ping.zig").PingMessage;
pub const PongMessage = @import("pong.zig").PongMessage;
pub const AddrMessage = @import("addr.zig").AddrMessage;
pub const MerkleBlockMessage = @import("merkleblock.zig").MerkleBlockMessage;
pub const FeeFilterMessage = @import("feefilter.zig").FeeFilterMessage;
pub const SendCmpctMessage = @import("sendcmpct.zig").SendCmpctMessage;
pub const FilterClearMessage = @import("filterclear.zig").FilterClearMessage;
pub const GetdataMessage = @import("getdata.zig").GetdataMessage;
pub const Block = @import("block.zig").BlockMessage;
pub const FilterAddMessage = @import("filteradd.zig").FilterAddMessage;
const Sha256 = std.crypto.hash.sha2.Sha256;
pub const NotFoundMessage = @import("notfound.zig").NotFoundMessage;
pub const SendHeadersMessage = @import("sendheaders.zig").SendHeadersMessage;
pub const FilterLoadMessage = @import("filterload.zig").FilterLoadMessage;
pub const GetBlockTxnMessage = @import("getblocktxn.zig").GetBlockTxnMessage;
pub const HeadersMessage = @import("headers.zig").HeadersMessage;
pub const CmpctBlockMessage = @import("cmpctblock.zig").CmpctBlockMessage;

pub const MessageTypes = enum {
    version,
    verack,
    mempool,
    getaddr,
    getblocks,
    ping,
    pong,
    addr,
    merkleblock,
    sendcmpct,
    feefilter,
    filterclear,
    block,
    filteradd,
    notfound,
    sendheaders,
    filterload,
    getblocktxn,
    getdata,
    headers,
    cmpctblock,
};


pub const Message = union(MessageTypes) {
    version: VersionMessage,
    verack: VerackMessage,
    mempool: MempoolMessage,
    getaddr: GetaddrMessage,
    getblocks: GetblocksMessage,
    ping: PingMessage,
    pong: PongMessage,
    addr: AddrMessage,
    merkleblock: MerkleBlockMessage,
    sendcmpct: SendCmpctMessage,
    feefilter: FeeFilterMessage,
    filterclear: FilterClearMessage,
    block: Block,
    filteradd: FilterAddMessage,
    notfound: NotFoundMessage,
    sendheaders: SendHeadersMessage,
    filterload: FilterLoadMessage,
    getblocktxn: GetBlockTxnMessage,
    getdata: GetdataMessage,
    headers: HeadersMessage,
    cmpctblock: CmpctBlockMessage,

    pub fn name(self: Message) *const [12]u8 {
        return switch (self) {
            .version => |m| @TypeOf(m).name(),
            .verack => |m| @TypeOf(m).name(),
            .mempool => |m| @TypeOf(m).name(),
            .getaddr => |m| @TypeOf(m).name(),
            .getblocks => |m| @TypeOf(m).name(),
            .ping => |m| @TypeOf(m).name(),
            .pong => |m| @TypeOf(m).name(),
            .addr => |m| @TypeOf(m).name(),
            .merkleblock => |m| @TypeOf(m).name(),
            .sendcmpct => |m| @TypeOf(m).name(),
            .feefilter => |m| @TypeOf(m).name(),
            .filterclear => |m| @TypeOf(m).name(),
            .block => |m| @TypeOf(m).name(),
            .filteradd => |m| @TypeOf(m).name(),
            .notfound => |m| @TypeOf(m).name(),
            .sendheaders => |m| @TypeOf(m).name(),
            .filterload => |m| @TypeOf(m).name(),
            .getblocktxn => |m| @TypeOf(m).name(),
            .getdata => |m| @TypeOf(m).name(),
            .headers => |m| @TypeOf(m).name(),
            .cmpctblock => |m| @TypeOf(m).name(),
        };
    }

    pub fn deinit(self: *Message, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .version => |*m| m.deinit(allocator),
            .getblocks => |*m| m.deinit(allocator),
            .ping => {},
            .pong => {},
            .addr => |m| m.deinit(allocator),
            .merkleblock => |*m| m.deinit(allocator),
            .block => |*m| m.deinit(allocator),
            .filteradd => |*m| m.deinit(allocator),
            .getdata => |*m| m.deinit(allocator),
            .cmpctblock => |*m| m.deinit(allocator),
            .sendheaders => {},
            .filterload => {},
            .getblocktxn => |*m| m.deinit(allocator),
            .headers => |*m| m.deinit(allocator),
            else => {}
        }
    }

    pub fn checksum(self: *Message) [4]u8 {
        return switch (self.*) {
            .version => |*m| m.checksum(),
            .verack => |*m| m.checksum(),
            .mempool => |*m| m.checksum(),
            .getaddr => |*m| m.checksum(),
            .getblocks => |*m| m.checksum(),
            .ping => |*m| m.checksum(),
            .pong => |*m| m.checksum(),
            .merkleblock => |*m| m.checksum(),
            .sendcmpct => |*m| m.checksum(),
            .feefilter => |*m| m.checksum(),
            .filterclear => |*m| m.checksum(),
            .block => |*m| m.checksum(),
            .filteradd => |*m| m.checksum(),
            .notfound => |*m| m.checksum(),
            .sendheaders => |*m| m.checksum(),
            .filterload => |*m| m.checksum(),
            .getblocktxn => |*m| m.checksum(),
            .addr => |*m| m.checksum(),
            .getdata => |*m| m.checksum(),
            .headers => |*m| m.checksum(),
            .cmpctblock => |*m| m.checksum(),
        };
    }

    pub fn hintSerializedLen(self: *Message) usize {
        return switch (self.*) {
            .version => |*m| m.hintSerializedLen(),
            .verack => |*m| m.hintSerializedLen(),
            .mempool => |*m| m.hintSerializedLen(),
            .getaddr => |*m| m.hintSerializedLen(),
            .getblocks => |*m| m.hintSerializedLen(),
            .ping => |*m| m.hintSerializedLen(),
            .pong => |*m| m.hintSerializedLen(),
            .merkleblock => |*m| m.hintSerializedLen(),
            .sendcmpct => |*m| m.hintSerializedLen(),
            .feefilter => |*m| m.hintSerializedLen(),
            .filterclear => |*m| m.hintSerializedLen(),
            .block => |*m| m.hintSerializedLen(),
            .filteradd => |*m| m.hintSerializedLen(),
            .notfound => |m| m.hintSerializedLen(),
            .sendheaders => |m| m.hintSerializedLen(),
            .filterload => |*m| m.hintSerializedLen(),
            .getblocktxn => |*m| m.hintSerializedLen(),
            .addr => |*m| m.hintSerializedLen(),
            .getdata => |m| m.hintSerializedLen(),
            .headers => |*m| m.hintSerializedLen(),
            .cmpctblock => |*m| m.hintSerializedLen(),
        };
    }
};

pub const default_checksum: [4]u8 = [_]u8{ 0x5d, 0xf6, 0xe0, 0xe2 };

pub fn genericChecksum(m: anytype) [4]u8 {
    comptime {
        if (!std.meta.hasMethod(@TypeOf(m), "serializeToWriter")) @compileError("Expects m to have fn 'serializeToWriter'.");
    }

    var digest: [32]u8 = undefined;
    var hasher = Sha256.init(.{});
    m.serializeToWriter(hasher.writer()) catch unreachable;
    hasher.final(&digest);

    Sha256.hash(&digest, &digest, .{});

    return digest[0..4].*;
}

pub fn genericSerialize(m: anytype, allocator: std.mem.Allocator) ![]u8 {
    comptime {
        if (!std.meta.hasMethod(@TypeOf(m), "hintSerializedLen")) @compileError("Expects m to have fn 'hintSerializedLen'.");
        if (!std.meta.hasMethod(@TypeOf(m), "serializeToWriter")) @compileError("Expects m to have fn 'serializeToWriter'.");
    }
    const serialized_len = m.hintSerializedLen();

    const buffer = try allocator.alloc(u8, serialized_len);
    errdefer allocator.free(buffer);

    var fbs = std.io.fixedBufferStream(buffer);
    try m.serializeToWriter(fbs.writer());

    return buffer;
}

pub fn genericDeserializeSlice(comptime T: type, allocator: std.mem.Allocator, bytes: []const u8) !T {
    if (!std.meta.hasMethod(T, "deserializeReader")) @compileError("Expects T to have fn 'deserializeReader'.");

    var fbs = std.io.fixedBufferStream(bytes);
    const reader = fbs.reader();

    return try T.deserializeReader(allocator, reader);
}
