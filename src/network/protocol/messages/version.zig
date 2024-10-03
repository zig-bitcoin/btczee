const std = @import("std");
const protocol = @import("../lib.zig");

const ServiceFlags = protocol.ServiceFlags;

const Sha256 = std.crypto.hash.sha2.Sha256;

const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;
const genericChecksum = @import("lib.zig").genericChecksum;
const NetworkAddress = @import("../NetworkAddress.zig").NetworkAddress;

/// VersionMessage represents the "version" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#version
pub const VersionMessage = struct {
    timestamp: i64,
    services: u64 = 0,
    nonce: u64,
    addr_recv: NetworkAddress,
    addr_from: NetworkAddress,
    version: i32,
    start_height: i32,
    user_agent: ?[]const u8 = null,
    relay: ?bool = null,

    const Self = @This();

    pub fn name() *const [12]u8 {
        return protocol.CommandNames.VERSION ++ [_]u8{0} ** 5;
    }

    /// Returns the message checksum
    ///
    /// Computed as `Sha256(Sha256(self.serialize()))[0..4]`
    pub fn checksum(self: *const Self) [4]u8 {
        return genericChecksum(self);
    }

    /// Free the `user_agent` if there is one
    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        if (self.user_agent) |ua| {
            allocator.free(ua);
        }
    }

    /// Serialize the message as bytes and write them to the Writer.
    ///
    /// `w` should be a valid `Writer`.
    pub fn serializeToWriter(self: *const Self, w: anytype) !void {
        comptime {
            if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects r to have fn 'writeInt'.");
            if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects r to have fn 'writeAll'.");
        }

        const user_agent_len: usize = if (self.user_agent) |ua|
            ua.len
        else
            0;
        const compact_user_agent_len = CompactSizeUint.new(user_agent_len);

        try w.writeInt(i32, self.version, .little);
        try w.writeInt(u64, self.services, .little);
        try w.writeInt(i64, self.timestamp, .little);
        try w.writeInt(u64, self.nonce, .little);
        try self.addr_recv.serializeToWriter(w);
        try self.addr_from.serializeToWriter(w);
        try compact_user_agent_len.encodeToWriter(w);
        if (user_agent_len != 0) {
            try w.writeAll(self.user_agent.?);
        }
        try w.writeInt(i32, self.start_height, .little);
        if (self.relay) |r| {
            try w.writeAll(std.mem.asBytes(&r));
        }
    }

    /// Serialize a message as bytes and write them to the buffer.
    ///
    /// buffer.len must be >= than self.hintSerializedLen()
    pub fn serializeToSlice(self: *const Self, buffer: []u8) !void {
        var fbs = std.io.fixedBufferStream(buffer);
        try self.serializeToWriter(fbs.writer());
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        const serialized_len = self.hintSerializedLen();

        const ret = try allocator.alloc(u8, serialized_len);
        errdefer allocator.free(ret);

        try self.serializeToSlice(ret);

        return ret;
    }

    /// Deserialize a Reader bytes as a `VersionMessage`
    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
        comptime {
            if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
            if (!std.meta.hasFn(@TypeOf(r), "readNoEof")) @compileError("Expects r to have fn 'readNoEof'.");
            if (!std.meta.hasFn(@TypeOf(r), "readAll")) @compileError("Expects r to have fn 'readAll'.");
            if (!std.meta.hasFn(@TypeOf(r), "readByte")) @compileError("Expects r to have fn 'readByte'.");
        }

        var vm: Self = undefined;

        vm.version = try r.readInt(i32, .little);
        vm.services = try r.readInt(u64, .little);
        vm.timestamp = try r.readInt(i64, .little);
        vm.nonce = try r.readInt(u64, .little);

        vm.addr_recv = try NetworkAddress.deserializeReader(r);
        vm.addr_from = try NetworkAddress.deserializeReader(r);

        const user_agent_len = (try CompactSizeUint.decodeReader(r)).value();

        if (user_agent_len != 0) {
            const user_agent = try allocator.alloc(u8, user_agent_len);
            errdefer allocator.free(user_agent);
            try r.readNoEof(user_agent);
            vm.user_agent = user_agent;
        } else {
            vm.user_agent = null;
        }
        vm.start_height = try r.readInt(i32, .little);
        vm.relay = if (r.readByte() catch null) |v| v != 0 else null;

        return vm;
    }

    /// Deserialize bytes into a `VersionMessage`
    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
        var fbs = std.io.fixedBufferStream(bytes);
        return try Self.deserializeReader(allocator, fbs.reader());
    }

    pub fn hintSerializedLen(self: *const Self) usize {
        // 4 + 8 + 8 + (2 * (8 + 16 + 2) + 8 + 4)
        const fixed_length = 84;
        const user_agent_len: usize = if (self.user_agent) |ua| ua.len else 0;
        const compact_user_agent_len = CompactSizeUint.new(user_agent_len);
        const compact_user_agent_len_len = compact_user_agent_len.hint_encoded_len();
        const relay_len: usize = if (self.relay != null) 1 else 0;
        const variable_length = compact_user_agent_len_len + user_agent_len + relay_len;
        return fixed_length + variable_length;
    }

    pub fn eql(self: *const Self, other: *const Self) bool {
        // Normal fields
        if (self.version != other.version //
        or self.services != other.services //
        or self.timestamp != other.timestamp //
                                             //
        or self.nonce != other.nonce) {
            return false;
        }
        
        // Compare NetworkAddress fields
        if (!self.addr_recv.eql(&other.addr_recv) or
            !self.addr_from.eql(&other.addr_from))
        {
            return false;
        }

        // user_agent
        if (self.user_agent) |lua| {
            if (other.user_agent) |rua| {
                if (!std.mem.eql(u8, lua, rua)) {
                    return false;
                }
            } else {
                return false;
            }
        } else {
            if (other.user_agent) |_| {
                return false;
            }
        }

        // relay
        if (self.relay != other.relay) {
            return false;
        }

        return true;
    }

    pub fn new(protocol_version: i32, me: NetworkAddress, you: NetworkAddress, nonce: u64, last_block: i32) Self {
        return .{
            .version = protocol_version,
            .timestamp = std.time.timestamp(),
            .addr_recv = you,
            .addr_from = me,
            .nonce = nonce,
            .start_height = last_block,
        };
    }
};

