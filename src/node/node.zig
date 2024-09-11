//! Contains functionalities to run a Bitcoin full node on the Bitcoin network.
//! It enables the validation of transactions and blocks, the exchange of transactions and blocks with other peers.
const std = @import("std");
const Config = @import("../config/config.zig").Config;
const Mempool = @import("../core/mempool.zig").Mempool;
const Storage = @import("../storage/storage.zig").Storage;
const P2P = @import("../network/p2p.zig").P2P;
const RPC = @import("../network/rpc.zig").RPC;
const Logger = @import("../util/trace/log.zig").Logger;
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
    /// Logger.
    logger: Logger,
    /// IBD handler.
    ibd: IBD,

    /// Initialize the node.
    ///
    /// # Arguments
    /// - `mempool`: Transaction pool.
    /// - `storage`: Blockchain storage.
    /// - `p2p`: P2P network handler.
    /// - `rpc`: RPC server.
    pub fn init(allocator: std.mem.Allocator, logger: Logger, mempool: *Mempool, storage: *Storage, p2p: *P2P, rpc: *RPC) !Node {
        return Node{
            .allocator = allocator,
            .logger = logger,
            .mempool = mempool,
            .storage = storage,
            .p2p = p2p,
            .rpc = rpc,
            .stopped = false,
            .started = std.Thread.Condition{},
            .mutex = std.Thread.Mutex{},
            .ibd = IBD.init(p2p, logger),
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

        // Start Initial Block Download
        try self.ibd.start();

        self.started.signal();

        // Main event loop
        while (!self.stopped) {
            self.mutex.unlock();
            self.logger.debug("Processing new blocks and transactions...");
            try self.processNewBlocksAndTransactions();
            std.time.sleep(5 * std.time.ns_per_s);
            self.mutex.lock();
        }
        self.logger.info("Node stopped");
    }

    fn processNewBlocksAndTransactions(self: *Node) !void {
        // Simulate processing of new blocks and transactions
        const new_block = try self.simulateNewBlock();
        try self.validateBlock(new_block);
        try self.addBlockToChain(new_block);

        var new_tx = try self.simulateNewTransaction();
        defer {
            new_tx.deinit();
            self.allocator.destroy(new_tx);
        }
        try self.validateTransaction(new_tx);
        try self.addTransactionToMempool(new_tx);
    }

    fn simulateNewBlock(self: *Node) !Block {
        _ = self;
        return Block{ .height = 0, .hash = [_]u8{0} ** 32 };
    }

    fn validateBlock(self: *Node, _: Block) !void {
        self.logger.debug("Validating block...");
        // Implement block validation logic here
    }

    fn addBlockToChain(self: *Node, _: Block) !void {
        self.logger.debug("Adding block to chain.");
        // Implement logic to add block to the chain
    }

    fn simulateNewTransaction(self: *Node) !*Transaction {
        var tx = try self.allocator.create(Transaction);
        errdefer self.allocator.destroy(tx);

        tx.* = try Transaction.init(self.allocator);
        errdefer tx.deinit();

        return tx;
    }

    fn validateTransaction(self: *Node, tx: *Transaction) !void {
        self.logger.debug("Validating transaction");
        // Implement transaction validation logic here
        _ = tx;
    }

    fn addTransactionToMempool(self: *Node, tx: *Transaction) !void {
        self.logger.debug("Adding transaction to mempool");
        _ = try self.mempool.addTransaction(tx, 42, 1000);
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
