const std = @import("std");
const Config = @import("config.zig").Config;
const RPC = @import("rpc.zig").RPC;

pub const CLI = struct {
    allocator: std.mem.Allocator,
    config: *const Config,
    rpc: *RPC,

    pub fn init(allocator: std.mem.Allocator, config: *const Config, rpc: *RPC) !CLI {
        return CLI{
            .allocator = allocator,
            .config = config,
            .rpc = rpc,
        };
    }

    pub fn deinit(self: *CLI) void {
        // Clean up resources if needed
        _ = self;
    }

    pub fn start(_: *CLI) !void {}
};
