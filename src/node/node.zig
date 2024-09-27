//! Contains functionalities to run a Bitcoin full node on the Bitcoin network.
//! It enables the validation of transactions and blocks, the exchange of transactions and blocks with other peers.
const std = @import("std");
const Config = @import("../config/config.zig").Config;
const Mempool = @import("../core/mempool.zig").Mempool;
const Storage = @import("../storage/storage.zig").Storage;
const P2P = @import("../network/p2p.zig").P2P;
const RPC = @import("../network/rpc.zig").RPC;
const IBD = @import("ibd.zig").IBD;
const Block = @import("../types/block.zig").Block;
const Transaction = @import("../types/transaction.zig").Transaction;

/// Node is a struct that contains all the components of a Bitcoin full node.
pub const Node = struct {
    /// Allocator.
    allocator: std.mem.Allocator,
    /// Transaction pool.
    mempool: *Mempool,
    /// Blockchain storage.
    storage: *Storage,
    /// P2P network handler.
    p2p: *P2P,
    rpc: *RPC,
    /// Whether the node is stopped.
    stopped: bool,
    /// Condition variable to wait for the node to start.
    started: std.Thread.Condition,
    /// Mutex to synchronize access to the node.
    mutex: std.Thread.Mutex,
    /// IBD handler.
    ibd: IBD,

    /// Initialize the node.
    ///
    /// # Arguments
    /// - `mempool`: Transaction pool.
    /// - `storage`: Blockchain storage.
    /// - `p2p`: P2P network handler.
    /// - `rpc`: RPC server.
    pub fn init(allocator: std.mem.Allocator, mempool: *Mempool, storage: *Storage, p2p: *P2P, rpc: *RPC) !Node {
        return Node{
            .allocator = allocator,
            .mempool = mempool,
            .storage = storage,
            .p2p = p2p,
            .rpc = rpc,
            .stopped = false,
            .started = std.Thread.Condition{},
            .mutex = std.Thread.Mutex{},
            .ibd = IBD.init(p2p),
        };
    }

    /// Deinitialize the node.
    /// Cleans up the resources used by the node.
    pub fn deinit(self: *Node) void {
        _ = self;
    }

    /// Start the node.
    ///
    /// # Arguments
    /// - `mempool`: Transaction pool.
    /// - `storage`: Blockchain storage.
    /// - `p2p`: P2P network handler.
    /// - `rpc`: RPC server.
    pub fn start(self: *Node) !void {
        std.log.info("Starting btczee node...", .{});
        self.mutex.lock();
        defer self.mutex.unlock();

        // Start P2P network
        try self.p2p.start();

        // Start RPC server
        try self.rpc.start();

        // Start Initial Block Download
        try self.ibd.start();

        self.started.signal();

        // Main event loop
        while (!self.stopped) {
            std.time.sleep(5 * std.time.ns_per_s);
        }
        std.log.info("Node stopped", .{});
    }
};
