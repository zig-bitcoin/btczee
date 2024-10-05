//! The logic to read/write bitcoin messages from/to any Zig Reader/Writer.
//!
//! Bitcoin messages are always prefixed by the following header:
//! * network_id: [4]u8
//! * command: [12]u8
//! * payload_len: u32
//! * checksum: [4]u8
//!
//! `command` tells how to read the payload.
//! Error detection is done by checking received messages against their `payload_len` and `checksum`.

const std = @import("std");
const protocol = @import("../protocol/lib.zig");

const Sha256 = std.crypto.hash.sha2.Sha256;

pub const Error = error{
    MessageTooLarge,
};

const BlockHeader = @import("../../types/block_header.zig");

/// Return the checksum of a slice
///
/// Use it on serialized messages to compute the header's value
fn computePayloadChecksum(payload: []u8) [4]u8 {
    var digest: [32]u8 = undefined;
    Sha256.hash(payload, &digest, .{});
    Sha256.hash(&digest, &digest, .{});

    return digest[0..4].*;
}

fn validateMessageSize(payload_len: usize) !void {
    const MAX_SIZE: usize = 0x02000000; // 32 MB
    const precomputed_total_size = 24; // network (4 bytes) + command (12 bytes) + payload size (4 bytes) + checksum (4 bytes)
    const total_message_size = precomputed_total_size + payload_len;

    if (total_message_size > MAX_SIZE) {
        return error.InvalidPayloadLen;
    }
}

/// Send a message through the wire.
///
/// Prefix it with the appropriate header.
pub fn sendMessage(allocator: std.mem.Allocator, w: anytype, protocol_version: i32, network_id: [4]u8, message: anytype) !void {
    comptime {
        if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects r to have fn 'readAll'.");
        if (!std.meta.hasFn(@TypeOf(message), "name")) @compileError("Expects message to have fn 'name'.");
        if (!std.meta.hasFn(@TypeOf(message), "serialize")) @compileError("Expects message to have fn 'serialize'.");
    }

    // Not used right now.
    // As we add more messages, we will need to create multiple dedicated
    // methods like this one to handle different messages in different
    // way depending on the version of the protocol used
    _ = protocol_version;

    const command = comptime @TypeOf(message).name();

    const payload: []u8 = try message.serialize(allocator);
    defer allocator.free(payload);
    const checksum = computePayloadChecksum(payload);

    const payload_len: u32 = @intCast(payload.len);

    try validateMessageSize(payload_len);

    try w.writeAll(&network_id);
    try w.writeAll(command);
    try w.writeAll(std.mem.asBytes(&payload_len));
    try w.writeAll(std.mem.asBytes(&checksum));
    try w.writeAll(payload);
}

pub const ReceiveMessageError = error{ UnknownMessage, InvalidPayloadLen, InvalidChecksum, InvalidHandshake, InvalidNetwork };

