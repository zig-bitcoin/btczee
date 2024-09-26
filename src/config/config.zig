const std = @import("std");

const DnsSeed = struct { inner: [:0]const u8 };

/// Global configuration for the node
///
/// This is loaded from the `bitcoin.conf` file
/// Must be loaded before any other modules are used.
/// Must be compatible with Bitcoin Core's `bitcoin.conf` format.
pub const Config = struct {
    const Self = @This();
    /// Protocol version
    pub const PROTOCOL_VERSION: i32 = 70015;

    /// Known network ids
    pub const BitcoinNetworkId = struct {
        pub const MAINNET: [4]u8 = .{ 0xf9, 0xbe, 0xb4, 0xd9 };
        pub const REGTEST: [4]u8 = .{ 0xfa, 0xbf, 0xd5, 0xda };
        pub const TESTNET3: [4]u8 = .{ 0x0b, 0x11, 0x09, 0x07 };
        pub const SIGNET: [4]u8 = .{ 0x0a, 0x03, 0xcf, 0x40 };
    };

    const DNS_SEEDS = [1]DnsSeed{
        .{ .inner = "seed.bitcoin.sipa.be" },
        // Those are two other seeds that we will keep here for later.
        // We are still building and I don't want to spam the whole network everytime I reboot.
        // "seed.bitcoin.sprovoost.nl",
        // "seed.btc.petertodd.net",
    };

    allocator: std.mem.Allocator,
    /// RPC port
    rpc_port: u16 = 8332,
    /// P2P port
    p2p_port: u16 = 8333,
    /// Data directory
    datadir: [:0]const u8 = ".bitcoin",
    /// Services supported
    services: u64 = 0,
    /// Protocol version supported
    protocol_version: i32 = PROTOCOL_VERSION,
    /// Network Id
    network_id: [4]u8 = BitcoinNetworkId.MAINNET,

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
            } else if (std.mem.eql(u8, key, "network")) {
                if (std.mem.eql(u8, value, &BitcoinNetworkId.MAINNET)) {
                    config.network_id = BitcoinNetworkId.MAINNET;
                } else if (std.mem.eql(u8, value, &BitcoinNetworkId.REGTEST)) {
                    config.network_id = BitcoinNetworkId.REGTEST;
                } else if (std.mem.eql(u8, value, &BitcoinNetworkId.TESTNET3)) {
                    config.network_id = BitcoinNetworkId.TESTNET3;
                } else if (std.mem.eql(u8, value, &BitcoinNetworkId.SIGNET)) {
                    config.network_id = BitcoinNetworkId.SIGNET;
                } else {
                    return error.UnknownNetworkId;
                }
            } else if (std.mem.eql(u8, key, "datadir")) {
                config.datadir = try allocator.dupeZ(u8, value);
            } else if (std.mem.eql(u8, key, "services")) {
                config.services = try std.fmt.parseInt(u64, value, 10);
            } else if (std.mem.eql(u8, key, "protocol")) {
                config.protocol_version = try std.fmt.parseInt(i32, value, 10);
            }
        }

        return config;
    }

    pub fn dnsSeeds(self: *const Self) [1]DnsSeed {
        _ = self;
        return DNS_SEEDS;
    }

    pub fn bestBlock(self: *const Self) i32 {
        _ = self;
        // Should probably read it from db in the future
        return 0;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.datadir);
    }
};
