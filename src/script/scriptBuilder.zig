const std = @import("std");
const Allocator = std.mem.Allocator;
const Script = @import("lib.zig").Script;
const StackError = @import("stack.zig").StackError;
pub const engine = @import("engine.zig");
const Opcode = @import("./opcodes/constant.zig").Opcode;
const isUnnamedPushNDataOpcode = @import("opcodes/constant.zig").isUnnamedPushNDataOpcode;
const ScriptNum = @import("lib.zig").ScriptNum;
const asBool = Script.asBool;
const asInt = Script.asInt;
const testing = std.testing;

/// Maximum script length in bytes
const MAX_SCRIPT_SIZE = 10000;

/// ScriptBuilder Errors
const ScriptBuilderError = error{ ScriptTooLong, ScriptTooShort };

///ScriptBuilder is a library to generate easier scripts, useful for faster testing
pub const ScriptBuilder = struct {
    /// Dynamic array holding the opcodes
    script: std.ArrayList(u8),

    ///Memory Allocator
    allocator: Allocator,

    /// Initialize a new ScriptBuilder
    ///
    /// # Arguments
    /// - `allocator`: Memory allocator for managing engine resources
    ///
    /// # Returns
    /// - `!ScriptBuilder`: use with `try`
    pub fn new(allocator: Allocator, capacity: usize) !ScriptBuilder {
        return ScriptBuilder{
            .script = try std.ArrayList(u8).initCapacity(allocator, capacity),
            .allocator = allocator,
        };
    }

    ///Push an OPcode to the ScriptBuilder
    pub fn addOpcode(self: *ScriptBuilder, op: Opcode) !*ScriptBuilder {
        if (self.script.items.len >= MAX_SCRIPT_SIZE) {
            return ScriptBuilderError.ScriptTooLong;
        }
        try self.script.append(op.toBytes());
        return self;
    }

    fn i32ToBytes(value: i32) [4]u8 {
        return [_]u8{
            @intCast(value & 0xFF), // Lower byte (least significant byte)
            @intCast((value >> 8) & 0xFF), // Next byte
            @intCast((value >> 16) & 0xFF), // Next byte
            @intCast((value >> 24) & 0xFF), // Upper byte (most significant byte)
        };
    }

    ///Push an Int to the SciptBuilder
    pub fn addInt(self: *ScriptBuilder, num: i32) !*ScriptBuilder {
        var byteArray: [4]u8 = undefined;

        // Get the bytes from the integer and copy them to the array
        std.mem.copyForwards(u8, &byteArray, std.mem.asBytes(&num));

        if (canonicalDataSize(&byteArray) + self.script.items.len >= MAX_SCRIPT_SIZE) {
            return ScriptBuilderError.ScriptTooLong;
        }
        switch (num) {
            0 => {
                try self.script.append(Opcode.OP_0.toBytes());
            },
            1...16 => try self.script.append(@intCast(Opcode.OP_1.toBytes() - 1 + num)),
            else => _ = try self.addData(try ScriptNum.new(num).toBytes(self.allocator)),
        }
        return self;
    }

    pub fn addData(self: *ScriptBuilder, data: []const u8) !*ScriptBuilder {
        const bytes_length: usize = @intCast(canonicalDataSize(data));
        if (bytes_length + self.script.items.len >= MAX_SCRIPT_SIZE) {
            return ScriptBuilderError.ScriptTooLong;
        }

        if (data.len == 0 or data.len == 1 and data[0] == 0) {
            _ = try self.addOpcode(Opcode.OP_0);
        } else if (data.len == 1 and data[0] <= 16) {
            const op = Opcode.OP_1.toBytes() - 1 + data[0];
            try self.script.append(op);
        } else if (data.len == 1 and data[0] == 0x81) {
            _ = try self.addOpcode(Opcode.OP_1NEGATE);
        } else if (data.len < Opcode.OP_PUSHDATA1.toBytes()) {
            try self.script.append(@intCast(data.len));
            try self.script.appendSlice(data);
        } else if (data.len <= 0xff) {
            try self.script.append(Opcode.OP_PUSHDATA1.toBytes());
            try self.script.append(@intCast(data.len));

            try self.script.appendSlice(data);
        } else if (data.len <= 0xffff) {
            try self.script.append(Opcode.OP_PUSHDATA2.toBytes());
            const length: u16 = @intCast(data.len);
            var n: [2]u8 = undefined;
            std.mem.writeInt(u16, &n, length, .little);
            try self.script.appendSlice(&n);

            try self.script.appendSlice(data);
        } else {
            try self.script.append(Opcode.OP_PUSHDATA4.toBytes());
            const length: u32 = @intCast(data.len);
            var n: [4]u8 = undefined;
            std.mem.writeInt(u32, &n, length, .little);

            try self.script.appendSlice(&n);
            try self.script.appendSlice(data);
        }
        return self;
    }

    // Deallocate all resources used by the Engine
    pub fn deinit(self: *ScriptBuilder) void {
        self.script.deinit();
    }

    /// Build the script. It creates and returns an engine instance.
    ///
    /// Returns
    /// Instance of the engine
    pub fn build(self: *ScriptBuilder) !engine.Engine {
        const script = Script.init(self.script.items);

        const script_engine = engine.Engine.init(self.allocator, script, .{});
        return script_engine;
    }

    /// Returns the Size in Bytes of the data to be added
    fn canonicalDataSize(data: []const u8) usize {
        const dataLen = data.len;

        if (dataLen == 0) {
            return 1;
        } else if (dataLen == 1 and data[0] <= 16) {
            return 1;
        } else if (dataLen == 1 and data[0] == 0x81) {
            return 1;
        }

        if (dataLen < Opcode.OP_PUSHDATA1.toBytes()) {
            return 1 + dataLen;
        } else if (dataLen <= 0xff) {
            return 2 + dataLen;
        } else if (dataLen <= 0xffff) {
            return 3 + dataLen;
        }

        return 5 + dataLen;
    }

    /// Private Function to addData without checking MAX_SCRIPT_SIZE
    /// Only to be used for testing soundess of the ScriptBuilder struct
    /// Cannot be called from other files
    fn addDataUnchecked(self: *ScriptBuilder, data: []const u8) !*ScriptBuilder {
        if (data.len == 0 or data.len == 1 and data[0] == 0) {
            _ = try self.addOpcode(Opcode.OP_0);
        } else if (data.len == 1 and data[0] <= 16) {
            const op = Opcode.OP_1.toBytes() - 1 + data[0];
            try self.script.append(op);
        } else if (data.len == 1 and data[0] == 0x81) {
            _ = try self.addOpcode(Opcode.OP_1NEGATE);
        } else if (data.len < Opcode.OP_PUSHDATA1.toBytes()) {
            try self.script.append(@intCast(data.len));
            try self.script.appendSlice(data);
        } else if (data.len <= 0xff) {
            try self.script.append(Opcode.OP_PUSHDATA1.toBytes());
            try self.script.append(@intCast(data.len));

            try self.script.appendSlice(data);
        } else if (data.len <= 0xffff) {
            try self.script.append(Opcode.OP_PUSHDATA2.toBytes());
            const length: u16 = @intCast(data.len);
            var n: [2]u8 = undefined;
            std.mem.writeInt(u16, &n, length, .little);
            try self.script.appendSlice(&n);

            try self.script.appendSlice(data);
        } else {
            try self.script.append(Opcode.OP_PUSHDATA4.toBytes());
            const length: u32 = @intCast(data.len);
            var n: [4]u8 = undefined;
            std.mem.writeInt(u32, &n, length, .little);

            try self.script.appendSlice(&n);
            try self.script.appendSlice(data);
        }
        return self;
    }
};