/// Read a message from the wire.
///
/// Will fail if the header content does not match the payload.
pub fn receiveMessage(
    allocator: std.mem.Allocator,
    r: anytype,
    our_network: [4]u8,
) !?protocol.messages.Message {
    comptime {
        if (!std.meta.hasFn(@TypeOf(r), "readBytesNoEof")) @compileError("Expects r to have fn 'readBytesNoEof'.");
        if (!std.meta.hasFn(@TypeOf(r), "readByte")) @compileError("Expects r to have fn 'readByte'.");
        if (!std.meta.hasFn(@TypeOf(r), "readNoEof")) @compileError("Expects r to have fn 'readNoEof'.");
    }

    // Read header
    var network_id: [4]u8 = undefined;

    network_id[0] = r.readByte() catch |e| switch (e) {
        error.EndOfStream => return null,
        else => return e,
    };
    try r.readNoEof(network_id[1..]);

    if (!std.mem.eql(u8, &network_id, &our_network)) {
        return error.InvalidNetwork;
    }

    const command = try r.readBytesNoEof(12);
    const payload_len = try r.readInt(u32, .little);
    const checksum = try r.readBytesNoEof(4);

    try validateMessageSize(payload_len);

    // Read payload
    var message: protocol.messages.Message = if (std.mem.eql(u8, &command, protocol.messages.VersionMessage.name()))
        protocol.messages.Message{ .version = try protocol.messages.VersionMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.VerackMessage.name()))
        protocol.messages.Message{ .verack = try protocol.messages.VerackMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.MempoolMessage.name()))
        protocol.messages.Message{ .mempool = try protocol.messages.MempoolMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.GetaddrMessage.name()))
        protocol.messages.Message{ .getaddr = try protocol.messages.GetaddrMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.BlockMessage.name()))
        protocol.messages.Message{ .block = try protocol.messages.BlockMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.GetblocksMessage.name()))
        protocol.messages.Message{ .getblocks = try protocol.messages.GetblocksMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.PingMessage.name()))
        protocol.messages.Message{ .ping = try protocol.messages.PingMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.PongMessage.name()))
        protocol.messages.Message{ .pong = try protocol.messages.PongMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.MerkleBlockMessage.name()))
        protocol.messages.Message{ .merkleblock = try protocol.messages.MerkleBlockMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.SendCmpctMessage.name()))
        protocol.messages.Message{ .sendcmpct = try protocol.messages.SendCmpctMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.FilterClearMessage.name()))
        protocol.messages.Message{ .filterclear = try protocol.messages.FilterClearMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.FilterAddMessage.name()))
        protocol.messages.Message{ .filteradd = try protocol.messages.FilterAddMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.NotFoundMessage.name()))
        protocol.messages.Message{ .notfound = try protocol.messages.NotFoundMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.FeeFilterMessage.name()))
        protocol.messages.Message{ .feefilter = try protocol.messages.FeeFilterMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.SendHeadersMessage.name()))
        protocol.messages.Message{ .sendheaders = try protocol.messages.SendHeadersMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.FilterLoadMessage.name()))
        protocol.messages.Message{ .filterload = try protocol.messages.FilterLoadMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.GetBlockTxnMessage.name()))
        protocol.messages.Message{ .getblocktxn = try protocol.messages.GetBlockTxnMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.GetdataMessage.name()))
        protocol.messages.Message{ .getdata = try protocol.messages.GetdataMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.CmpctBlockMessage.name()))
        protocol.messages.Message{ .cmpctblock = try protocol.messages.CmpctBlockMessage.deserializeReader(allocator, r) }
    else {
        try r.skipBytes(payload_len, .{}); // Purge the wire
        return error.UnknownMessage;
    };
    errdefer message.deinit(allocator);

    if (!std.mem.eql(u8, &message.checksum(), &checksum)) {
        return error.InvalidChecksum;
    }
    if (message.hintSerializedLen() != payload_len) {
        return error.InvalidPayloadLen;
    }

    return message;
}

// TESTS
fn write_and_read_message(allocator: std.mem.Allocator, list: *std.ArrayList(u8), network_id: [4]u8, protocol_version: i32, message: anytype) !?protocol.messages.Message {
    const writer = list.writer();
    try sendMessage(allocator, writer, protocol_version, network_id, message);
    var fbs: std.io.FixedBufferStream([]u8) = std.io.fixedBufferStream(list.items);
    const reader = fbs.reader();

    return receiveMessage(allocator, reader, network_id);
}

test "ok_send_version_message" {
    const Config = @import("../../config/config.zig").Config;
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const VersionMessage = protocol.messages.VersionMessage;
    const ServiceFlags = protocol.ServiceFlags;

    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
    defer list.deinit();

    const user_agent = [_]u8{0} ** 2023;
    const message = VersionMessage{
        .version = 42,
        .services = ServiceFlags.NODE_NETWORK,
        .timestamp = 43,
        .recv_services = ServiceFlags.NODE_WITNESS,
        .trans_services = ServiceFlags.NODE_BLOOM,
        .recv_ip = [_]u8{13} ** 16,
        .trans_ip = [_]u8{12} ** 16,
        .recv_port = 33,
        .trans_port = 22,
        .nonce = 31,
        .user_agent = &user_agent,
        .start_height = 1000,
        .relay = false,
    };
    var received_message = try write_and_read_message(
        test_allocator,
        &list,
        Config.BitcoinNetworkId.MAINNET,
        Config.PROTOCOL_VERSION,
        message,
    ) orelse unreachable;
    defer received_message.deinit(test_allocator);

    switch (received_message) {
        .version => |rm| try std.testing.expect(message.eql(&rm)),
        else => unreachable,
    }
}

