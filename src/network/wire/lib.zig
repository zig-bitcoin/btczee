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

pub const ReceiveMessageError = error{ UnknownMessage, InvaliPayloadLen, InvalidChecksum, InvalidHandshake };

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
    var message: protocol.messages.Message = if (std.mem.eql(u8, &command, protocol.messages.VersionMessage.name()))
        protocol.messages.Message{ .Version = try protocol.messages.VersionMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.VerackMessage.name()))
        protocol.messages.Message{ .Verack = try protocol.messages.VerackMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.MempoolMessage.name()))
        protocol.messages.Message{ .Mempool = try protocol.messages.MempoolMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.GetaddrMessage.name()))
        protocol.messages.Message{ .Getaddr = try protocol.messages.GetaddrMessage.deserializeReader(allocator, r) }
    else if (std.mem.eql(u8, &command, protocol.messages.BlockMessage.name()))
        protocol.messages.Message{ .Block = try protocol.messages.BlockMessage.deserializeReader(allocator, r) }
    else
        return error.UnknownMessage;
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

    const writer = list.writer();
    try sendMessage(test_allocator, writer, Config.PROTOCOL_VERSION, Config.BitcoinNetworkId.MAINNET, message);
    var fbs: std.io.FixedBufferStream([]u8) = std.io.fixedBufferStream(list.items);
    const reader = fbs.reader();

    const received_message = try receiveMessage(test_allocator, reader);
    defer received_message.deinit(test_allocator);

    switch (received_message) {
        .Version => |rm| try std.testing.expect(message.eql(&rm)),
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

    const writer = list.writer();
    try sendMessage(test_allocator, writer, Config.PROTOCOL_VERSION, Config.BitcoinNetworkId.MAINNET, message);
    var fbs: std.io.FixedBufferStream([]u8) = std.io.fixedBufferStream(list.items);
    const reader = fbs.reader();

    const received_message = try receiveMessage(test_allocator, reader);
    defer received_message.deinit(test_allocator);

    try std.testing.expect(received_message == .Verack);
}

test "ok_send_mempool_message" {
    const Config = @import("../../config/config.zig").Config;
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;
    const MempoolMessage = protocol.messages.MempoolMessage;

    var list: std.ArrayListAligned(u8, null) = ArrayList(u8).init(test_allocator);
    defer list.deinit();

    const message = MempoolMessage{};

    const writer = list.writer();
    try sendMessage(test_allocator, writer, Config.PROTOCOL_VERSION, Config.BitcoinNetworkId.MAINNET, message);
    var fbs: std.io.FixedBufferStream([]u8) = std.io.fixedBufferStream(list.items);
    const reader = fbs.reader();

    const received_message = try receiveMessage(test_allocator, reader);
    defer received_message.deinit(test_allocator);

    try std.testing.expect(received_message == .Mempool);
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
    try sendMessage(test_allocator, writer, Config.PROTOCOL_VERSION, Config.BitcoinNetworkId.MAINNET, message);

    // Corrupt header payload length
    @memset(list.items[16..20], 42);

    var fbs: std.io.FixedBufferStream([]u8) = std.io.fixedBufferStream(list.items);
    const reader = fbs.reader();

    try std.testing.expectError(error.InvaliPayloadLen, receiveMessage(test_allocator, reader));
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
    try sendMessage(test_allocator, writer, Config.PROTOCOL_VERSION, Config.BitcoinNetworkId.MAINNET, message);

    // Corrupt header checksum
    @memset(list.items[20..24], 42);

    var fbs: std.io.FixedBufferStream([]u8) = std.io.fixedBufferStream(list.items);
    const reader = fbs.reader();

    try std.testing.expectError(error.InvalidChecksum, receiveMessage(test_allocator, reader));
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
    try sendMessage(test_allocator, writer, Config.PROTOCOL_VERSION, Config.BitcoinNetworkId.MAINNET, message);

    // Corrupt header command
    @memcpy(list.items[4..16], "whoissatoshi");

    var fbs: std.io.FixedBufferStream([]u8) = std.io.fixedBufferStream(list.items);
    const reader = fbs.reader();

    try std.testing.expectError(error.UnknownMessage, receiveMessage(test_allocator, reader));
}
