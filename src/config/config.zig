const std = @import("std");

/// Global configuration for the node
///
/// This is loaded from the `bitcoin.conf` file
/// Must be loaded before any other modules are used.
/// Must be compatible with Bitcoin Core's `bitcoin.conf` format.
pub const Config = struct {
    allocator: std.mem.Allocator,

    /// RPC port
    rpc_port: u16,

    /// P2P port
    p2p_port: u16,

    /// Testnet flag
    testnet: bool,

    /// Data directory
    datadir: []const u8,

    seednode: []const u8,

    /// Load the configuration from a file
    ///
    /// # Arguments
    /// - `allocator`: Memory allocator
    /// - `filename`: Path to the configuration file
    ///
    /// # Returns
    /// - `Config`: Configuration
    /// # Errors
    /// - Failed to read the file
    /// - Failed to parse the file
    pub fn load(allocator: std.mem.Allocator, filename: []const u8) !Config {
        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        var buf_reader = std.io.bufferedReader(file.reader());
        var in_stream = buf_reader.reader();

        var config = Config{
            .allocator = allocator,
            .rpc_port = 8332,
            .p2p_port = 8333,
            .testnet = false,
            .datadir = try allocator.dupe(u8, ".bitcoin"),
            .seednode = "",
        };

        var buf: [1024]u8 = undefined;
        while (try in_stream.readUntilDelimiterOrEof(&buf, '\n')) |line| {
            var it = std.mem.splitSequence(u8, line, "=");
            const key = it.next() orelse continue;
            const value = it.next() orelse continue;

            if (std.mem.eql(u8, key, "rpcport")) {
                config.rpc_port = try std.fmt.parseInt(u16, value, 10);
            } else if (std.mem.eql(u8, key, "port")) {
                config.p2p_port = try std.fmt.parseInt(u16, value, 10);
            } else if (std.mem.eql(u8, key, "testnet")) {
                config.testnet = std.mem.eql(u8, value, "1");
            } else if (std.mem.eql(u8, key, "datadir")) {
                allocator.free(config.datadir);
                config.datadir = try allocator.dupe(u8, value);
            }
        }

        return config;
    }

    pub fn deinit(self: *Config) void {
        self.allocator.free(self.datadir);
    }
};
