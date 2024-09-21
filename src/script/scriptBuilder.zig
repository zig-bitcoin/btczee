const std = @import("std");
const Allocator = std.mem.Allocator;
const Script = @import("lib.zig").Script;
pub const engine = @import("engine.zig");
const Opcode = @import("./opcodes/constant.zig").Opcode;
const ScriptNum = Script.ScriptNum;
const asBool = Script.asBool;
const asInt = Script.asInt;
const testing = std.testing;
///ScriptBuilder is a library to generate easier scripts, useful for faster testing
pub const ScriptBuilder = struct {
    /// Number of opcodes in the script(this is not a necessary field and may be removed later)
    opcodeCount: u8,

    /// Dynamic array holding the opcodes
    opcodes: []u8,

    ///Memory Allocator
    allocator: Allocator,

    /// Initialize a new ScriptBuilder
    ///
    /// # Arguments
    /// - `allocator`: Memory allocator for managing engine resources
    ///
    /// # Returns
    /// - `!ScriptBuilder`: use with `try`
    pub fn new(allocator: std.mem.Allocator) !ScriptBuilder {
        return ScriptBuilder{
            .opcodeCount = 0,
            .opcodes = try allocator.alloc(u8, 0),
            .allocator = allocator,
        };
    }

    ///Push an OPcode to the ScriptBuilder
    pub fn pushOpcode(self: *ScriptBuilder, op: Opcode) !*ScriptBuilder {
        // Resize the array to add one more element
        const newOpcodes = try self.allocator.realloc(self.opcodes, self.opcodeCount + 1);

        newOpcodes[self.opcodeCount] = op.toBytes();
        self.opcodes = newOpcodes;
        self.opcodeCount += 1;
        return self;
    }

    ///Push an Int to the SciptBuilder
    /// OP_1...OP_16
    pub fn pushInt(self: *ScriptBuilder, num: u8) !*ScriptBuilder {
        const newOpcodes = try self.allocator.realloc(self.opcodes, self.opcodeCount + 1);
        const op = Opcode.pushOpcode(num);
        newOpcodes[self.opcodeCount] = op.toBytes();
        self.opcodes = newOpcodes;
        self.opcodeCount += 1;
        return self;
    }

    /// Deallocate all resources used by the Engine
    pub fn deinit(self: *ScriptBuilder) void {
        if (self.opcodes.len > 0) {
            self.allocator.free(self.opcodes);
        }
    }

    ///Execute the script. It creates an engine and executes the opcodes.
    ///
    /// Returns
    /// Instance of the engine
    pub fn build(self: *ScriptBuilder) !engine.Engine {
        const script = Script.init(self.opcodes);

        var script_engine = engine.Engine.init(self.allocator, script, .{});
        try script_engine.execute();
        return script_engine;
    }
};

// zig function chaining issue
// https://github.com/ziglang/zig/issues/5705
