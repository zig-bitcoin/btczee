//! P2P module handles the peer-to-peer networking of btczee.
//! It is responsible for the connection to other nodes in the network.
//! It can receive and send messages to other nodes, based on the Bitcoin protocol.
const std = @import("std");
const net = std.net;
const posix = std.posix;
const Config = @import("../config/config.zig").Config;
const Peer = @import("peer.zig").Peer;
const wire = @import("wire/lib.zig");
const protocol = @import("protocol/lib.zig");
const VersionMessage = protocol.messages.VersionMessage;
const NetworkAddress = protocol.NetworkAddress;

/// P2P network handler.
pub const P2P = struct {
    /// Allocator.
    allocator: std.mem.Allocator,
    /// Configuration.
    config: *const Config,
    /// List of peers.
    peers: std.ArrayList(*Peer),
    /// Listener.
    listener: ?net.Server,

    /// Initialize the P2P network handler.
    /// # Arguments
    /// - `allocator`: Allocator.
    /// - `config`: Configuration.
    /// # Returns
    /// - `P2P`: P2P network handler.
    pub fn init(allocator: std.mem.Allocator, config: *const Config) !P2P {
        return P2P{
            .allocator = allocator,
            .config = config,
            .peers = std.ArrayList(*Peer).init(allocator),
            .listener = null,
        };
    }

    /// Deinitialize the P2P network handler.
    pub fn deinit(self: *P2P) void {
        if (self.listener) |*l| l.deinit();
        for (self.peers.items) |peer| {
            peer.deinit();
        }
        self.peers.deinit();
    }

    /// Start the P2P network handler.
    pub fn start(self: *P2P) !void {
        std.log.info("Starting P2P network on port {}", .{self.config.p2p_port});

        for (self.config.dnsSeeds()) |seed| {
            const address_list = try std.net.getAddressList(self.allocator, seed.inner, 8333);
            for (address_list.addrs[0..5]) |address| {
                const peer = Peer.init(self.allocator, self.config, address) catch continue;
                try self.peers.append(peer);
                peer.start(true) catch continue;
            }
        }
    }
    /// Accept incoming connections.
    /// The P2P network handler will accept incoming connections and handle them in a separate thread.
    fn acceptConnections(self: *P2P) !void {
        while (true) {
            const connection = self.listener.?.accept() catch |err| {
                self.logger.errf("Failed to accept connection: {}", .{err});
                continue;
            };

            // Handle the new connection in a separate thread
            // TODO: Error handling
            _ = try std.Thread.spawn(.{}, handleConnection, .{ self, connection });
            
        }
    }
};
