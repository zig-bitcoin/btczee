//! P2P module handles the peer-to-peer networking of btczee.
//! It is responsible for the connection to other nodes in the network.
//! It can receive and send messages to other nodes, based on the Bitcoin protocol.
const std = @import("std");
const net = std.net;
const Config = @import("../config/config.zig").Config;
const Peer = @import("peer.zig").Peer;
const Boundness = @import("peer.zig").Boundness;

/// P2P network handler.
pub const P2P = struct {
    /// Allocator.
    allocator: std.mem.Allocator,
    /// Configuration.
    config: *const Config,
    /// List of peers.
    peers: std.ArrayList(*Peer),
    /// Thread pool for listening to peers
    peer_thread_pool: *std.Thread.Pool,
    /// Listener.
    listener: ?net.Server,

    /// Initialize the P2P network handler.
    pub fn init(allocator: std.mem.Allocator, config: *const Config) !P2P {
        const pool = try allocator.create(std.Thread.Pool);
        try std.Thread.Pool.init(pool, .{ .allocator = allocator });
        return P2P{
            .allocator = allocator,
            .config = config,
            .peers = std.ArrayList(*Peer).init(allocator),
            .listener = null,
            .peer_thread_pool = pool,
        };
    }

    /// Deinitialize the P2P network handler.
    pub fn deinit(self: *P2P) void {
        if (self.listener) |*l| l.deinit();
        self.peer_thread_pool.deinit();
        self.allocator.destroy(self.peer_thread_pool);
        for (self.peers.items) |peer| {
            peer.deinit();
        }
        self.peers.deinit();
    }

    /// Start the P2P network handler.
    pub fn start(self: *P2P) !void {
        std.log.info("Starting P2P network on port {}", .{self.config.p2p_port});

        var n_outboud_peer: u8 = 0;
        seeds: for (self.config.dnsSeeds()) |seed| {
            const address_list = try std.net.getAddressList(self.allocator, seed.inner, 8333);
            for (address_list.addrs) |address| {
                var peer = Peer.init(self.allocator, self.config, address, Boundness.outbound) catch continue;
                try self.peers.append(peer);
                peer.handshake() catch continue;
                try self.peer_thread_pool.spawn(Peer.listen, .{peer});

                n_outboud_peer += 1;
                // TODO: replace the hardcoded value with one from config
                if (n_outboud_peer == 8) {
                    break :seeds;
                }
            }
        }
        std.log.info("Connected to {d} nodes", .{n_outboud_peer});
    }
};
