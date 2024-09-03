const std = @import("std");

pub const Config = struct {
    allocator: std.mem.Allocator,
    rpc_port: u16,
    p2p_port: u16,
    testnet: bool,
    datadir: []const u8,

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
