const std = @import("std");
const Config = @import("config.zig").Config;

/// Storage handler.
///
/// The storage is responsible for handling the blockchain data.
pub const Storage = struct {
    allocator: std.mem.Allocator,
    config: *const Config,

    /// Initialize the storage
    ///
    /// # Arguments
    /// - `allocator`: Memory allocator
    /// - `config`: Configuration
    ///
    /// # Returns
    /// - `Storage`: Storage
    pub fn init(allocator: std.mem.Allocator, config: *const Config) !Storage {
        return Storage{
            .allocator = allocator,
            .config = config,
        };
    }

    /// Deinitialize the storage
    ///
    /// # Arguments
    /// - `self`: Storage
    pub fn deinit(self: *Storage) void {
        // Clean up resources if needed
        _ = self;
    }
};
