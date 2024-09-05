//! Contains functionalities to run a Bitcoin full node on the Bitcoin network.
//! It enables the validation of transactions and blocks, the exchange of transactions and blocks with other peers.
const std = @import("std");
const Config = @import("../config/config.zig").Config;
const Mempool = @import("../core/mempool.zig").Mempool;
const Storage = @import("../storage/storage.zig").Storage;
const P2P = @import("../network/p2p.zig").P2P;
const RPC = @import("../network/rpc.zig").RPC;

/// Start the node.
///
/// # Arguments
/// - `mempool`: Transaction pool.
/// - `storage`: Blockchain storage.
/// - `p2p`: P2P network handler.
/// - `rpc`: RPC server.
pub fn startNode(_: *Mempool, _: *Storage, p2p: *P2P, rpc: *RPC) !void {
    std.log.info("Starting btczee node...", .{});

    // Start P2P network
    try p2p.start();

    // Start RPC server
    try rpc.start();

    // Main event loop
    while (true) {
        // Handle events, process blocks, etc.
        std.log.debug("Waiting for blocks...", .{});
        std.time.sleep(std.time.ns_per_s);
    }
}