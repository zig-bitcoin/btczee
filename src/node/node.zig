//! Contains functionalities to run a Bitcoin full node on the Bitcoin network.
//! It enables the validation of transactions and blocks, the exchange of transactions and blocks with other peers.
const std = @import("std");
const Config = @import("../config/config.zig").Config;
const Mempool = @import("../core/mempool.zig").Mempool;
const Storage = @import("../storage/storage.zig").Storage;
const P2P = @import("../network/p2p.zig").P2P;
const RPC = @import("../network/rpc.zig").RPC;
const Logger = @import("../util/trace/log.zig").Logger;

/// Node is a struct that contains all the components of a Bitcoin full node.
pub const Node = struct {
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
    logger: Logger,

    /// Initialize the node.
    ///
    /// # Arguments
    /// - `mempool`: Transaction pool.
    /// - `storage`: Blockchain storage.
    /// - `p2p`: P2P network handler.
    /// - `rpc`: RPC server.
    pub fn init(logger: Logger, mempool: *Mempool, storage: *Storage, p2p: *P2P, rpc: *RPC) !Node {
        return Node{
            .logger = logger,
            .mempool = mempool,
            .storage = storage,
            .p2p = p2p,
            .rpc = rpc,
            .stopped = false,
            .started = std.Thread.Condition{},
            .mutex = std.Thread.Mutex{},
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
        self.logger.info("Starting btczee node...");
        self.mutex.lock();
        defer self.mutex.unlock();

        // Start P2P network
        try self.p2p.start();

        // Start RPC server
        try self.rpc.start();

        self.started.signal();

        // Main event loop
        while (!self.stopped) {
            self.mutex.unlock();
            self.logger.debug("Waiting for blocks...");
            std.time.sleep(std.time.ns_per_s);
            self.mutex.lock();
        }
        self.logger.info("Node stopped");
    }

    /// Stop the node.
    pub fn stop(self: *Node) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.logger.info("Stopping node...");
        self.stopped = true;
        self.logger.info("Node stop signal sent");
    }

    /// Wait for the node to start.
    pub fn waitForStart(self: *Node) void {
        self.mutex.lock();
        defer self.mutex.unlock();

        self.started.wait(&self.mutex);
    }
};
