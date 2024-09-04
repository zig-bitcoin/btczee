const std = @import("std");
const net = std.net;
const protocol = @import("protocol.zig");

/// Represents a peer connection in the Bitcoin network
pub const Peer = struct {
    allocator: std.mem.Allocator,
    stream: net.Stream,
    address: net.Address,
    version: ?protocol.VersionMessage,
    last_seen: i64,
    is_outbound: bool,

    /// Initialize a new peer
    pub fn init(allocator: std.mem.Allocator, connection: net.Server.Connection) !*Peer {
        const peer = try allocator.create(Peer);
        peer.* = .{
            .allocator = allocator,
            .stream = connection.stream,
            .address = connection.address,
            .version = null,
            .last_seen = std.time.timestamp(),
            .is_outbound = false,
        };
        return peer;
    }

    /// Clean up peer resources
    pub fn deinit(self: *Peer) void {
        self.stream.close();
        self.allocator.destroy(self);
    }

    /// Start peer operations
    pub fn start(self: *Peer) !void {
        std.log.info("Starting peer connection with {}", .{self.address});

        try self.sendVersionMessage();
        try self.handleMessages();
    }

    /// Send version message to peer
    fn sendVersionMessage(self: *Peer) !void {
        const version_msg = protocol.VersionMessage{
            .version = 70015,
            .services = 1,
            .timestamp = @intCast(std.time.timestamp()),
            .addr_recv = protocol.NetworkAddress.init(self.address),
        };

        try self.sendMessage("version", version_msg);
    }

    /// Handle incoming messages from peer
    fn handleMessages(self: *Peer) !void {
        var buffer: [1024]u8 = undefined;

        while (true) {
            const bytes_read = try self.stream.read(&buffer);
            if (bytes_read == 0) break; // Connection closed

            // Mock message parsing
            const message_type = self.parseMessageType(buffer[0..bytes_read]);
            try self.handleMessage(message_type, buffer[0..bytes_read]);

            self.last_seen = std.time.timestamp();
        }
    }

    /// Mock function to parse message type
    fn parseMessageType(self: *Peer, data: []const u8) []const u8 {
        _ = self;
        if (std.mem.startsWith(u8, data, "version")) {
            return "version";
        } else if (std.mem.startsWith(u8, data, "verack")) {
            return "verack";
        } else {
            return "unknown";
        }
    }

    /// Handle a specific message type
    fn handleMessage(self: *Peer, message_type: []const u8, data: []const u8) !void {
        if (std.mem.eql(u8, message_type, "version")) {
            try self.handleVersionMessage(data);
        } else if (std.mem.eql(u8, message_type, "verack")) {
            try self.handleVerackMessage();
        } else {
            std.log.warn("Received unknown message type from peer", .{});
        }
    }

    /// Handle version message
    fn handleVersionMessage(self: *Peer, data: []const u8) !void {
        _ = data; // In a real implementation, parse the version message

        // Mock version message handling
        self.version = protocol.VersionMessage{
            .version = 70015,
            .services = 1,
            .timestamp = @intCast(std.time.timestamp()),
            .addr_recv = protocol.NetworkAddress.init(self.address),
            // ... other fields ...
        };

        try self.sendMessage("verack", {});
    }

    /// Handle verack message
    fn handleVerackMessage(self: *Peer) !void {
        std.log.info("Received verack from peer {}", .{self.address});
        // In a real implementation, mark the connection as established
    }

    /// Send a message to the peer
    fn sendMessage(self: *Peer, command: []const u8, message: anytype) !void {
        _ = message;
        // In a real implementation, serialize the message and send it
        try self.stream.writer().print("{s}\n", .{command});
    }
};