test "ScriptBuilder Smoke test" {
    var sb = try ScriptBuilder.new(std.testing.allocator, 3);
    defer sb.deinit();

    var e = try (try (try (try sb.addInt(1)).addInt(2)).addOpcode(Opcode.OP_ADD)).build();
    const expected = [_]u8{ 0x51, 0x52, 0x93 };
    defer e.deinit();

    try std.testing.expectEqualSlices(u8, &expected, e.script.data);
}

//METHOD 1
test "ScriptBuilder OP_SWAP METHOD 1" {
    var sb = try ScriptBuilder.new(std.testing.allocator, 4);

    var e = try (try (try (try (try sb.addInt(1)).addInt(2)).addInt(3)).addOpcode(Opcode.OP_SWAP)).build();

    const expected = [_]u8{ 0x51, 0x52, 0x53, 0x7c };

    defer sb.deinit();
    defer e.deinit();

    try std.testing.expectEqualSlices(u8, &expected, e.script.data);
}
//METHOD 2
test "ScriptBuilder OP_SWAP METHOD 2" {
    var sb = try ScriptBuilder.new(std.testing.allocator, 4);

    defer sb.deinit();
    //requirement to assign to _ can be removed
    _ = try sb.addInt(1);
    _ = try sb.addInt(2);
    _ = try sb.addInt(3);
    _ = try sb.addOpcode(Opcode.OP_SWAP);
    var e = try sb.build();

    defer e.deinit();
    const expected = [_]u8{ 0x51, 0x52, 0x53, 0x7c };

    try std.testing.expectEqualSlices(u8, &expected, e.script.data);
}

