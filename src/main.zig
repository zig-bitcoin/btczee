const std = @import("std");
const Config = @import("config/config.zig").Config;
const Mempool = @import("core/mempool.zig").Mempool;
const Storage = @import("storage/storage.zig").Storage;
const P2P = @import("network/p2p.zig").P2P;
const RPC = @import("network/rpc.zig").RPC;
const node = @import("node/node.zig");

pub fn main() !void {
    // Initialize the allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load configuration
    var config = try Config.load(allocator, "bitcoin.conf.example");
    defer config.deinit();

    // Initialize components
    var mempool = try Mempool.init(allocator, &config);
    defer mempool.deinit();

    var storage = try Storage.init(allocator, &config);
    defer storage.deinit();

    var p2p = try P2P.init(allocator, &config);
    defer p2p.deinit();

    var rpc = try RPC.init(allocator, &config, &mempool, &storage);
    defer rpc.deinit();

    // Start the node
    try node.startNode(&mempool, &storage, &p2p, &rpc);
}
