const std = @import("std");
const Allocator = std.mem.Allocator;
const Script = @import("lib.zig").Script;
pub const engine = @import("engine.zig");
const Opcode = @import("./opcodes/constant.zig").Opcode;
const ScriptNum = Script.ScriptNum;
const asBool = Script.asBool;
const asInt = Script.asInt;
const testing = std.testing;

pub const ScriptBuilder = struct {
    opcodeCount: u8,
    opcodes: []u8,

    pub fn new(allocator: std.mem.Allocator) !ScriptBuilder {
        return ScriptBuilder{
            .opcodeCount = 0,
            .opcodes = try allocator.alloc(u8, 0),
        };
    }

    pub fn pushOpcode(self: *ScriptBuilder, allocator: *Allocator, op: Opcode) !void {
        // Resize the array to add one more element
        const newOpcodes = try allocator.realloc(self.opcodes, self.opcodeCount + 1);
        newOpcodes[self.opcodeCount] = op.toBytes();
        self.opcodes = newOpcodes;
        self.opcodeCount += 1;
        // return self;
    }

    pub fn pushInt(self: *ScriptBuilder, allocator: *Allocator, num: u8) !void {
        const newOpcodes = try allocator.realloc(self.opcodes, self.opcodeCount + 1);
        const op = Opcode.pushOpcode(num);
        newOpcodes[self.opcodeCount] = op.toBytes();
        self.opcodes = newOpcodes;
        self.opcodeCount += 1;
        // return self;
    }

    pub fn deinit(self: *ScriptBuilder, allocator: *Allocator) void {
        if (self.opcodes.len > 0) {
            allocator.free(self.opcodes);
        }
    }

    pub fn build(self: *ScriptBuilder, allocator: *Allocator) !engine.Engine {
        const script = Script.init(self.opcodes);

        var script_engine = engine.Engine.init(allocator.*, script, .{});
        try script_engine.execute();
        return script_engine;
    }
};

test "ScriptBuilder" {
    var allocator = std.testing.allocator;
    var sb = try ScriptBuilder.new(allocator);
    defer sb.deinit(&allocator);

    std.debug.print("sb:{any}\n", .{sb});
}
test "ScriptBuilder push" {
    var allocator = std.testing.allocator;

    var sb = try ScriptBuilder.new(allocator);
    defer sb.deinit(&allocator);

    // const op0: u8 = Opcode.Op_1;

    _ = try sb.pushOpcode(&allocator, Opcode.OP_0);
    _ = try sb.pushInt(&allocator, 1);

    std.debug.print("sb:{any}\n", .{sb});
}

// test "Build engine" {
//     var allocator = std.testing.allocator;
//     var sb = try ScriptBuilder.new(allocator);

//     try sb.pushOpcode(&allocator, Opcode.OP_0);
//     try sb.pushInt(&allocator, 1);

//     std.debug.print("sb:{any}\n", .{sb});
//     const e = try sb.build(&allocator);

//     try std.testing.expectEqual(@as(usize, 2), e.stack.len());

//     // // Check the stack elements
//     // const element0 = try engine.stack.peekInt(0);
//     // const element1 = try engine.stack.peekInt(1);
//     // const element2 = try engine.stack.peekInt(2);
//     // const element3 = try engine.stack.peekInt(3);
//     defer sb.deinit(&allocator);
//     // std.debug.print("hello");
// }
