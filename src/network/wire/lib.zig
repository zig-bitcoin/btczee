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

const Stream = std.net.Stream;
const io = std.io;
const Sha256 = std.crypto.hash.sha2.Sha256;

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

    // No payload will be longer than u32.MAX
    const payload_len: u32 = @intCast(payload.len);

    try w.writeAll(&network_id);
    try w.writeAll(command);
    try w.writeAll(std.mem.asBytes(&payload_len));
    try w.writeAll(std.mem.asBytes(&checksum));
    try w.writeAll(payload);
}

pub const ReceiveMessageError = error{ InvalidCommand, InvaliPayloadLen, InvalidChecksum };

/// Read a message from the wire.
///
/// Will fail if the header content does not match the payload.
pub fn receiveMessage(allocator: std.mem.Allocator, r: anytype) !protocol.messages.Message {
    comptime {
        if (!std.meta.hasFn(@TypeOf(r), "readBytesNoEof")) @compileError("Expects r to have fn 'readBytesNoEof'.");
    }

    // Read header
    _ = try r.readBytesNoEof(4); // Network id
    const command = try r.readBytesNoEof(12);
    const payload_len = try r.readInt(u32, .little);
    const checksum = try r.readBytesNoEof(4);

    // Read payload
    const message: protocol.messages.Message = if (std.mem.eql(u8, &command, protocol.messages.VersionMessage.name()))
        protocol.messages.Message{ .Version = try protocol.messages.VersionMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.VerackMessage.name()))

        protocol.messages.Message{ .Verack = try protocol.messages.VerackMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.MempoolMessage.name()))
        protocol.messages.Message{ .Mempool = try protocol.messages.MempoolMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.GetaddrMessage.name()))
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

test "ok_send_version_message" {
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

    const writer = list.writer();
    try sendMessage(test_allocator, writer, protocol.PROTOCOL_VERSION, protocol.BitcoinNetworkId.MAINNET, message);
    var fbs: std.io.FixedBufferStream([]u8) = std.io.fixedBufferStream(list.items);
    const reader = fbs.reader();

    const received_message = try receiveMessage(test_allocator, reader);
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
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const VerackMessage = protocol.messages.VerackMessage;

    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
    defer list.deinit();

    const message = VerackMessage{};

    const writer = list.writer();
    try sendMessage(test_allocator, writer, protocol.PROTOCOL_VERSION, protocol.BitcoinNetworkId.MAINNET, message);
    var fbs: std.io.FixedBufferStream([]u8) = std.io.fixedBufferStream(list.items);
    const reader = fbs.reader();

    const received_message = try receiveMessage(test_allocator, reader);
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
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const MempoolMessage = protocol.messages.MempoolMessage;

    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
    defer list.deinit();

    const message = MempoolMessage{};

    const writer = list.writer();
    try sendMessage(test_allocator, writer, protocol.PROTOCOL_VERSION, protocol.BitcoinNetworkId.MAINNET, message);
    var fbs: std.io.FixedBufferStream([]u8) = std.io.fixedBufferStream(list.items);
    const reader = fbs.reader();

    const received_message = try receiveMessage(test_allocator, reader);
    defer received_message.deinit(test_allocator);

    switch (received_message) {
        .Mempool => {},
        .Verack => unreachable,
        .Version => unreachable,
        .Getaddr => unreachable,
        .Addr => unreachable,
    }
}

//test "ok_send_addr_message" {
//    const ArrayList = std.ArrayList;
//    const test_allocator = std.testing.allocator;
//    const AddrMessage = protocol.messages.AddrMessage;
//    //const ServiceFlags = protocol.ServiceFlags;
//
//    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
//    defer list.deinit();
//
//    // Create an ArrayList for NetworkIPAddr
//    //var ips = ArrayList(NetworkIPAddr).init(test_allocator);
//    //defer ips.deinit();
//
//    //try ips.append(
//    //    NetworkIPAddr{
//    //    .time = 42,
//    //    .services = ServiceFlags.NODE_NETWORK,
//    //    .ip = [_]u8{13} ** 16,
//    //    .port = 33,
//    //    
//    //    });
//    //const message = AddrMessage{
//    //    //.ip_address_count = CompactSizeUint.new(1),
//    //    .ip_addresses = ips,
//    //};
//    var message = AddrMessage.init(test_allocator);
//    defer message.deinit();
//
//    try message.ip_addresses.append(NetworkIPAddr{
//        .time = 1414012889,
//        .services = 1,
//        .ip = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff, 192, 0, 2, 51 },
//        .port = 8333,
//    //        .time = 42,
//    //        .services = ServiceFlags.NODE_NETWORK,
//    //        .ip = [_]u8{13} ** 16,
//    //        .port = 33,
//    });
//
//
//    const writer = list.writer();
//    try sendMessage(test_allocator, writer, protocol.PROTOCOL_VERSION, protocol.BitcoinNetworkId.MAINNET, message);
//    var fbs: std.io.FixedBufferStream([]u8) = std.io.fixedBufferStream(list.items);
//    const reader = fbs.reader();
//
//    const received_message = try receiveMessage(test_allocator, reader);
//    defer received_message.deinit(test_allocator);
//
//    switch (received_message) {
//        .Addr => |rm| try std.testing.expect(message.eql(&rm)),
//        .Version => unreachable,
//        .Verack => unreachable,
//        .Mempool => unreachable,
//        .Getaddr => unreachable,
//    }
//}

test "ok_send_addr_message" {
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const AddrMessage = protocol.messages.AddrMessage;
    //const ServiceFlags = protocol.ServiceFlags;

    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
    defer list.deinit();

    //var message = AddrMessage{
    //    .ip_addresses = try test_allocator.alloc(NetworkIPAddr, 1),
    //};
    const ip_addresses = try test_allocator.alloc(NetworkIPAddr, 1);
    defer test_allocator.free(ip_addresses);

    ip_addresses[0] = NetworkIPAddr{
        .time = 1414012889,
        .services = 1,
        .ip = [16]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 192, 0, 2, 51 },
        .port = 8080,
    };

    var message = AddrMessage{
        .ip_addresses = ip_addresses,
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
    try sendMessage(test_allocator, writer, protocol.PROTOCOL_VERSION, protocol.BitcoinNetworkId.MAINNET, message);

    // Corrupt header payload length
    @memset(list.items[16..20], 42);

    var fbs: std.io.FixedBufferStream([]u8) = std.io.fixedBufferStream(list.items);
    const reader = fbs.reader();

    try std.testing.expectError(error.InvaliPayloadLen, receiveMessage(test_allocator, reader));
}

test "ko_receive_invalid_checksum" {
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
    try sendMessage(test_allocator, writer, protocol.PROTOCOL_VERSION, protocol.BitcoinNetworkId.MAINNET, message);

    // Corrupt header checksum
    @memset(list.items[20..24], 42);

    var fbs: std.io.FixedBufferStream([]u8) = std.io.fixedBufferStream(list.items);
    const reader = fbs.reader();

    try std.testing.expectError(error.InvalidChecksum, receiveMessage(test_allocator, reader));
}

test "ko_receive_invalid_command" {
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
    try sendMessage(test_allocator, writer, protocol.PROTOCOL_VERSION, protocol.BitcoinNetworkId.MAINNET, message);

    // Corrupt header command
    @memcpy(list.items[4..16], "whoissatoshi");

    var fbs: std.io.FixedBufferStream([]u8) = std.io.fixedBufferStream(list.items);
    const reader = fbs.reader();

    try std.testing.expectError(error.InvalidCommand, receiveMessage(test_allocator, reader));
}
