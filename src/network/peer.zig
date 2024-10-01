const std = @import("std");
const net = std.net;
const protocol = @import("./protocol/lib.zig");
const wire = @import("./wire/lib.zig");
const Config = @import("../config/config.zig").Config;

pub const Boundness = enum {
    inbound,
    outbound,

    pub fn isOutbound(self: Boundness) bool {
        return self == Boundness.outbound;
    }
    pub fn isInbound(self: Boundness) bool {
        return self == Boundness.inbound;
    }
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
    boundness: Boundness,
    should_listen: bool = false,

    /// Initialize a new peer
    pub fn init(allocator: std.mem.Allocator, config: *const Config, address: std.net.Address, boundness: Boundness) !*Peer {
        const stream = try std.net.tcpConnectToAddress(address);
        const peer = try allocator.create(Peer);

        peer.* = .{
            .allocator = allocator,
            .config = config,
            .stream = stream,
            .address = address,
            .last_seen = std.time.timestamp(),
            .boundness = boundness,
        };
        return peer;
    }

    /// Clean up peer resources
    pub fn deinit(self: *Peer) void {
        self.stream.close();
        self.allocator.destroy(self);
    }

    /// Start peer operations
    pub fn handshake(self: *Peer) !void {
        std.log.info("Starting peer connection with {}", .{self.address});
        if (self.boundness.isOutbound()) {
            try self.negociateProtocolOutboundConnection();
        } else {
            // Not implemented yet
            unreachable;
        }

        self.should_listen = true;
        std.log.info("Connected to {}", .{self.address});
    }

    fn negociateProtocolOutboundConnection(self: *Peer) !void {
        try self.sendVersionMessage();

        while (true) {
            const received_message = wire.receiveMessage(self.allocator, self.stream.reader(), self.config.network_id) catch |e| {
                switch (e) {
                    // The node can be on another version of the protocol, using messages we are not aware of
                    error.UnknownMessage => continue,
                    else => return e,
                }
            } orelse continue;

            switch (received_message) {
                .version => |vm| {
                    self.protocol_version = @min(self.config.protocol_version, vm.version);
                    self.services = vm.trans_services;
                },

                .verack => return,
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

    pub fn listen(self: *Peer) void {
        std.log.info("Listening for messages from {any}", .{self.address});
        while (self.should_listen) {
            const message = wire.receiveMessage(self.allocator, self.stream.reader(), self.config.network_id) catch |e| switch (e) {
                // The node can be on another version of the protocol, using messages we are not aware of
                error.UnknownMessage => continue,
                else => {
                    self.should_listen = false;
                    continue;
                },
            } orelse continue;

            switch (message) {
                // We only received those during handshake, seeing them again is an error
                .version, .verack => self.should_listen = false,
                .feefilter => |feefilter_message| {
                    std.log.info("Received feefilter message with feerate: {}", .{feefilter_message.feerate});
                    // TODO: Implement logic to filter transactions based on the received feerate
                },
                // TODO: handle other messages correctly
                else => |*m| {
                    std.log.info("Peer {any} sent a `{s}` message", .{ self.address, m.name() });
                    continue;
                },
            }
        }
    }
};