test "ScriptBuilder addData 0" {
    var sb = try ScriptBuilder.new(std.testing.allocator, 4);

    defer sb.deinit();
    const data = [_]u8{0};

    _ = try sb.addData(&data);
    var e = try sb.build();
    defer e.deinit();

    try std.testing.expectEqualSlices(u8, &[_]u8{Opcode.OP_0.toBytes()}, e.script.data);
}

test "ScriptBuilder addData PUSHDATA data.len == 1 and data[0] = 1..16" {
    var sb = try ScriptBuilder.new(std.testing.allocator, 4);
    std.debug.print("Running test 1..16", .{});
    defer sb.deinit();
    const data = [_]u8{12};
    const expected = [_]u8{0x5c};
    _ = try sb.addData(&data);
    var e = try sb.build();
    defer e.deinit();

    try std.testing.expectEqualSlices(u8, &expected, e.script.data);
}
test "ScriptBuilder addData PUSHDATA data.len == 1 and data[0] = Opcode.OP_negate" {
    var sb = try ScriptBuilder.new(std.testing.allocator, 4);

    defer sb.deinit();
    const data = [_]u8{0x81};
    const expected = [_]u8{0x4F};
    _ = try sb.addData(&data);
    var e = try sb.build();
    defer e.deinit();

    try std.testing.expectEqualSlices(u8, &expected, e.script.data);
}
test "ScriptBuilder addData PUSHDATA data.len < =opcode.pushdata1.toBytes()" {
    var sb = try ScriptBuilder.new(std.testing.allocator, 4);

    defer sb.deinit();
    const data = [_]u8{ 97, 98, 99, 100 };
    const expected = [_]u8{ 4, 97, 98, 99, 100 };
    _ = try sb.addData(&data);
    var e = try sb.build();
    defer e.deinit();

    try std.testing.expectEqualSlices(u8, &expected, e.script.data);
}