test "ok_send_verack_message" {
    const Config = @import("../../config/config.zig").Config;
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const VerackMessage = protocol.messages.VerackMessage;

    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
    defer list.deinit();

    const message = VerackMessage{};

    var received_message = try write_and_read_message(
        test_allocator,
        &list,
        Config.BitcoinNetworkId.MAINNET,
        Config.PROTOCOL_VERSION,
        message,
    ) orelse unreachable;
    defer received_message.deinit(test_allocator);

    switch (received_message) {
        .verack => {},
        else => unreachable,
    }
}

test "ok_send_mempool_message" {
    const Config = @import("../../config/config.zig").Config;
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const MempoolMessage = protocol.messages.MempoolMessage;

    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
    defer list.deinit();

    const message = MempoolMessage{};

    var received_message = try write_and_read_message(
        test_allocator,
        &list,
        Config.BitcoinNetworkId.MAINNET,
        Config.PROTOCOL_VERSION,
        message,
    ) orelse unreachable;
    defer received_message.deinit(test_allocator);

    switch (received_message) {
        .mempool => {},
        else => unreachable,
    }
}

test "ok_send_getdata_message" {
    const Config = @import("../../config/config.zig").Config;
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const GetdataMessage = protocol.messages.GetdataMessage;

    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
    defer list.deinit();

    const inventory = try test_allocator.alloc(protocol.InventoryItem, 5);
    defer test_allocator.free(inventory);

    for (inventory) |*item| {
        item.type = 1;
        for (&item.hash) |*byte| {
            byte.* = 0xab;
        }
    }

    const message = GetdataMessage{
        .inventory = inventory,
    };

    var received_message = try write_and_read_message(
        test_allocator,
        &list,
        Config.BitcoinNetworkId.MAINNET,
        Config.PROTOCOL_VERSION,
        message,
    ) orelse unreachable;
    defer received_message.deinit(test_allocator);

    switch (received_message) {
        .getdata => |rm| try std.testing.expect(message.eql(&rm)),
        else => unreachable,
    }
}

test "ok_send_getblocks_message" {
    const Config = @import("../../config/config.zig").Config;

    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const GetblocksMessage = protocol.messages.GetblocksMessage;

    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
    defer list.deinit();

    const message = GetblocksMessage{
        .version = 42,
        .header_hashes = try test_allocator.alloc([32]u8, 2),
        .stop_hash = [_]u8{0} ** 32,
    };

    defer test_allocator.free(message.header_hashes);

    // Fill in the header_hashes
    for (message.header_hashes) |*hash| {
        for (hash) |*byte| {
            byte.* = 0xab;
        }
    }

    var received_message = try write_and_read_message(
        test_allocator,
        &list,
        Config.BitcoinNetworkId.MAINNET,
        Config.PROTOCOL_VERSION,
        message,
    ) orelse unreachable;
    defer received_message.deinit(test_allocator);

    switch (received_message) {
        .getblocks => |rm| try std.testing.expect(message.eql(&rm)),
        else => unreachable,
    }
}

test "ok_send_ping_message" {
    const Config = @import("../../config/config.zig").Config;
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const PingMessage = protocol.messages.PingMessage;

    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
    defer list.deinit();

    const message = PingMessage.new(21000000);

    var received_message = try write_and_read_message(
        test_allocator,
        &list,
        Config.BitcoinNetworkId.MAINNET,
        Config.PROTOCOL_VERSION,
        message,
    ) orelse unreachable;
    defer received_message.deinit(test_allocator);

    switch (received_message) {
        .ping => |ping_message| try std.testing.expectEqual(message.nonce, ping_message.nonce),
        else => unreachable,
    }
}

