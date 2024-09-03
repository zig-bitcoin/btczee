const std = @import("std");
const net = std.net;
const Config = @import("config.zig").Config;
const Peer = @import("peer.zig").Peer;

/// P2P network handler.
pub const P2P = struct {
    allocator: std.mem.Allocator,
    config: *const Config,
    peers: std.ArrayList(*Peer),
    listener: ?net.Server,

    /// Initialize the P2P network
    pub fn init(allocator: std.mem.Allocator, config: *const Config) !P2P {
        return P2P{
            .allocator = allocator,
            .config = config,
            .peers = std.ArrayList(*Peer).init(allocator),
            .listener = null,
        };
    }

    /// Deinitialize the P2P network
    pub fn deinit(self: *P2P) void {
        if (self.listener) |*l| l.deinit();
        for (self.peers.items) |peer| {
            peer.deinit();
        }
        self.peers.deinit();
    }

    /// Start the P2P network
    pub fn start(self: *P2P) !void {
        std.log.info("Starting P2P network on port {}", .{self.config.p2p_port});

        // Initialize the listener
        // const address = try net.Address.parseIp4("0.0.0.0", self.config.p2p_port);
        // const stream = try net.tcpConnectToAddress(address);

        // self.listener = net.Server{
        //     .listen_address = address,
        //     .stream = stream,
        // };

        // // Start accepting connections
        // try self.acceptConnections();

        // // Connect to seed nodes
        // try self.connectToSeedNodes();
    }

    /// Accept incoming connections
    fn acceptConnections(self: *P2P) !void {
        while (true) {
            const connection = self.listener.?.accept() catch |err| {
                std.log.err("Failed to accept connection: {}", .{err});
                continue;
            };

            // Handle the new connection in a separate thread
            // TODO: Error handling
            _ = try std.Thread.spawn(.{}, handleConnection, .{ self, connection });
        }
    }

    /// Handle a new connection
    fn handleConnection(self: *P2P, connection: net.Server.Connection) void {
        const peer = Peer.init(self.allocator, connection) catch |err| {
            std.log.err("Failed to initialize peer: {}", .{err});
            connection.stream.close();
            return;
        };

        self.peers.append(peer) catch |err| {
            std.log.err("Failed to add peer: {}", .{err});
            peer.deinit();
            return;
        };

        peer.start() catch |err| {
            std.log.err("Peer encountered an error: {}", .{err});
            _ = self.peers.swapRemove(self.peers.items.len - 1);
            peer.deinit();
        };
    }

    /// Connect to seed nodes
    fn connectToSeedNodes(self: *P2P) !void {
        if (self.config.seednode.len == 0) {
            return;
        }

        const address = try net.Address.parseIp4(self.config.seednode, 8333);
        const stream = try net.tcpConnectToAddress(address);

        const peer = try Peer.init(self.allocator, .{ .stream = stream, .address = address });
        try self.peers.append(peer);

        // Start the peer in a new thread
        // TODO: Error handling
        _ = try std.Thread.spawn(.{}, Peer.start, .{peer});
    }
};
