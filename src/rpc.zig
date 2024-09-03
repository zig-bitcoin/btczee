const std = @import("std");
const Config = @import("config.zig").Config;
const Mempool = @import("mempool.zig").Mempool;
const Storage = @import("storage.zig").Storage;
const P2P = @import("p2p.zig").P2P;

/// RPC Server handler.
///
/// The RPC server is responsible for handling the RPC requests from the clients.
///
/// See https://developer.bitcoin.org/reference/rpc/
pub const RPC = struct {
    allocator: std.mem.Allocator,
    config: *const Config,
    mempool: *Mempool,
    storage: *Storage,

    pub fn init(
        allocator: std.mem.Allocator,
        config: *const Config,
        mempool: *Mempool,
        storage: *Storage,
    ) !RPC {
        return RPC{
            .allocator = allocator,
            .config = config,
            .mempool = mempool,
            .storage = storage,
        };
    }

    pub fn deinit(self: *RPC) void {
        // Clean up resources if needed
        _ = self;
    }

    pub fn start(self: *RPC) !void {
        std.log.info("Starting RPC server on port {}", .{self.config.rpc_port});
        // Implement RPC server initialization
    }
};
