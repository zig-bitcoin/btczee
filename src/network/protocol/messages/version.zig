const std = @import("std");
const native_endian = @import("builtin").target.cpu.arch.endian();
const protocol = @import("../lib.zig");

const ServiceFlags = protocol.ServiceFlags;

const Endian = std.builtin.Endian;
const Sha256 = std.crypto.hash.sha2.Sha256;

const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;

/// VersionMessage represents the "version" message
///
/// https://developer.bitcoin.org/reference/p2p_networking.html#version
pub const VersionMessage = struct {
    recv_ip: [16]u8,
    trans_ip: [16]u8,
    timestamp: i64,
    services: u64,
    nonce: u64,
    recv_services: u64,
    trans_services: u64,
    version: i32,
    start_height: i32,
    recv_port: u16,
    trans_port: u16,
    user_agent: ?[]const u8,
    relay: ?bool,

    pub fn name() [12]u8 {
        var ret = std.mem.zeroes([12]u8);
        @memcpy(ret[0..7], protocol.CommandNames.VERSION);
        return ret;
    }

    /// Returns the message checksum
    ///
    /// Computed as `Sha256(Sha256(self.serialize()))[0..4]`
    pub fn checksum(self: VersionMessage) [4]u8 {
        var digest: [32]u8 = undefined;
        var hasher = Sha256.init(.{});
        const writer = hasher.writer();
        self.serializeToWriter(writer) catch unreachable; // Sha256.write is infaible
        hasher.final(&digest);

        Sha256.hash(&digest, &digest, .{});

        var ret: [4]u8 = undefined;
        @memcpy(ret[0..], digest[0..4]);

        return ret;
    }

    /// Free the `user_agent` if there is one
    pub fn deinit(self: VersionMessage, allocator: std.mem.Allocator) void {
        if (self.user_agent) |ua| {
            allocator.free(ua);
        }
    }

    /// Serialize the message as bytes and write them to the Writer.
    ///
    /// `w` should be a valid `Writer`.
    pub fn serializeToWriter(self: *const VersionMessage, w: anytype) !void {
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
        try w.writeInt(u64, self.recv_services, .little);
        try w.writeAll(std.mem.asBytes(&self.recv_ip));
        try w.writeInt(u16, self.recv_port, .big);
        try w.writeInt(u64, self.trans_services, .little);
        try w.writeAll(std.mem.asBytes(&self.trans_ip));
        try w.writeInt(u16, self.trans_port, .big);
        try w.writeInt(u64, self.nonce, .little);
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
    pub fn serializeToSlice(self: *const VersionMessage, buffer: []u8) !void {
        var fbs = std.io.fixedBufferStream(buffer);
        const writer = fbs.writer();
        try self.serializeToWriter(writer);
    }

    /// Serialize a message as bytes and return them.
    pub fn serialize(self: *const VersionMessage, allocator: std.mem.Allocator) ![]u8 {
        const serialized_len = self.hintSerializedLen();

        const ret = try allocator.alloc(u8, serialized_len);
        errdefer allocator.free(ret);

        try self.serializeToSlice(ret);

        return ret;
    }

    /// Deserialize a Reader bytes as a `VersionMessage`
    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !VersionMessage {
        comptime {
            if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
            if (!std.meta.hasFn(@TypeOf(r), "readNoEof")) @compileError("Expects r to have fn 'readNoEof'.");
            if (!std.meta.hasFn(@TypeOf(r), "readAll")) @compileError("Expects r to have fn 'readAll'.");
            if (!std.meta.hasFn(@TypeOf(r), "readByte")) @compileError("Expects r to have fn 'readByte'.");
        }

        var vm: VersionMessage = undefined;

        vm.version = try r.readInt(i32, .little);
        vm.services = try r.readInt(u64, .little);
        vm.timestamp = try r.readInt(i64, .little);
        vm.recv_services = try r.readInt(u64, .little);
        try r.readNoEof(&vm.recv_ip);
        vm.recv_port = try r.readInt(u16, .big);
        vm.trans_services = try r.readInt(u64, .little);
        try r.readNoEof(&vm.trans_ip);
        vm.trans_port = try r.readInt(u16, .big);
        vm.nonce = try r.readInt(u64, .little);

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
    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !VersionMessage {
        var fbs = std.io.fixedBufferStream(bytes);
        const reader = fbs.reader();
        return try VersionMessage.deserializeReader(allocator, reader);
    }

    pub fn hintSerializedLen(self: VersionMessage) usize {
        // 4 + 8 + 8 + (2 * (8 + 16 + 2) + 8 + 4)
        const fixed_length = 84;
        const user_agent_len: usize = if (self.user_agent) |ua| ua.len else 0;
        const compact_user_agent_len = CompactSizeUint.new(user_agent_len);
        const compact_user_agent_len_len = compact_user_agent_len.hint_encoded_len();
        const relay_len: usize = if (self.relay != null) 1 else 0;
        const variable_length = compact_user_agent_len_len + user_agent_len + relay_len;
        return fixed_length + variable_length;
    }

    pub fn eql(self: *const VersionMessage, other: *const VersionMessage) bool {
        // Normal fields
        if (self.version != other.version //
        or self.services != other.services //
        or self.timestamp != other.timestamp //
        or self.recv_services != other.recv_services //
        or !std.mem.eql(u8, &self.recv_ip, &other.recv_ip) //
        or self.recv_port != other.recv_port //
        or self.trans_services != other.trans_services //
        or !std.mem.eql(u8, &self.trans_ip, &other.trans_ip) //
        or self.trans_port != other.trans_port //
        or self.nonce != other.nonce) {
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
        if (self.relay) |ln| {
            if (other.relay) |rn| {
                if (ln != rn) {
                    return false;
                }
            } else {
                return false;
            }
        } else {
            if (other.relay) |_| {
                return false;
            }
        }

        return true;
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
            .recv_services = ServiceFlags.NODE_WITNESS,
            .trans_services = ServiceFlags.NODE_BLOOM,
            .recv_ip = [_]u8{13} ** 16,
            .trans_ip = [_]u8{12} ** 16,
            .recv_port = 33,
            .trans_port = 22,
            .nonce = 31,
            .user_agent = null,
            .start_height = 1000,
            .relay = null,
        };

        const payload = try vm.serialize(allocator);
        defer allocator.free(payload);
        const deserialized_vm = try VersionMessage.deserializeSlice(allocator, payload);
        defer deserialized_vm.deinit(allocator);

        try std.testing.expect(vm.eql(&deserialized_vm));
    }

    // With relay
    {
        const vm = VersionMessage{
            .version = 42,
            .services = ServiceFlags.NODE_NETWORK,
            .timestamp = 43,
            .recv_services = ServiceFlags.NODE_WITNESS,
            .trans_services = ServiceFlags.NODE_BLOOM,
            .recv_ip = [_]u8{13} ** 16,
            .trans_ip = [_]u8{12} ** 16,
            .recv_port = 33,
            .trans_port = 22,
            .nonce = 31,
            .user_agent = null,
            .start_height = 1000,
            .relay = true,
        };

        const payload = try vm.serialize(allocator);
        defer allocator.free(payload);
        const deserialized_vm = try VersionMessage.deserializeSlice(allocator, payload);
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
            .recv_services = ServiceFlags.NODE_WITNESS,
            .trans_services = ServiceFlags.NODE_BLOOM,
            .recv_ip = [_]u8{13} ** 16,
            .trans_ip = [_]u8{12} ** 16,
            .recv_port = 33,
            .trans_port = 22,
            .nonce = 31,
            .user_agent = &user_agent,
            .start_height = 1000,
            .relay = false,
        };

        const payload = try vm.serialize(allocator);
        defer allocator.free(payload);
        const deserialized_vm = try VersionMessage.deserializeSlice(allocator, payload);
        defer deserialized_vm.deinit(allocator);

        try std.testing.expect(vm.eql(&deserialized_vm));
    }
}
