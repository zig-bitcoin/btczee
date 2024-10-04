const std = @import("std");

pub const NetworkAddress = struct {
    ip: [16]u8,
    port: u16,
    services: u64,

    pub fn eql(self: *const NetworkAddress, other: *const NetworkAddress) bool {
        return std.mem.eql(u8, &self.ip, &other.ip) and
            self.port == other.port and
            self.services == other.services;
    }

    pub fn serializeToWriter(self: *const NetworkAddress, writer: anytype) !void {
        try writer.writeInt(u64, self.services, .little);
        try writer.writeAll(&self.ip);
        try writer.writeInt(u16, self.port, .big);
    }

    pub fn deserializeReader(reader: anytype) !NetworkAddress {
        return NetworkAddress{
            .services = try reader.readInt(u64, .little),
            .ip = try reader.readBytesNoEof(16),
            .port = try reader.readInt(u16, .big),
        };
    }
};
