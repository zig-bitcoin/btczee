const std = @import("std");
const net = std.net;
const protocol = @import("./protocol/lib.zig");
const wire = @import("./wire/lib.zig");
const Config = @import("../config/config.zig").Config;

const PeerError = error{
    WeOnlySupportIPV6ForNow,
};

/// Represents a peer connection in the Bitcoin network
pub const Peer = struct {
    allocator: std.mem.Allocator,
    config: *const Config,
    stream: net.Stream,
    address: net.Address,
    protocol_version: ?i32 = null,
    services: ?u64 = null,
    last_seen: i64,

    /// Initialize a new peer
    pub fn init(allocator: std.mem.Allocator, config: *const Config, address: std.net.Address) !*Peer {
        if (address.any.family != std.posix.AF.INET6) {
            return error.WeOnlySupportIPV6ForNow;
        }

        const stream = try std.net.tcpConnectToAddress(address);
        const peer = try allocator.create(Peer);

        peer.* = .{
            .allocator = allocator,
            .config = config,
            .stream = stream,
            .address = address,
            .last_seen = std.time.timestamp(),
        };
        return peer;
    }

    /// Clean up peer resources
    pub fn deinit(self: *Peer) void {
        self.stream.close();
        self.allocator.destroy(self);
    }

    /// Start peer operations
    pub fn start(self: *Peer, is_outbound: bool) !void {
        std.log.info("Starting peer connection with {}", .{self.address});
        if (is_outbound) {
            try self.negociateProtocolOutboundConnection();
        } else {
            // Not implemented yet
            unreachable;
        }
    }

    fn negociateProtocolOutboundConnection(self: *Peer) !void {
        try self.sendVersionMessage();

        while (true) {
            const received_message = wire.receiveMessage(self.allocator, self.stream.reader()) catch |e| {
                switch (e) {
                    error.EndOfStream, error.UnknownMessage => continue,
                    else => return e,
                }
            };

            switch (received_message) {
                .Version => {
                    self.protocol_version = @min(self.config.protocol_version, received_message.Version.version);
                    self.services = received_message.Version.trans_services;
                },

                .Verack => return,
                else => return error.InvalidHandshake,
            }
        }
    }

    /// Send version message to peer
    fn sendVersionMessage(self: *Peer) !void {
        const message = protocol.messages.VersionMessage.new(
            self.config.protocol_version,
            .{ .ip = std.mem.zeroes([16]u8), .port = 0, .services = self.config.services },
            .{ .ip = self.address.in6.sa.addr, .port = self.address.in6.getPort(), .services = 0 },
            std.crypto.random.int(u64),
            self.config.bestBlock(),
        );

        try wire.sendMessage(
            self.allocator,
            self.stream.writer(),
            self.config.protocol_version,
            self.config.network_id,
            message,
        );
    }
};
