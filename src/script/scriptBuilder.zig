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

///ScriptBuilder is a library to generate easier scripts, useful for faster testing
pub const ScriptBuilder = struct {
    /// Number of opcodes in the script(this is not a necessary field and may be removed later)
    size: ?usize,

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
    pub fn new(allocator: Allocator, opcodeCount: ?u8) !ScriptBuilder {
        return ScriptBuilder{
            .size = opcodeCount orelse null,
            .script = std.ArrayList(u8).init(allocator),
            .allocator = allocator,
        };
    }

    ///Push an OPcode to the ScriptBuilder
    pub fn addOpcode(self: *ScriptBuilder, op: Opcode) !*ScriptBuilder {
        if (self.script.items.len + 1 > MAX_SCRIPT_SIZE) {
            return StackError.OutOfMemory;
        }
        try self.script.append(op.toBytes());
        return self;
    }

    ///Push an Int to the SciptBuilder
    pub fn addInt(self: *ScriptBuilder, num: u8) !*ScriptBuilder {
        switch (num) {
            0 => {
                _ = try self.script.append(Opcode.OP_0.toBytes());
            },
            1...16 => try self.script.append(Opcode.OP_1.toBytes() - 1 + num),
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
        } else if (data.len == 1 and data[0] >= 0x01 and data[0] <= 0x4b) {
            _ = try self.script.append(data[0]);
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
