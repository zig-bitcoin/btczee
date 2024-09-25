const std = @import("std");

const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;
const read_bytes_exact = @import("../util/mem/read.zig").read_bytes_exact;

/// Represents a transaction hash
pub const Hash = struct {
    bytes: [32]u8,

    /// Create a zero hash
    pub fn zero() Hash {
        return Hash{ .bytes = [_]u8{0} ** 32 };
    }

    /// Check if two hashes are equal
    pub fn eql(self: Hash, other: Hash) bool {
        return std.mem.eql(u8, &self.bytes, &other.bytes);
    }
};

/// Represents a transaction outpoint (reference to a previous transaction output)
pub const OutPoint = struct {
    hash: Hash,
    index: u32,
};

/// Represents a transaction input
pub const Input = struct {
    previous_outpoint: OutPoint,
    script_sig: Script,
    sequence: u32,
};

/// Represents a transaction output
pub const Output = struct {
    value: i64,
    script_pubkey: Script,
};

/// Represents a script (either scriptSig or scriptPubKey)
pub const Script = struct {
    bytes: []u8,
    allocator: std.mem.Allocator,

    /// Initialize a new script
    pub fn init(allocator: std.mem.Allocator) !Script {
        return Script{
            .bytes = try allocator.alloc(u8, 0),
            .allocator = allocator,
        };
    }

    /// Deinitialize the script
    pub fn deinit(self: *Script) void {
        self.allocator.free(self.bytes);
    }

    /// Add data to the script
    pub fn push(self: *Script, data: []const u8) !void {
        const new_len = self.bytes.len + data.len;
        self.bytes = try self.allocator.realloc(self.bytes, new_len);
        @memcpy(self.bytes[self.bytes.len - data.len ..], data);
    }
};

