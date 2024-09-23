const std = @import("std");
const protocol = @import("../lib.zig");
const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;

const Sha256 = std.crypto.hash.sha2.Sha256;

pub const NetworkIPAddr = struct {
    time: u32,
    services: u64,
    ip: [16]u8,
    port: u16,

    pub fn eql(self: *const NetworkIPAddr, other: *const NetworkIPAddr) bool {
        return self.time == other.time
            and self.services == other.services
            and std.mem.eql(u8, &self.ip, &other.ip)
            and self.port == other.port;
    }

    pub fn serialize(self: *const NetworkIPAddr, writer: anytype) !void {
        try writer.writeInt(u32, self.time, .little);
        try writer.writeInt(u64, self.services, .little);
        try writer.writeAll(&self.ip);
        try writer.writeInt(u16, self.port, .big);
    }

    pub fn deserialize(reader: anytype) !NetworkIPAddr {
        return NetworkIPAddr{
            .time = try reader.readInt(u32, .little),
            .services = try reader.readInt(u64, .little),
            .ip = try reader.readBytesNoEof(16),
            .port = try reader.readInt(u16, .big),
        };
    }
};

pub const AddrMessage = struct {
    ip_addresses: std.ArrayList(NetworkIPAddr),

    pub fn init(allocator: std.mem.Allocator) AddrMessage {
        return AddrMessage{
            .ip_addresses = std.ArrayList(NetworkIPAddr).init(allocator),
        };
    }

    pub fn deinit(self: *AddrMessage) void {
        self.ip_addresses.deinit();
    }

    pub inline fn name() *const [12]u8 {
        return protocol.CommandNames.ADDR ++ [_]u8{0} ** 8;
    }

    /// Returns the message checksum
    ///
    /// Computed as `Sha256(Sha256(self.serialize()))[0..4]`
    pub fn checksum(self: AddrMessage) [4]u8 {
        var digest: [32]u8 = undefined;
        var hasher = Sha256.init(.{});
        const writer = hasher.writer();
        self.serializeToWriter(writer) catch unreachable; // Sha256.write is infaible
        hasher.final(&digest);

        Sha256.hash(&digest, &digest, .{});

        return digest[0..4].*;
    }

    pub fn serializeToWriter(self: *const AddrMessage, writer: anytype) !void {
        try CompactSizeUint.new(@intCast(self.ip_addresses.items.len)).encodeToWriter(writer);
        for (self.ip_addresses.items) |*addr| {
            try addr.serialize(writer);
        }
    }

    /// Serialize a message as bytes and write them to the buffer.
    ///
    /// buffer.len must be >= than self.hintSerializedLen()
    pub fn serializeToSlice(self: *const AddrMessage, buffer: []u8) !void {
        var fbs = std.io.fixedBufferStream(buffer);
        const writer = fbs.writer();
        try self.serializeToWriter(writer);
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const AddrMessage, allocator: std.mem.Allocator) ![]u8 {
        const serialized_len = self.hintSerializedLen();

        const ret = try allocator.alloc(u8, serialized_len);
        errdefer allocator.free(ret);

        try self.serializeToSlice(ret);

        return ret;
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, reader: anytype) !AddrMessage {
        var msg = AddrMessage.init(allocator);
        errdefer msg.deinit();

        const count = try CompactSizeUint.decodeReader(reader);
        try msg.ip_addresses.ensureTotalCapacity(@intCast(count.value()));

        var i: usize = 0;
        while (i < count.value()) : (i += 1) {
            const addr = try NetworkIPAddr.deserialize(reader);
            try msg.ip_addresses.append(addr);
        }

        return msg;
    }

    /// Deserialize bytes into a `AddrMessage`
    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !AddrMessage {
        var fbs = std.io.fixedBufferStream(bytes);
        const reader = fbs.reader();
        return try AddrMessage.deserializeReader(allocator, reader);
    }

    pub fn hintSerializedLen(self: AddrMessage) usize {
        // 4 + 8 + 16 + 2
        const fixed_length_per_ip = 30;
        return 1 +  self.ip_addresses.items.len * fixed_length_per_ip;// 1 for CompactSizeUint

    }

    pub fn eql(self: *const AddrMessage, other: *const AddrMessage) bool {
        if (self.ip_addresses.items.len != other.ip_addresses.items.len) return false;
        for (self.ip_addresses.items, other.ip_addresses.items) |addr1, addr2| {
            if (!addr1.eql(&addr2)) return false;
        }
        return true;
    }
};

// Test
test "AddrMessage serialization and deserialization" {
    const allocator = std.testing.allocator;

    var msg = AddrMessage.init(allocator);
    defer msg.deinit();

    try msg.ip_addresses.append(.{
        .time = 1414012889,
        .services = 1,
        .ip = [_]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0xff, 0xff, 192, 0, 2, 51 },
        .port = 8333,
    });

    var buf = std.ArrayList(u8).init(allocator);
    defer buf.deinit();

    try msg.serializeToWriter(buf.writer());

    // Create a mutable FixedBufferStream from the buffer
    var fbs = std.io.fixedBufferStream(buf.items);
    const reader = fbs.reader(); // Get the reader

    //var deserializedMsg = try AddrMessage.deserialize(allocator, std.io.fixedBufferStream(buf.items).reader());
    //defer deserializedMsg.deinit();
    // Deserialize the message
    var deserializedMsg = try AddrMessage.deserializeReader(allocator, reader);
    defer deserializedMsg.deinit(); // Ensure to free memory
                                             //
    try std.testing.expect(msg.eql(&deserializedMsg));
}