test "ok_send_merkleblock_message" {
    const Config = @import("../../config/config.zig").Config;
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const MerkleBlockMessage = protocol.messages.MerkleBlockMessage;

    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
    defer list.deinit();

    const block_header = BlockHeader{
        .version = 1,
        .prev_block = [_]u8{0} ** 32,
        .merkle_root = [_]u8{1} ** 32,
        .timestamp = 1234567890,
        .nbits = 0x1d00ffff,
        .nonce = 987654321,
    };
    const hashes = try test_allocator.alloc([32]u8, 3);

    const flags = try test_allocator.alloc(u8, 1);
    const transaction_count = 1;
    const message = MerkleBlockMessage.new(block_header, transaction_count, hashes, flags);

    defer message.deinit(test_allocator);
    // Fill in the header_hashes
    for (message.hashes) |*hash| {
        for (hash) |*byte| {
            byte.* = 0xab;
        }
    }
    flags[0] = 0x1;

    const serialized = try message.serialize(test_allocator);
    defer test_allocator.free(serialized);

    const deserialized = try MerkleBlockMessage.deserializeSlice(test_allocator, serialized);
    defer deserialized.deinit(test_allocator);

    var received_message = try write_and_read_message(test_allocator, &list, Config.BitcoinNetworkId.MAINNET, Config.PROTOCOL_VERSION, message) orelse unreachable;
    defer received_message.deinit(test_allocator);

    switch (received_message) {
        .merkleblock => {},
        else => unreachable,
    }

    try std.testing.expectEqual(received_message.hintSerializedLen(), 183);
    try std.testing.expectEqualSlices(u8, received_message.merkleblock.flags, flags);
    try std.testing.expectEqual(received_message.merkleblock.transaction_count, transaction_count);
    try std.testing.expectEqualSlices([32]u8, received_message.merkleblock.hashes, hashes);
}

test "ok_send_pong_message" {
    const Config = @import("../../config/config.zig").Config;
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const PongMessage = protocol.messages.PongMessage;

    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
    defer list.deinit();

    const message = PongMessage.new(21000000);

    var received_message = try write_and_read_message(
        test_allocator,
        &list,
        Config.BitcoinNetworkId.MAINNET,
        Config.PROTOCOL_VERSION,
        message,
    ) orelse unreachable;
    defer received_message.deinit(test_allocator);

    switch (received_message) {
        .pong => |pong_message| try std.testing.expectEqual(message.nonce, pong_message.nonce),
        else => unreachable,
    }
}

test "ok_send_sendheaders_message" {
    const Config = @import("../../config/config.zig").Config;
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const SendHeadersMessage = protocol.messages.SendHeadersMessage;

    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
    defer list.deinit();

    const message = SendHeadersMessage.new();

    var received_message = try write_and_read_message(
        test_allocator,
        &list,
        Config.BitcoinNetworkId.MAINNET,
        Config.PROTOCOL_VERSION,
        message,
    ) orelse unreachable;
    defer received_message.deinit(test_allocator);

    switch (received_message) {
        .sendheaders => {},
        else => unreachable,
    }
}

test "ok_send_getblocktxn_message" {
    const Config = @import("../../config/config.zig").Config;
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const GetBlockTxnMessage = protocol.messages.GetBlockTxnMessage;

    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
    defer list.deinit();

    const block_hash = [_]u8{1} ** 32;
    const indexes = try test_allocator.alloc(u64, 1);
    indexes[0] = 1;
    const message = GetBlockTxnMessage.new(block_hash, indexes);
    defer message.deinit(test_allocator);
    var received_message = try write_and_read_message(
        test_allocator,
        &list,
        Config.BitcoinNetworkId.MAINNET,
        Config.PROTOCOL_VERSION,
        message,
    ) orelse unreachable;
    defer received_message.deinit(test_allocator);

    switch (received_message) {
        .getblocktxn => {
            try std.testing.expectEqual(message.block_hash, received_message.getblocktxn.block_hash);
            try std.testing.expectEqual(indexes[0], received_message.getblocktxn.indexes[0]);
        },
        else => unreachable,
    }
}