// TESTS

test "ok_full_flow_VersionMessage" {
    const allocator = std.testing.allocator;

    // No optional
    {
        const vm = VersionMessage{
            .version = 42,
            .services = ServiceFlags.NODE_NETWORK,
            .timestamp = 43,
            .addr_recv = NetworkAddress{
            .services = ServiceFlags.NODE_WITNESS,
            .ip = [_]u8{13} ** 16,
            .port = 33,
            },
        .addr_from = NetworkAddress{
            .services = ServiceFlags.NODE_BLOOM,
            .ip = [_]u8{12} ** 16,
            .port = 22,
        },
            .nonce = 31,
            .user_agent = null,
            .start_height = 1000,
            .relay = null,
        };

        const payload = try vm.serialize(allocator);
        defer allocator.free(payload);
        var deserialized_vm = try VersionMessage.deserializeSlice(allocator, payload);
        defer deserialized_vm.deinit(allocator);

        try std.testing.expect(vm.eql(&deserialized_vm));
    }

    // With relay
    {
        const vm = VersionMessage{
            .version = 42,
            .services = ServiceFlags.NODE_NETWORK,
            .timestamp = 43,
            .addr_recv = NetworkAddress {
            .services = ServiceFlags.NODE_WITNESS,
            .ip = [_]u8{13} ** 16,
            .port = 33,
            },
        .addr_from = NetworkAddress {
            .services = ServiceFlags.NODE_BLOOM,
            .ip = [_]u8{12} ** 16,
            .port = 22,
        },
            .nonce = 31,
            .user_agent = null,
            .start_height = 1000,
            .relay = true,
        };

        const payload = try vm.serialize(allocator);
        defer allocator.free(payload);
        var deserialized_vm = try VersionMessage.deserializeSlice(allocator, payload);
        defer deserialized_vm.deinit(allocator);

        try std.testing.expect(vm.eql(&deserialized_vm));
    }

    // With relay and user agent
    {
        const user_agent = [_]u8{0} ** 2046;
        const vm = VersionMessage{
            .version = 42,
            .services = ServiceFlags.NODE_NETWORK,
            .timestamp = 43,
            .addr_recv = NetworkAddress {
            .services = ServiceFlags.NODE_WITNESS,
            .ip = [_]u8{13} ** 16,
            .port = 33,
            },
            .addr_from = NetworkAddress {
            .services = ServiceFlags.NODE_BLOOM,
            .ip = [_]u8{12} ** 16,
            .port = 22,
            },
            .nonce = 31,
            .user_agent = &user_agent,
            .start_height = 1000,
            .relay = false,
        };

        const payload = try vm.serialize(allocator);
        defer allocator.free(payload);
        var deserialized_vm = try VersionMessage.deserializeSlice(allocator, payload);
        defer deserialized_vm.deinit(allocator);

        try std.testing.expect(vm.eql(&deserialized_vm));
    }
}