/// Represents a transaction
pub const Transaction = struct {
    version: i32,
    inputs: std.ArrayList(Input),
    outputs: std.ArrayList(Output),
    lock_time: u32,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn serializeToWriter(self: *const Transaction, w: anytype) !void {
        comptime {
            if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects w to have field 'writeInt'.");
            if (!std.meta.hasFn(@TypeOf(w), "writeAll")) @compileError("Expects w to have field 'writeAll'.");
        }

        const compact_input_len = CompactSizeUint.new(self.inputs.items.len);
        const compact_output_len = CompactSizeUint.new(self.outputs.items.len);

        try w.writeInt(i32, self.version, .little);

        try compact_input_len.encodeToWriter(w);

        for (self.inputs.items) |input| {
            const compact_script_len = CompactSizeUint.new(input.script_sig.bytes.len);

            try w.writeAll(&input.previous_outpoint.hash.bytes);
            try w.writeInt(u32, input.previous_outpoint.index, .little);
            try compact_script_len.encodeToWriter(w);
            try w.writeAll(input.script_sig.bytes);
            try w.writeInt(u32, input.sequence, .little);
        }

        try compact_output_len.encodeToWriter(w);
        for (self.outputs.items) |output| {
            const compact_script_len = CompactSizeUint.new(output.script_pubkey.bytes.len);

            try w.writeInt(i64, output.value, .little);
            try compact_script_len.encodeToWriter(w);
            try w.writeAll(output.script_pubkey.bytes);
        }

        try w.writeInt(u32, self.lock_time, .little);
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
        const serialized_len = self.virtual_size();

        const ret = try allocator.alloc(u8, serialized_len);
        errdefer allocator.free(ret);

        try self.serializeToSlice(ret);

        return ret;
    }

    pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
        comptime {
            if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
            if (!std.meta.hasFn(@TypeOf(r), "readNoEof")) @compileError("Expects r to have fn 'readNoEof'.");
            if (!std.meta.hasFn(@TypeOf(r), "readAll")) @compileError("Expects r to have fn 'readAll'.");
            if (!std.meta.hasFn(@TypeOf(r), "readByte")) @compileError("Expects r to have fn 'readByte'.");
        }

        var tx: Self = undefined;
        // errdefer tx.deinit();

        tx.version = try r.readInt(i32, .little);

        const compact_input_len = try CompactSizeUint.decodeReader(r);
        var inputs = try std.ArrayList(Input).initCapacity(allocator, compact_input_len.value());
        errdefer inputs.deinit();

        while (inputs.items.len < compact_input_len.value()) {
            var input: Input = undefined;
            var hash_bytes: [32]u8 = undefined;
            const hash_raw_bytes = try read_bytes_exact(allocator, r, 32);
            defer allocator.free(hash_raw_bytes);
            @memcpy(&hash_bytes, hash_raw_bytes);

            input.previous_outpoint.hash = Hash{ .bytes = hash_bytes };
            input.previous_outpoint.index = try r.readInt(u32, .little);
            const compact_script_len = (try CompactSizeUint.decodeReader(r)).value();

            input.script_sig = Script{ .bytes = try read_bytes_exact(allocator, r, compact_script_len), .allocator = allocator };
            input.sequence = try r.readInt(u32, .little);

            try inputs.append(input);
            errdefer {
                for (inputs.items) |i| {
                    i.script_pubkey.deinit();
                }
                allocator.free(inputs);
            }
        }
        tx.inputs = inputs;

        const compact_output_len = try CompactSizeUint.decodeReader(r);
        var outputs = try std.ArrayList(Output).initCapacity(allocator, compact_output_len.value());
        errdefer outputs.deinit();
        while (outputs.items.len < compact_output_len.value()) {
            var output: Output = undefined;
            output.value = try r.readInt(i64, .little);
            const compact_script_len = (try CompactSizeUint.decodeReader(r)).value();
            output.script_pubkey = Script{ .bytes = try read_bytes_exact(allocator, r, compact_script_len), .allocator = allocator };

            try outputs.append(output);
            errdefer {
                for (outputs.items) |o| {
                    o.script_pubkey.deinit();
                }
                allocator.free(outputs);
            }
        }
        tx.outputs = outputs;
        tx.lock_time = try r.readInt(u32, .little);

        return tx;
    }

    /// Deserialize bytes into a `VersionMessage`
    pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
        var fbs = std.io.fixedBufferStream(bytes);
        return try Self.deserializeReader(allocator, fbs.reader());
    }

    /// Initialize a new transaction
    pub fn init(allocator: std.mem.Allocator) !Transaction {
        return Transaction{
            .version = 1,
            .inputs = std.ArrayList(Input).init(allocator),
            .outputs = std.ArrayList(Output).init(allocator),
            .lock_time = 0,
            .allocator = allocator,
        };
    }

    /// Deinitialize the transaction
    pub fn deinit(self: *Transaction) void {
        for (self.inputs.items) |*input| {
            input.script_sig.deinit();
        }
        for (self.outputs.items) |*output| {
            output.script_pubkey.deinit();
        }
        self.inputs.deinit();
        self.outputs.deinit();
    }

    /// Add an input to the transaction
    pub fn addInput(self: *Transaction, previous_outpoint: OutPoint) !void {
        const script_sig = try Script.init(self.allocator);
        try self.inputs.append(Input{
            .previous_outpoint = previous_outpoint,
            .script_sig = script_sig,
            .sequence = 0xffffffff,
        });
    }

    /// Add an output to the transaction
    pub fn addOutput(self: *Transaction, value: i64, script_pubkey: Script) !void {
        var new_script = try Script.init(self.allocator);
        try new_script.push(script_pubkey.bytes);
        try self.outputs.append(Output{
            .value = value,
            .script_pubkey = new_script,
        });
    }

    /// Calculate the transaction hash
    pub fn hash(self: *const Transaction) Hash {
        var h: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(@as([]const u8, std.mem.asBytes(&self.version)), &h, .{});
        return Hash{ .bytes = h };
    }

    /// Calculate the virtual size of the transaction
    pub fn virtual_size(self: *const Transaction) usize {
        // This is a simplified size calculation. In a real implementation,
        // you would need to account for segregated witness data if present.
        var size: usize = 8; // Version (4 bytes) + LockTime (4 bytes)
        size += self.inputs.items.len * 41; // Simplified input size
        size += self.outputs.items.len * 33; // Simplified output size
        return size;
    }

    pub fn eql(self: Self, other: Self) bool {
        // zig fmt: off
        return self.version == other.version
            and self.inputs.items.len == other.inputs.items.len
            and self.outputs.items.len == other.outputs.items.len
            and self.lock_time == other.lock_time
            and for (self.inputs.items, other.inputs.items) |a, b| {
                if (
                    !a.previous_outpoint.hash.eql(b.previous_outpoint.hash)
                    or a.previous_outpoint.index != b.previous_outpoint.index
                    or !std.mem.eql(u8, a.script_sig.bytes, b.script_sig.bytes)
                    or a.sequence != b.sequence
                ) break false;
            } else true
            and for (self.outputs.items, other.outputs.items) |c, d| {
                if (
                    c.value != d.value
                    or !std.mem.eql(u8, c.script_pubkey.bytes, d.script_pubkey.bytes)
                ) break false;
            } else true;
        // zig fmt: on
    }
};

