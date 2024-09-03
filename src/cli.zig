const std = @import("std");
const Config = @import("config.zig").Config;
const RPC = @import("rpc.zig").RPC;

/// CLI for the node
pub const CLI = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !CLI {
        return CLI{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *CLI) void {
        // Clean up resources if needed
        _ = self;
    }

    pub fn start(_: *CLI) !void {}
};
