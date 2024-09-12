const std = @import("std");
const net = std.net;
const Sha256 = std.crypto.hash.sha2.Sha256;

const protocol = @import("lib.zig");
const NetworkMagicBytes = protocol.NetworkMagicBytes;

pub const Message = struct {
    header: Header,
    payload: []u8,
};

/// Header structure for all messages
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#message-headers
pub const Header = struct {
    start_string: NetworkMagicBytes,
    command_name: [12]u8,
    payload_size: u32,
    checksum: u32,

    pub fn new(network: NetworkMagicBytes, command_name: [12]u8, payload: []const u8) Header {
        const header = .{
            .start_string = network,
            .command_name = command_name,
            .payload_size = 0,
            .checksum = 0x5df6e0e2,
        };

        if (payload.len == 0) {
            return header;
        }

        const digest = [Sha256.digest_length]u8;
        Sha256.hash(payload, &digest, .{});
        Sha256.hash(&digest, std.mem.asBytes(&header.checksum), .{});

        header.payload_size = payload.len;

        return header;
    }
};
