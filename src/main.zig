const std = @import("std");
const Config = @import("config.zig").Config;
const Mempool = @import("mempool.zig").Mempool;
const Storage = @import("storage.zig").Storage;
const P2P = @import("p2p.zig").P2P;
const RPC = @import("rpc.zig").RPC;
const CLI = @import("cli.zig").CLI;

pub fn main() !void {
    // Initialize the allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Load configuration
    var config = try Config.load(allocator, "bitcoin.conf.example");
    defer config.deinit();

    var cli = try CLI.init(allocator);
    defer cli.deinit();

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
    try startNode(&mempool, &storage, &p2p, &rpc, &cli);
}

fn startNode(_: *Mempool, _: *Storage, p2p: *P2P, rpc: *RPC, _: *CLI) !void {
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
