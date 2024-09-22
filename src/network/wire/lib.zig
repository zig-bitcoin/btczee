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
const MAX_SIZE: usize = 0x02000000; // 32 MB

pub const Error = error{
    MessageTooLarge,
};

pub const NetworkIPAddr = @import("../protocol/messages/addr.zig").NetworkIPAddr;
const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;

/// Return the checksum of a slice
///
/// Use it on serialized messages to compute the header's value
fn computePayloadChecksum(payload: []u8) [4]u8 {
    var digest: [32]u8 = undefined;
    Sha256.hash(payload, &digest, .{});
    Sha256.hash(&digest, &digest, .{});

    return digest[0..4].*;
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

    // Calculate total message size
    const precomputed_total_size = 24; // network (4 bytes) + command (12 bytes) + payload size (4 bytes) + checksum (4 bytes)
    const total_message_size = precomputed_total_size + payload_len;

    if (total_message_size > MAX_SIZE) {
        return Error.MessageTooLarge;
    }

    try w.writeAll(&network_id);
    try w.writeAll(command);
    try w.writeAll(std.mem.asBytes(&payload_len));
    try w.writeAll(std.mem.asBytes(&checksum));
    try w.writeAll(payload);
}

pub const ReceiveMessageError = error{ UnknownMessage, InvaliPayloadLen, InvalidChecksum, InvalidHandshake, InvalidNetwork };

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

    // Read payload
    const message: protocol.messages.Message = if (std.mem.eql(u8, &command, protocol.messages.VersionMessage.name()))
        protocol.messages.Message{ .version = try protocol.messages.VersionMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.VerackMessage.name()))
        protocol.messages.Message{ .verack = try protocol.messages.VerackMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.MempoolMessage.name()))
        protocol.messages.Message{ .mempool = try protocol.messages.MempoolMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.GetaddrMessage.name()))
        protocol.messages.Message{ .getaddr = try protocol.messages.GetaddrMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.GetblocksMessage.name()))
        protocol.messages.Message{ .getblocks = try protocol.messages.GetblocksMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.PingMessage.name()))
        protocol.messages.Message{ .ping = try protocol.messages.PingMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.PongMessage.name()))
        protocol.messages.Message{ .pong = try protocol.messages.PongMessage.deserializeReader(allocator, r) }
    else {
        try r.skipBytes(payload_len, .{}); // Purge the wire
        return error.UnknownMessage;
    };
        protocol.messages.Message{ .Getaddr = try protocol.messages.GetaddrMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.AddrMessage.name()))
        protocol.messages.Message{ .Addr = try protocol.messages.AddrMessage.deserializeReader(allocator, r) }
    else
        return error.InvalidCommand;
    errdefer message.deinit(allocator);

    if (!std.mem.eql(u8, &message.checksum(), &checksum)) {
        return error.InvalidChecksum;
    }
    if (message.hintSerializedLen() != payload_len) {
        return error.InvaliPayloadLen;
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
    const received_message = try write_and_read_message(
        test_allocator,
        &list,
        Config.BitcoinNetworkId.MAINNET,
        Config.PROTOCOL_VERSION,
        message,
    ) orelse unreachable;
    defer received_message.deinit(test_allocator);

    switch (received_message) {
        .Version => |rm| try std.testing.expect(message.eql(&rm)),
        .Verack => unreachable,
        .Mempool => unreachable,
        .Getaddr => unreachable,
        .Addr => unreachable,
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

    const received_message = try write_and_read_message(
        test_allocator,
        &list,
        Config.BitcoinNetworkId.MAINNET,
        Config.PROTOCOL_VERSION,
        message,
    ) orelse unreachable;
    defer received_message.deinit(test_allocator);

    switch (received_message) {
        .Verack => {},
        .Version => unreachable,
        .Mempool => unreachable,
        .Getaddr => unreachable,
        .Addr => unreachable,
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

    const received_message = try write_and_read_message(
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

test "ok_send_getblocks_message" {
    const Config = @import("../../config/config.zig").Config;

    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const GetblocksMessage = protocol.messages.GetblocksMessage;
        .Mempool => {},
        .Verack => unreachable,
        .Version => unreachable,
        .Getaddr => unreachable,
        .Addr => unreachable,
    }
}

test "ok_send_addr_message" {
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const AddrMessage = protocol.messages.AddrMessage;
//    const NetworkIPAddr = protocol.messages.NetworkIPAddr;
    const ServiceFlags = protocol.ServiceFlags;

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

    const received_message = try write_and_read_message(
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

    const received_message = try write_and_read_message(
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

test "ok_send_pong_message" {
    const Config = @import("../../config/config.zig").Config;
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const PongMessage = protocol.messages.PongMessage;

    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
    defer list.deinit();

    const message = PongMessage.new(21000000);

    const received_message = try write_and_read_message(
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
    var ips = [_]NetworkIPAddr{
        NetworkIPAddr{
        .time = 42,
        .services = ServiceFlags.NODE_NETWORK,
        .ip = [_]u8{13} ** 16,
        .port = 33,
        
        }, 
    };
    const message = AddrMessage{
        .ip_address_count = CompactSizeUint.new(1),
        .ip_addresses = ips[0..],
    };

    const writer = list.writer();
    try sendMessage(test_allocator, writer, protocol.PROTOCOL_VERSION, protocol.BitcoinNetworkId.MAINNET, message);
    var fbs: std.io.FixedBufferStream([]u8) = std.io.fixedBufferStream(list.items);
    const reader = fbs.reader();

    const received_message = try receiveMessage(test_allocator, reader);
    defer received_message.deinit(test_allocator);

    switch (received_message) {
        .Addr => |rm| try std.testing.expect(message.eql(&rm)),
        .Version => unreachable,
        .Verack => unreachable,
        .Mempool => unreachable,
        .Getaddr => unreachable,
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

    try std.testing.expectError(error.InvaliPayloadLen, receiveMessage(test_allocator, reader, network_id));
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
