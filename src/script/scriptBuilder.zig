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

    ///Push an Int to the SciptBuilder
    pub fn addInt(self: *ScriptBuilder, num: i32) !*ScriptBuilder {
        switch (num) {
            0 => {
                _ = try self.script.append(Opcode.OP_0.toBytes());
            },
            1...16 => try self.script.append(@intCast(Opcode.OP_1.toBytes() - 1 + num)),
            else => {
                _ = try self.addData(try ScriptNum.new(num).toBytes(self.allocator));
            },
        }
        return self;
    }

    pub fn addData(self: *ScriptBuilder, data: []const u8) !*ScriptBuilder {
        if (data.len == 0 or data.len == 1 and data[0] == 0) {
            _ = try self.addOpcode(Opcode.OP_0);
        } else if (data.len == 1 and data[0] <= 16) {
            const op = Opcode.OP_1.toBytes() - 1 + data[0];
            try self.script.append(op);
        } else if (data.len == 1 and data[0] == 0x81) {
            _ = try self.addOpcode(Opcode.OP_1NEGATE);
        } else if (data.len < Opcode.OP_PUSHDATA1.toBytes()) {
            _ = try self.script.append(@intCast(data.len));
            for (data) |byte| {
                try self.script.append(byte);
            }
        } else if (data.len >= Opcode.OP_PUSHDATA1.toBytes()) {
            if (data.len > 75 and data.len <= 255) {
                _ = try self.script.append(76);
                const size = &[1]u8{@intCast(data.len)};
                const n = std.mem.readInt(u8, size, .little);
                _ = try self.script.append(n);

                for (data) |byte| {
                    try self.script.append(byte);
                }
            } else if (data.len >= 256 and data.len <= 65535) {
                _ = try self.script.append(77);
                const length: u16 = @intCast(data.len);
                const n: [2]u8 = [2]u8{
                    @intCast(length & 0xFF), // lower byte (least significant byte)
                    @intCast((length >> 8) & 0xFF), // upper byte (most significant byte)
                };
                _ = try self.script.append(n[0]);
                _ = try self.script.append(n[1]);

                for (data) |byte| {
                    try self.script.append(byte);
                }
            } else if (data.len > 65535 and data.len <= 4294967295) {
                _ = try self.script.append(78);
                const length: u32 = @intCast(data.len);
                const n: [4]u8 = [4]u8{
                    @intCast(length & 0xFF), // lower byte (least significant byte)
                    @intCast(length >> 8 & 0xFF), // next byte
                    @intCast(length >> 16 & 0xFF), // next byte
                    @intCast((length >> 24) & 0xFF), // upper byte (most significant byte)
                };
                _ = try self.script.append(n[0]);
                _ = try self.script.append(n[1]);
                _ = try self.script.append(n[2]);
                _ = try self.script.append(n[3]);

                for (data) |byte| {
                    try self.script.append(byte);
                }
            }
        } else {
            _ = try self.script.append(Opcode.OP_PUSHDATA1.toBytes());
        }
        return self;
    }

    // Deallocate all resources used by the Engine
    pub fn deinit(self: *ScriptBuilder) void {
        self.script.deinit();
    }

    ///Execute the script. It creates and returns an engine instance.
    ///
    /// Returns
    /// Instance of the engine
    pub fn build(self: *ScriptBuilder) !engine.Engine {
        const script = Script.init(self.script.items);

        const script_engine = engine.Engine.init(self.allocator, script, .{});
        return script_engine;
    }
};

test "ScriptBuilder Smoke test" {
    var sb = try ScriptBuilder.new(std.testing.allocator, 3);
    defer sb.deinit();

    var e = try (try (try (try sb.addInt(1)).addInt(2)).addOpcode(Opcode.OP_ADD)).build();

    try e.execute();

    defer e.deinit();

    try std.testing.expectEqual(1, e.stack.len());

    const element0 = try e.stack.popInt();

    try std.testing.expectEqual(3, element0);
}

//METHOD 1
test "ScriptBuilder OP_SWAP METHOD 1" {
    var sb = try ScriptBuilder.new(std.testing.allocator, 4);
    std.debug.print("running test{}", .{2});

    var e = try (try (try (try (try sb.addInt(1)).addInt(2)).addInt(3)).addOpcode(Opcode.OP_SWAP)).build();

    try e.execute();

    defer sb.deinit();
    defer e.deinit();

    try std.testing.expectEqual(@as(usize, 3), e.stack.len());

    const element0 = try e.stack.peekInt(0);
    const element1 = try e.stack.peekInt(1);
    const element2 = try e.stack.peekInt(2);

    try std.testing.expectEqual(2, element0);
    try std.testing.expectEqual(3, element1);
    try std.testing.expectEqual(1, element2);
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
    try e.execute();
    defer e.deinit();

    try std.testing.expectEqual(3, e.stack.len());

    const element0 = try e.stack.peekInt(0);
    const element1 = try e.stack.peekInt(1);
    const element2 = try e.stack.peekInt(2);

    try std.testing.expectEqual(2, element0);
    try std.testing.expectEqual(3, element1);
    try std.testing.expectEqual(1, element2);
}

test "ScriptBuilder addData 0" {
    var sb = try ScriptBuilder.new(std.testing.allocator, 4);

    defer sb.deinit();
    const data = [_]u8{0};

    _ = try sb.addData(&data);
    var e = try sb.build();
    try e.execute();
    defer e.deinit();

    const element0 = try e.stack.peekInt(0);
    try std.testing.expectEqual(0, element0);
}

test "ScriptBuilder addData PUSHDATA" {
    var sb = try ScriptBuilder.new(std.testing.allocator, 4);

    defer sb.deinit();
    // data=abcd
    const data = [_]u8{ 97, 98, 99, 100 };

    _ = try sb.addData(&data);
    var e = try sb.build();
    try e.execute();
    defer e.deinit();

    try std.testing.expectEqual(1, e.stack.len());

    const element0 = try e.stack.peek(0);
    try std.testing.expectEqual(97, element0[0]);
    try std.testing.expectEqual(98, element0[1]);
    try std.testing.expectEqual(99, element0[2]);
    try std.testing.expectEqual(100, element0[3]);
}
