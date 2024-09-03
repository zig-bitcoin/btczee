const std = @import("std");
const Config = @import("config.zig").Config;
const tx = @import("transaction.zig");

const Transaction = struct {};

/// Transaction descriptor containing a transaction in the mempool along with additional metadata.
const TxDesc = struct {
    tx: *tx.Transaction,
    added_time: i64,
    height: i32,
    fee: i64,
    fee_per_kb: i64,
    starting_priority: f64,
};

/// Mempool for validating and storing standalone transactions until they are mined into a block.
pub const Mempool = struct {
    allocator: std.mem.Allocator,
    config: *const Config,
    pool: std.AutoHashMap(tx.Hash, *TxDesc),
    orphans: std.AutoHashMap(tx.Hash, *tx.Transaction),
    orphans_by_prev: std.AutoHashMap(tx.OutPoint, std.AutoHashMap(tx.Hash, *tx.Transaction)),
    outpoints: std.AutoHashMap(tx.OutPoint, *tx.Transaction),
    last_updated: i64,

    /// Initialize the mempool
    ///
    /// # Arguments
    /// - `allocator`: Memory allocator
    /// - `config`: Configuration
    ///
    /// # Returns
    /// - `Mempool`: Initialized mempool
    pub fn init(allocator: std.mem.Allocator, config: *const Config) !Mempool {
        return Mempool{
            .allocator = allocator,
            .config = config,
            .pool = std.AutoHashMap(tx.Hash, *TxDesc).init(allocator),
            .orphans = std.AutoHashMap(tx.Hash, *tx.Transaction).init(allocator),
            .orphans_by_prev = std.AutoHashMap(tx.OutPoint, std.AutoHashMap(tx.Hash, *tx.Transaction)).init(allocator),
            .outpoints = std.AutoHashMap(tx.OutPoint, *tx.Transaction).init(allocator),
            .last_updated = 0,
        };
    }

    /// Deinitialize the mempool
    pub fn deinit(self: *Mempool) void {
        self.pool.deinit();
        self.orphans.deinit();
        self.orphans_by_prev.deinit();
        self.outpoints.deinit();
    }

    /// Add a transaction to the mempool
    ///
    /// # Arguments
    /// - `transaction`: Transaction to add
    /// - `height`: Current blockchain height
    /// - `fee`: Transaction fee
    ///
    /// # Returns
    /// - `?*TxDesc`: Added transaction descriptor or null if not added
    pub fn addTransaction(self: *Mempool, transaction: *tx.Transaction, height: i32, fee: i64) !?*TxDesc {
        const hash = transaction.hash();

        // Check if the transaction is already in the pool
        if (self.pool.contains(hash)) {
            return null;
        }

        // Create a new transaction descriptor
        const tx_desc = try self.allocator.create(TxDesc);
        tx_desc.* = TxDesc{
            .tx = transaction,
            .added_time = std.time.milliTimestamp(),
            .height = height,
            .fee = fee,
            .fee_per_kb = @divTrunc(fee * 1000, @as(i64, @intCast(transaction.virtual_size()))),
            .starting_priority = try self.calculatePriority(transaction, height),
        };

        // Add the transaction to the pool
        try self.pool.put(hash, tx_desc);

        // Add the transaction outpoints to the outpoints map
        for (transaction.inputs.items) |input| {
            try self.outpoints.put(input.previous_outpoint, transaction);
        }

        // Update the last updated timestamp
        self.last_updated = std.time.milliTimestamp();

        return tx_desc;
    }

    /// Remove a transaction from the mempool
    ///
    /// # Arguments
    /// - `hash`: Hash of the transaction to remove
    /// - `remove_redeemers`: Whether to remove transactions that redeem outputs of this transaction
    pub fn removeTransaction(self: *Mempool, hash: tx.Hash, remove_redeemers: bool) void {
        const tx_desc = self.pool.get(hash) orelse return;

        if (remove_redeemers) {
            // Remove any transactions which rely on this one
            for (tx_desc.tx.outputs.items, 0..) |_, i| {
                const outpoint = tx.OutPoint{ .hash = hash, .index = @as(u32, @intCast(i)) };
                if (self.outpoints.get(outpoint)) |redeemer| {
                    self.removeTransaction(redeemer.hash(), true);
                }
            }
        }

        // Remove the transaction from the pool
        _ = self.pool.remove(hash);

        // Remove the outpoints from the outpoints map
        for (tx_desc.tx.inputs.items) |input| {
            _ = self.outpoints.remove(input.previous_outpoint);
        }

        // Update the last updated timestamp
        self.last_updated = std.time.milliTimestamp();

        // Free the transaction descriptor
        self.allocator.destroy(tx_desc);
    }

    /// Calculate the priority of a transaction
    ///
    /// # Arguments
    /// - `transaction`: Transaction to calculate priority for
    /// - `height`: Current blockchain height
    ///
    /// # Returns
    /// - `f64`: Calculated priority
    fn calculatePriority(self: *Mempool, transaction: *tx.Transaction, height: i32) !f64 {
        _ = self;
        var priority: f64 = 0;
        for (transaction.inputs.items) |input| {
            // TODO: Fetch the UTXO from the chain
            _ = input;
            const utxo = .{ .value = 1000, .height = 100 };
            const input_value = utxo.value;
            const input_age = @as(f64, @floatFromInt(height - utxo.height));
            priority += @as(f64, @floatFromInt(input_value)) * input_age;
        }

        priority /= @as(f64, @floatFromInt(transaction.virtual_size()));

        return priority;
    }

    /// Check if a transaction is in the mempool
    ///
    /// # Arguments
    /// - `hash`: Hash of the transaction to check
    ///
    /// # Returns
    /// - `bool`: True if the transaction is in the mempool, false otherwise
    pub fn containsTransaction(self: *const Mempool, hash: tx.Hash) bool {
        return self.pool.contains(hash);
    }

    /// Get the number of transactions in the mempool
    ///
    /// # Returns
    /// - `usize`: Number of transactions in the mempool
    pub fn count(self: *const Mempool) usize {
        return self.pool.count();
    }

    /// Get the last time the mempool was updated
    ///
    /// # Returns
    /// - `i64`: Last update time in milliseconds
    pub fn lastUpdated(self: *const Mempool) i64 {
        return self.last_updated;
    }
};

test "Mempool" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var config = Config{
        .allocator = allocator,
        .rpc_port = 8332,
        .p2p_port = 8333,
        .testnet = false,
        .datadir = "/tmp/btczee",
    };
    var mempool = try Mempool.init(allocator, &config);
    defer mempool.deinit();

    // Create a mock transaction
    var transaction = try tx.Transaction.init(allocator);
    defer transaction.deinit();
    try transaction.addInput(tx.OutPoint{ .hash = tx.Hash.zero(), .index = 0 });
    try transaction.addOutput(50000, try tx.Script.init(allocator));

    // Add the transaction to the mempool
    const tx_desc = try mempool.addTransaction(&transaction, 101, 1000);
    try testing.expect(tx_desc != null);

    // Check if the transaction is in the mempool
    try testing.expect(mempool.containsTransaction(transaction.hash()));

    // Check the mempool count
    try testing.expectEqual(@as(usize, 1), mempool.count());

    // Remove the transaction from the mempool
    mempool.removeTransaction(transaction.hash(), false);

    // Check if the transaction is no longer in the mempool
    try testing.expect(!mempool.containsTransaction(transaction.hash()));

    // Check the mempool count after removal
    try testing.expectEqual(@as(usize, 0), mempool.count());
}
