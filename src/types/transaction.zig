const std = @import("std");

const CompactSizeUint = @import("bitcoin-primitives").types.CompatSizeUint;
const readBytesExact = @import("../util/mem/read.zig").readBytesExact;
const Input = @import("input.zig");
const Output = @import("output.zig");
const Script = @import("script.zig");
const OutPoint = @import("outpoint.zig");
const Hash = @import("hash.zig");

version: i32,
inputs: []Input,
outputs: []Output,
lock_time: u32,
allocator: std.mem.Allocator,

const Self = @This();

pub fn serializeToWriter(self: *const Self, w: anytype) !void {
    comptime {
        if (!std.meta.hasFn(@TypeOf(w), "writeInt")) @compileError("Expects w to have field 'writeInt'.");
    }

    const compact_input_len = CompactSizeUint.new(self.inputs.len);
    const compact_output_len = CompactSizeUint.new(self.outputs.len);

    try w.writeInt(i32, self.version, .little);

    try compact_input_len.encodeToWriter(w);

    for (self.inputs) |input| {
        try input.serializeToWriter(w);
    }

    try compact_output_len.encodeToWriter(w);
    for (self.outputs) |output| {
        try output.serializeToWriter(w);
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
    const serialized_len = self.hintEncodedLen();

    const ret = try allocator.alloc(u8, serialized_len);
    errdefer allocator.free(ret);

    try self.serializeToSlice(ret);

    return ret;
}

pub fn deserializeReader(allocator: std.mem.Allocator, r: anytype) !Self {
    comptime {
        if (!std.meta.hasFn(@TypeOf(r), "readInt")) @compileError("Expects r to have fn 'readInt'.");
        if (!std.meta.hasFn(@TypeOf(r), "readByte")) @compileError("Expects r to have fn 'readByte'.");
    }

    var tx: Self = try Self.init(allocator);

    tx.version = try r.readInt(i32, .little);

    const compact_input_len = try CompactSizeUint.decodeReader(r);
    tx.inputs = try allocator.alloc(Input, compact_input_len.value());
    errdefer allocator.free(tx.inputs);

    var i: usize = 0;
    while (i < compact_input_len.value()) : (i += 1) {
        tx.inputs[i] = try Input.deserializeReader(allocator, r);
    }

    const compact_output_len = try CompactSizeUint.decodeReader(r);
    tx.outputs = try allocator.alloc(Output, compact_output_len.value());
    errdefer allocator.free(tx.outputs);

    var j: usize = 0;
    while (j < compact_output_len.value()) : (j += 1) {
        tx.outputs[j] = try Output.deserializeReader(allocator, r);
    }
    tx.lock_time = try r.readInt(u32, .little);

    return tx;
}

/// Deserialize bytes into Self
pub fn deserializeSlice(allocator: std.mem.Allocator, bytes: []const u8) !Self {
    var fbs = std.io.fixedBufferStream(bytes);
    return try Self.deserializeReader(allocator, fbs.reader());
}

/// Initialize a new transaction
pub fn init(allocator: std.mem.Allocator) !Self {
    return Self{
        .version = 1,
        .inputs = &[_]Input{},
        .outputs = &[_]Output{},
        .lock_time = 0,
        .allocator = allocator,
    };
}

/// Deinitialize the transaction
pub fn deinit(self: *Self) void {
    for (self.inputs) |*input| {
        input.deinit();
    }
    for (self.outputs) |*output| {
        output.deinit();
    }
    self.allocator.free(self.inputs);
    self.allocator.free(self.outputs);
}

/// Add an input to the transaction
pub fn addInput(self: *Self, previous_outpoint: OutPoint) !void {
    const script_sig = try Script.init(self.allocator);
    const new_capacity = self.inputs.len + 1;
    var new_inputs = try self.allocator.realloc(self.inputs, new_capacity);

    self.inputs = new_inputs;

    new_inputs[self.inputs.len - 1] = Input{
        .previous_outpoint = previous_outpoint,
        .script_sig = script_sig,
        .sequence = 0xffffffff,
    };
}

/// Add an output to the transaction
pub fn addOutput(self: *Self, value: i64, script_pubkey: Script) !void {
    var new_script = try Script.init(self.allocator);
    try new_script.push(script_pubkey.bytes.items);

    const new_capacity = self.outputs.len + 1;
    var new_outputs = try self.allocator.realloc(self.outputs, new_capacity);

    self.outputs = new_outputs;

    new_outputs[self.outputs.len - 1] = Output{
        .value = value,
        .script_pubkey = new_script,
    };
}

/// Calculate the transaction hash
pub fn hash(self: *const Self) Hash {
    var h: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(@as([]const u8, std.mem.asBytes(&self.version)), &h, .{});
    return Hash{ .bytes = h };
}

/// Calculate the size of the transaction
pub fn hintEncodedLen(self: *const Self) usize {
    // This is a simplified size calculation. In a real implementation,
    // you would need to account for segregated witness data if present.
    var size: usize = 8; // Version (4 bytes) + LockTime (4 bytes)
    size += self.inputs.len * 41; // Simplified input size
    size += self.outputs.len * 33; // Simplified output size
    return size;
}

pub fn eql(self: Self, other: Self) bool {
    // zig fmt: off
        return self.version == other.version
            and self.inputs.len == other.inputs.len
            and self.outputs.len == other.outputs.len
            and self.lock_time == other.lock_time
            and for (self.inputs, other.inputs) |a, b| {
                if (
                    !a.previous_outpoint.hash.eql(b.previous_outpoint.hash)
                    or a.previous_outpoint.index != b.previous_outpoint.index
                    or !std.mem.eql(u8, a.script_sig.bytes.items, b.script_sig.bytes.items)
                    or a.sequence != b.sequence
                ) break false;
            } else true
            and for (self.outputs, other.outputs) |c, d| {
                if (
                    c.value != d.value
                    or !std.mem.eql(u8, c.script_pubkey.bytes.items, d.script_pubkey.bytes.items)
                ) break false;
            } else true;
        // zig fmt: on
}

test "Transaction basics" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const OpCode = @import("../script/opcodes/constant.zig").Opcode;

    var tx = try Self.init(allocator);
    defer tx.deinit();

    try tx.addInput(OutPoint{ .hash = Hash.newZeroed(), .index = 0 });

    {
        var script_pubkey = try Script.init(allocator);
        defer script_pubkey.deinit();
        try script_pubkey.push(&[_]u8{ OpCode.OP_DUP.toBytes(), OpCode.OP_0.toBytes(), OpCode.OP_1.toBytes() });
        try tx.addOutput(50000, script_pubkey);
    }

    try testing.expectEqual(1, tx.inputs.len);
    try testing.expectEqual(1, tx.outputs.len);
    try testing.expectEqual(50000, tx.outputs[0].value);

    _ = tx.hash();

    const tx_size = tx.hintEncodedLen();
    try testing.expect(tx_size > 0);
}

test "Transaction serialization" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const OpCode = @import("../script/opcodes/constant.zig").Opcode;

    var tx = try Self.init(allocator);
    defer tx.deinit();

    try tx.addInput(OutPoint{ .hash = Hash.newZeroed(), .index = 0 });

    {
        var script_pubkey = try Script.init(allocator);
        defer script_pubkey.deinit();
        try script_pubkey.push(&[_]u8{ OpCode.OP_DUP.toBytes(), OpCode.OP_0.toBytes(), OpCode.OP_1.toBytes() });
        try tx.addOutput(50000, script_pubkey);
    }

    const payload = try tx.serialize(allocator);
    defer allocator.free(payload);

    var deserialized_tx = try Self.deserializeSlice(allocator, payload);
    defer deserialized_tx.deinit();

    try testing.expect(tx.eql(deserialized_tx));
}
