const std = @import("std");
const Config = @import("../config/config.zig").Config;
const Block = @import("../types/block.zig").Block;
const lmdb = @import("lmdb");

/// Storage handler.
///
/// The storage is responsible for handling the blockchain data.
pub const Storage = struct {
    config: *const Config,
    env: lmdb.Environment,

    /// Initialize the storage
    ///
    /// Will create the full path to the directory if it doesn't already exist.
    pub fn init(config: *const Config) !Storage {
        const datadir = config.datadir;
        try std.fs.cwd().makePath(datadir);

        // Init the db env
        // `max_dbs` is set to 1:
        // - "blocks"
        const env = try lmdb.Environment.init(datadir, .{ .max_dbs = 1 });

        return Storage{
            .config = config,
            .env = env,
        };
    }

    /// Deinitialize the storage
    ///
    /// Release the lmdb environment handle.
    pub fn deinit(self: Storage) void {
        self.env.deinit();
    }

    /// Return a Transaction handle
    pub fn init_transaction(self: Storage) !Transaction {
        const txn = try lmdb.Transaction.init(self.env, .{ .mode = .ReadWrite });
        return Transaction{ .txn = txn };
    }
};

/// A Storage transaction
pub const Transaction = struct {
    txn: lmdb.Transaction,

    /// Abandon the Transaction without applying any change
    pub fn abort(self: Transaction) void {
        self.txn.abort();
    }

    /// Serialize and store a block in database
    pub fn store_block(allocator: std.mem.Allocator, txn: Transaction, block: *Block) !void {
        const blocks = try txn.txn.database("blocks", .{ .create = true });
        try blocks.set(&block.hash, try block.serizalize(allocator));
    }
};