test "ScriptBuilder addData data.len <= 0xFF" {
    var sb = try ScriptBuilder.new(std.testing.allocator, 250);
    defer sb.deinit();

    var array: [250]u8 = undefined;
    var expected: [252]u8 = undefined;

    for (0..250) |i| {
        array[i] = 42;
    }

    expected[0] = Opcode.OP_PUSHDATA1.toBytes();
    expected[1] = 250;
    for (2..252) |i| {
        expected[i] = 42;
    }

    _ = try sb.addData(&array);
    var e = try sb.build();
    defer e.deinit();

    try std.testing.expectEqualSlices(u8, &expected, e.script.data);
}
test "ScriptBuilder addData data.len <= 0xFFFF" {
    var sb = try ScriptBuilder.new(std.testing.allocator, 65000);
    defer sb.deinit();

    var array: [65000]u8 = undefined;
    var expected: [65003]u8 = undefined;

    for (0..65000) |i| {
        array[i] = 42;
    }

    expected[0] = Opcode.OP_PUSHDATA2.toBytes();
    const n: [2]u8 = [2]u8{
        @intCast(65000 & 0xFF), // lower byte (least significant byte)
        @intCast((65000 >> 8) & 0xFF), // upper byte (most significant byte)
    };
    expected[1] = n[0];
    expected[2] = n[1];
    for (3..65003) |i| {
        expected[i] = 42;
    }

    const result_failed = sb.addData(&array);
    try std.testing.expectError(ScriptBuilderError.ScriptTooLong, result_failed);
}
test "ScriptBuilder addData data.len <= 0xFFFFFFFF" {
    var sb = try ScriptBuilder.new(std.testing.allocator, 4);
    defer sb.deinit();

    var array: [70000]u8 = undefined;
    var expected: [70005]u8 = undefined;

    for (0..70000) |i| {
        array[i] = 42;
    }

    expected[0] = Opcode.OP_PUSHDATA4.toBytes();
    const n: [4]u8 = [4]u8{
        @intCast(70000 & 0xFF), // lower byte (LSB)
        @intCast(70000 >> 8 & 0xFF), // next byte
        @intCast(70000 >> 16 & 0xFF), // next byte
        @intCast((70000 >> 24) & 0xFF), // upper byte (MSB)
    };
    expected[1] = n[0];
    expected[2] = n[1];
    expected[3] = n[2];
    expected[4] = n[3];
    for (5..70005) |i| {
        expected[i] = 42;
    }

    const result_failed = sb.addData(&array);
    try std.testing.expectError(ScriptBuilderError.ScriptTooLong, result_failed);
}

test "ScriptBuilder UNCHECKED_ADD_DATA data.len <= 0xFFFF" {
    var sb = try ScriptBuilder.new(std.testing.allocator, 65000);
    defer sb.deinit();

    var array: [65000]u8 = undefined;
    var expected: [65003]u8 = undefined;

    for (0..65000) |i| {
        array[i] = 42;
    }

    expected[0] = Opcode.OP_PUSHDATA2.toBytes();
    const n: [2]u8 = [2]u8{
        @intCast(65000 & 0xFF), // lower byte (least significant byte)
        @intCast((65000 >> 8) & 0xFF), // upper byte (most significant byte)
    };
    expected[1] = n[0];
    expected[2] = n[1];
    for (3..65003) |i| {
        expected[i] = 42;
    }

    _ = try sb.addDataUnchecked(&array);
    var e = try sb.build();
    defer e.deinit();

    try std.testing.expectEqualSlices(u8, &expected, e.script.data);
}

test "ScriptBuilder UNCHECKED_ADD_DATA data.len <= 0xFFFFFFFF" {
    var sb = try ScriptBuilder.new(std.testing.allocator, 4);
    defer sb.deinit();

    var array: [70000]u8 = undefined;
    var expected: [70005]u8 = undefined;

    for (0..70000) |i| {
        array[i] = 42;
    }

    expected[0] = Opcode.OP_PUSHDATA4.toBytes();
    const n: [4]u8 = [4]u8{
        @intCast(70000 & 0xFF), // lower byte (LSB)
        @intCast(70000 >> 8 & 0xFF), // next byte
        @intCast(70000 >> 16 & 0xFF), // next byte
        @intCast((70000 >> 24) & 0xFF), // upper byte (MSB)
    };
    expected[1] = n[0];
    expected[2] = n[1];
    expected[3] = n[2];
    expected[4] = n[3];
    for (5..70005) |i| {
        expected[i] = 42;
    }

    _ = try sb.addDataUnchecked(&array);
    var e = try sb.build();
    defer e.deinit();

    try std.testing.expectEqualSlices(u8, &expected, e.script.data);
}