pub const RawTransaction = struct {
    version: u32,
    tx_in_count: CompactSizeUint, // maximum is 10 000 inputs
    tx_in: []Input,
    tx_out_count: CompactSizeUint, // maximum is 10 000 outputs
    tx_out: []Output,
    lock_time: u32,

    allocator: std.mem.Allocator,
};

test "Transaction basics" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tx = try Transaction.init(allocator);
    defer tx.deinit();

    try tx.addInput(OutPoint{ .hash = Hash.zero(), .index = 0 });

    {
        var script_pubkey = try Script.init(allocator);
        defer script_pubkey.deinit();
        try script_pubkey.push(&[_]u8{ 0x76, 0xa9, 0x14 }); // OP_DUP OP_HASH160 Push14
        try tx.addOutput(50000, script_pubkey);
    }

    try testing.expectEqual(@as(usize, 1), tx.inputs.items.len);
    try testing.expectEqual(@as(usize, 1), tx.outputs.items.len);
    try testing.expectEqual(@as(i64, 50000), tx.outputs.items[0].value);

    _ = tx.hash();

    const vsize = tx.virtual_size();
    try testing.expect(vsize > 0);
}

test "Transaction serialization" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var tx = try Transaction.init(allocator);
    defer tx.deinit();

    try tx.addInput(OutPoint{ .hash = Hash.zero(), .index = 0 });

    {
        var script_pubkey = try Script.init(allocator);
        defer script_pubkey.deinit();
        try script_pubkey.push(&[_]u8{ 0x76, 0xa9, 0x14 }); // OP_DUP OP_HASH160 Push14
        try tx.addOutput(50000, script_pubkey);
    }

    const payload = try tx.serialize(allocator);
    defer allocator.free(payload);

    var deserialized_tx = try Transaction.deserializeSlice(allocator, payload);
    defer deserialized_tx.deinit();

    // version: i32,
    // inputs: std.ArrayList(Input),
    // outputs: std.ArrayList(Output),
    // lock_time: u32,
    try testing.expect(tx.eql(deserialized_tx));
    // for (tx.inputs.items, 0..) |input, i| {
    //     try testing.expectEqual(input.previous_outpoint.hash.bytes, deserialized_tx.inputs.items[i].previous_outpoint.hash.bytes);
    //     try testing.expectEqual(input.previous_outpoint.index, deserialized_tx.inputs.items[i].previous_outpoint.index);
    //     try testing.expect(std.mem.eql(u8, input.script_sig.bytes, deserialized_tx.inputs.items[i].script_sig.bytes));
    //     try testing.expectEqual(input.sequence, deserialized_tx.inputs.items[i].sequence);
    // }
    // for (tx.outputs.items, 0..) |output, i| {
    //     try testing.expectEqual(output.value, deserialized_tx.outputs.items[i].value);
    //     try testing.expect(std.mem.eql(u8, output.script_pubkey.bytes, deserialized_tx.outputs.items[i].script_pubkey.bytes));
    // }
    // try testing.expectEqual(tx.lock_time, deserialized_tx.lock_time);
}