test "ko_receive_invalid_payload_length" {
    const Config = @import("../../config/config.zig").Config;
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const VersionMessage = protocol.messages.VersionMessage;
    const ServiceFlags = protocol.ServiceFlags;

    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
    defer list.deinit();

    const user_agent = [_]u8{0} ** 2;
    const message = VersionMessage{
        .version = 42,
        .services = ServiceFlags.NODE_NETWORK,
        .timestamp = 43,
        .recv_services = ServiceFlags.NODE_WITNESS,
        .trans_services = ServiceFlags.NODE_BLOOM,
        .recv_ip = [_]u8{13} ** 16,
        .trans_ip = [_]u8{12} ** 16,
        .recv_port = 33,
        .trans_port = 22,
        .nonce = 31,
        .user_agent = &user_agent,
        .start_height = 1000,
        .relay = false,
    };

    const writer = list.writer();
    const network_id = Config.BitcoinNetworkId.MAINNET;
    try sendMessage(test_allocator, writer, Config.PROTOCOL_VERSION, network_id, message);

    // Corrupt header payload length
    @memset(list.items[16..20], 42);

    var fbs: std.io.FixedBufferStream([]u8) = std.io.fixedBufferStream(list.items);
    const reader = fbs.reader();

    try std.testing.expectError(error.InvalidPayloadLen, receiveMessage(test_allocator, reader, network_id));
}

test "ko_receive_invalid_checksum" {
    const Config = @import("../../config/config.zig").Config;
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const VersionMessage = protocol.messages.VersionMessage;
    const ServiceFlags = protocol.ServiceFlags;

    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
    defer list.deinit();

    const user_agent = [_]u8{0} ** 2;
    const message = VersionMessage{
        .version = 42,
        .services = ServiceFlags.NODE_NETWORK,
        .timestamp = 43,
        .recv_services = ServiceFlags.NODE_WITNESS,
        .trans_services = ServiceFlags.NODE_BLOOM,
        .recv_ip = [_]u8{13} ** 16,
        .trans_ip = [_]u8{12} ** 16,
        .recv_port = 33,
        .trans_port = 22,
        .nonce = 31,
        .user_agent = &user_agent,
        .start_height = 1000,
        .relay = false,
    };

    const writer = list.writer();
    const network_id = Config.BitcoinNetworkId.MAINNET;
    try sendMessage(test_allocator, writer, Config.PROTOCOL_VERSION, network_id, message);

    // Corrupt header checksum
    @memset(list.items[20..24], 42);

    var fbs: std.io.FixedBufferStream([]u8) = std.io.fixedBufferStream(list.items);
    const reader = fbs.reader();

    try std.testing.expectError(error.InvalidChecksum, receiveMessage(test_allocator, reader, network_id));
}

test "ko_receive_invalid_command" {
    const Config = @import("../../config/config.zig").Config;
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const VersionMessage = protocol.messages.VersionMessage;
    const ServiceFlags = protocol.ServiceFlags;

    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
    defer list.deinit();

    const user_agent = [_]u8{0} ** 2;
    const message = VersionMessage{
        .version = 42,
        .services = ServiceFlags.NODE_NETWORK,
        .timestamp = 43,
        .recv_services = ServiceFlags.NODE_WITNESS,
        .trans_services = ServiceFlags.NODE_BLOOM,
        .recv_ip = [_]u8{13} ** 16,
        .trans_ip = [_]u8{12} ** 16,
        .recv_port = 33,
        .trans_port = 22,
        .nonce = 31,
        .user_agent = &user_agent,
        .start_height = 1000,
        .relay = false,
    };

    const writer = list.writer();
    const network_id = Config.BitcoinNetworkId.MAINNET;
    try sendMessage(test_allocator, writer, Config.PROTOCOL_VERSION, network_id, message);

    // Corrupt header command
    @memcpy(list.items[4..16], "whoissatoshi");

    var fbs: std.io.FixedBufferStream([]u8) = std.io.fixedBufferStream(list.items);
    const reader = fbs.reader();

    try std.testing.expectError(error.UnknownMessage, receiveMessage(test_allocator, reader, network_id));
}

