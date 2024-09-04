const std = @import("std");

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
