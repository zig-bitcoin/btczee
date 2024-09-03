const std = @import("std");
const Config = @import("config.zig").Config;

pub const Storage = struct {
    allocator: std.mem.Allocator,
    config: *const Config,

    pub fn init(allocator: std.mem.Allocator, config: *const Config) !Storage {
        return Storage{
            .allocator = allocator,
            .config = config,
        };
    }

    pub fn deinit(self: *Storage) void {
        // Clean up resources if needed
        _ = self;
    }
};