test "ok_send_sendcmpct_message" {
    const Config = @import("../../config/config.zig").Config;
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const SendCmpctMessage = protocol.messages.SendCmpctMessage;

    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
    defer list.deinit();

    const message = SendCmpctMessage{
        .announce = true,
        .version = 1,
    };

    var received_message = try write_and_read_message(
        test_allocator,
        &list,
        Config.BitcoinNetworkId.MAINNET,
        Config.PROTOCOL_VERSION,
        message,
    ) orelse unreachable;
    defer received_message.deinit(test_allocator);

    switch (received_message) {
        .sendcmpct => |sendcmpct_message| try std.testing.expect(message.eql(&sendcmpct_message)),
        else => unreachable,
    }
}

test "ok_send_cmpctblock_message" {
    const Transaction = @import("../../types/transaction.zig");
    const OutPoint = @import("../../types/outpoint.zig");
    const OpCode = @import("../../script/opcodes/constant.zig").Opcode;
    const Hash = @import("../../types/hash.zig");
    const Script = @import("../../types/script.zig");
    const CmpctBlockMessage = @import("../protocol/messages/cmpctblock.zig").CmpctBlockMessage;

    const allocator = std.testing.allocator;

    // Create a sample BlockHeader
    const header = BlockHeader{
        .version = 1,
        .prev_block = [_]u8{0} ** 32, // Zero-filled array of 32 bytes
        .merkle_root = [_]u8{0} ** 32, // Zero-filled array of 32 bytes
        .timestamp = 1631234567,
        .nbits = 0x1d00ffff,
        .nonce = 12345,
    };

    // Create sample short_ids
    const short_ids = try allocator.alloc(u64, 2);
    defer allocator.free(short_ids);
    short_ids[0] = 123456789;
    short_ids[1] = 987654321;

    // Create a sample Transaction
    var tx = try Transaction.init(allocator);
    defer tx.deinit();
    try tx.addInput(OutPoint{ .hash = Hash.newZeroed(), .index = 0 });
    {
        var script_pubkey = try Script.init(allocator);
        defer script_pubkey.deinit();
        try script_pubkey.push(&[_]u8{ OpCode.OP_DUP.toBytes(), OpCode.OP_HASH160.toBytes(), OpCode.OP_EQUALVERIFY.toBytes(), OpCode.OP_CHECKSIG.toBytes() });
        try tx.addOutput(50000, script_pubkey);
    }

    // Create sample prefilled_txns
    const prefilled_txns = try allocator.alloc(CmpctBlockMessage.PrefilledTransaction, 1);
    defer allocator.free(prefilled_txns);
    prefilled_txns[0] = .{
        .index = 0,
        .tx = tx,
    };

    // Create CmpctBlockMessage
    const msg = CmpctBlockMessage{
        .header = header,
        .nonce = 9876543210,
        .short_ids = short_ids,
        .prefilled_txns = prefilled_txns,
    };

    // Test serialization
    const serialized = try msg.serialize(allocator);
    defer allocator.free(serialized);

    // Test deserialization
    var deserialized = try CmpctBlockMessage.deserializeSlice(allocator, serialized);
    defer deserialized.deinit(allocator);

    // Verify deserialized data
    try std.testing.expect(msg.eql(&deserialized));

    // Test hintSerializedLen
    const hint_len = msg.hintSerializedLen();
    try std.testing.expect(hint_len > 0);
    try std.testing.expect(hint_len == serialized.len);
}
