const std = @import("std");
const Allocator = std.mem.Allocator;
const ConditionalStack = @import("cond_stack.zig").ConditionalStack;
const ConditionalStackError = @import("cond_stack.zig").ConditionalStackError;
const FlowError = @import("opcodes/flow.zig").FlowError;
const Stack = @import("stack.zig").Stack;
const StackError = @import("stack.zig").StackError;
const Script = @import("lib.zig").Script;
const ScriptFlags = @import("lib.zig").ScriptFlags;
const arithmetic = @import("opcodes/arithmetic.zig");
const flow = @import("opcodes/flow.zig");

/// Errors that can occur during script execution
pub const EngineError = error{
    /// Script ended unexpectedly
    ScriptTooShort,
    /// OP_VERIFY failed
    VerifyFailed,
    /// OP_RETURN encountered
    EarlyReturn,
    /// Encountered an unknown opcode
    UnknownOpcode,
    /// Reserved opcode encountered
    ReservedOpcode,
} || StackError || ConditionalStackError || FlowError;

/// Engine is the virtual machine that executes Bitcoin scripts
pub const Engine = struct {
    /// The script being executed
    script: Script,
    /// Main stack for script execution
    stack: Stack,
    /// Alternative stack for some operations
    alt_stack: Stack,
    /// Program counter (current position in the script)
    pc: usize,
    /// Execution flags
    flags: ScriptFlags,
    /// Memory allocator
    allocator: Allocator,
    cond_stack: ConditionalStack,

    /// Initialize a new Engine
    ///
    /// # Arguments
    /// - `allocator`: Memory allocator for managing engine resources
    /// - `script`: The script to be executed
    /// - `flags`: Execution flags
    ///
    /// # Returns
    /// - `Engine`: A new Engine instance
    pub fn init(allocator: Allocator, script: Script, flags: ScriptFlags) Engine {
        return .{
            .script = script,
            .stack = Stack.init(allocator),
            .alt_stack = Stack.init(allocator),
            .pc = 0,
            .flags = flags,
            .allocator = allocator,
            .cond_stack = ConditionalStack.init(allocator),
        };
    }

    /// Deallocate all resources used by the Engine
    pub fn deinit(self: *Engine) void {
        self.stack.deinit();
        self.alt_stack.deinit();
        self.cond_stack.deinit();
    }

    /// Log debug information
    fn log(self: *Engine, comptime format: []const u8, args: anytype) void {
        _ = self;
        std.debug.print(format, args);
    }

    /// Execute the script
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    pub fn execute(self: *Engine) EngineError!void {
        self.log("Executing script: {s}\n", .{std.fmt.fmtSliceHexLower(self.script.data)});

        while (self.pc < self.script.len()) {
            const opcode = self.script.data[self.pc];
            self.log("\nPC: {d}, Opcode: 0x{x:0>2}\n", .{ self.pc, opcode });
            self.logStack();

            self.pc += 1;
            try self.executeOpcode(opcode);
        }

        self.log("\nExecution completed\n", .{});
        self.logStack();
    }

    /// Log the current state of the stack
    fn logStack(self: *Engine) void {
        self.log("Stack ({d} items):\n", .{self.stack.len()});
        for (self.stack.items.items) |item| {
            self.log("  {s}\n", .{std.fmt.fmtSliceHexLower(item)});
        }
    }

    /// Execute a single opcode
    ///
    /// # Arguments
    /// - `opcode`: The opcode to execute
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    fn executeOpcode(self: *Engine, opcode: u8) !void {
        self.log("Executing opcode: 0x{x:0>2}\n", .{opcode});
        try switch (opcode) {
            0x00 => try self.opFalse(),
            0x01...0x4b => try self.pushData(opcode),
            0x4c...0x4e => try opPushDataX(self, opcode),
            0x4f => try self.op1Negate(),
            0x50 => try self.opReserved(opcode),
            0x51...0x60 => try self.opN(opcode),
            0x61 => try self.opNop(),
            0x62 => try self.opReserved(opcode),
            0x63 => try flow.opIf(self),
            0x64 => try flow.opNotIf(self),
            0x65...0x66 => try self.opReserved(opcode),
            0x67 => try flow.opElse(self),
            0x68 => try flow.opEndIf(self),
            0x69 => try self.opVerify(),
            0x6a => try self.opReturn(),
            0x6d => try self.op2Drop(),
            0x6e => try self.op2Dup(),
            0x6f => try self.op3Dup(),
            0x73 => self.opIfDup(),
            0x74 => self.opDepth(),
            0x75 => try self.opDrop(),
            0x76 => try self.opDup(),
            0x87 => try self.opEqual(),
            0x88 => try self.opEqualVerify(),
            0x8b => try arithmetic.op1Add(self),
            0x8c => try arithmetic.op1Sub(self),
            0x8f => try arithmetic.opNegate(self),
            0x90 => try arithmetic.opAbs(self),
            0x91 => try arithmetic.opNot(self),
            0x92 => try arithmetic.op0NotEqual(self),
            0x93 => try arithmetic.opAdd(self),
            0x94 => try arithmetic.opSub(self),
            0x9a => try arithmetic.opBoolAnd(self),
            0x9b => try arithmetic.opBoolOr(self),
            0x9c => try arithmetic.opNumEqual(self),
            0x9d => try arithmetic.opNumEqualVerify(self),
            0x9e => try arithmetic.opNumNotEqual(self),
            0x9f => try arithmetic.opLessThan(self),
            0xa0 => try arithmetic.opGreaterThan(self),
            0xa1 => try arithmetic.opLessThanOrEqual(self),
            0xa2 => try arithmetic.opGreaterThanOrEqual(self),
            0xa3 => try arithmetic.opMin(self),
            0xa4 => try arithmetic.opMax(self),
            0xa5 => try arithmetic.opWithin(self),
            0xa9 => try self.opHash160(),
            0xac => try self.opCheckSig(),
            else => return error.UnknownOpcode,
        };
    }

    // Opcode implementations

    /// OP_FALSE: Pushes an empty array to the data stack to represent false.
    pub fn opFalse(self: *Engine) !void {
        const empty_array: []const u8 = &.{};
        try self.stack.pushByteArray(empty_array);
    }

    /// Push data onto the stack
    ///
    /// # Arguments
    /// - `n`: Number of bytes to push
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    fn pushData(self: *Engine, n: u8) !void {
        if (self.pc + n > self.script.len()) {
            return error.ScriptTooShort;
        }
        try self.stack.pushByteArray(self.script.data[self.pc .. self.pc + n]);
        self.pc += n;
    }

    /// Generalized function to handle OP_PUSHDATA operations with variable length prefixes.
    /// Pushes the next `n_bytes` as a length, then pushes that many bytes as an array.
    fn opPushDataX(self: *Engine, n_bytes: usize) !void {
        if (self.pc + n_bytes > self.script.len()) {
            return error.ScriptTooShort;
        }
        const n = self.script.data[self.pc];
        self.pc += n_bytes;
        try self.pushData(n);
    }

    /// OP_1NEGATE: Push the value -1 onto the stack
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    fn op1Negate(self: *Engine) !void {
        try self.stack.pushByteArray(&[_]u8{0x81});
    }

    /// OP_RESERVED: Reserved opcode
    pub fn opReserved(self: *Engine, opcode: u8) !void {
        if ((opcode == 0x50) or (opcode == 0x62)) {
            const msg = try std.fmt.allocPrint(self.allocator, "attempt to execute reserved opcode {}", .{opcode});
            defer self.allocator.free(msg);
            return error.ReservedOpcode;
        }
    }

    /// OP_1 to OP_16: Push the value (opcode - 0x50) onto the stack
    ///
    /// # Arguments
    /// - `opcode`: The opcode (0x51 to 0x60)
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    fn opN(self: *Engine, opcode: u8) !void {
        const n = opcode - 0x50;
        try self.stack.pushByteArray(&[_]u8{n});
    }

    /// OP_NOP: Do nothing
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    fn opNop(self: *Engine) !void {
        // Do nothing
        _ = self;
    }

    /// OP_VERIFY: Verify the top stack value
    ///
    /// # Returns
    /// - `EngineError`: If verification fails or an error occurs
    fn opVerify(self: *Engine) !void {
        const value = try self.stack.pop();
        defer self.allocator.free(value);
        if (value.len == 0 or (value.len == 1 and value[0] == 0)) {
            return error.VerifyFailed;
        }
    }

    /// OP_RETURN: Immediately halt execution
    ///
    /// # Returns
    /// - `EngineError.EarlyReturn`: Always
    fn opReturn(self: *Engine) !void {
        _ = self;
        return error.EarlyReturn;
    }

    /// OP_2DROP: Drops top 2 stack items
    ///
    /// # Returns
    /// - "EngineError.StackUnderflow": if initial stack length < 2
    fn op2Drop(self: *Engine) !void {
        if (self.stack.len() < 2) {
            return error.StackUnderflow;
        }
        const a = try self.stack.pop();
        const b = try self.stack.pop();

        defer self.allocator.free(a);
        defer self.allocator.free(b);
    }

    /// OP_2DUP: Duplicates top 2 stack item
    ///
    /// # Returns
    /// -  "EngineError.StackUnderflow": if initial stack length < 2
    fn op2Dup(self: *Engine) !void {
        if (self.stack.len() < 2) {
            return error.StackUnderflow;
        }

        const second_item = try self.stack.peek(0);
        const first_item = try self.stack.peek(1);
        try self.stack.pushByteArray(first_item);
        try self.stack.pushByteArray(second_item);
    }

    /// OP_3DUP: Duplicates top 3 stack item
    ///
    /// # Returns
    /// -  "EngineError.StackUnderflow": if initial stack length < 3
    fn op3Dup(self: *Engine) !void {
        if (self.stack.len() < 3) {
            return error.StackUnderflow;
        }
        const third_item = try self.stack.peek(2);
        const second_item = try self.stack.peek(1);
        const first_item = try self.stack.peek(0);
        try self.stack.pushByteArray(third_item);
        try self.stack.pushByteArray(second_item);
        try self.stack.pushByteArray(first_item);
    }

    /// OP_DEPTH: Puts the number of stack items onto the stack.
    ///
    /// # Returns
    /// -  "EngineError.StackUnderflow": if initial stack length == 0
    fn opDepth(self: *Engine) !void {
        if (self.stack.len() == 0) {
            return error.StackUnderflow;
        }
        const stack_length = self.stack.len();
        const u8_stack_length: u8 = @intCast(stack_length);
        try self.stack.pushByteArray(&[_]u8{u8_stack_length});
    }

    /// OP_IFDUP: If the top stack value is not 0, duplicate itp
    ///
    /// # Returns
    /// -  "EngineError.StackUnderflow": if initial stack length < 1
    fn opIfDup(self: *Engine) !void {
        if (self.stack.len() < 1) {
            return error.StackUnderflow;
        }
        const value = try self.stack.peek(0);
        if (value.len != 1 or value[0] != 0) {
            try self.stack.pushByteArray(value);
        }
    }

    /// OP_DROP: Drops top stack item
    ///
    /// # Returns
    /// -  "EngineError.StackUnderflow": if initial stack length < 1
    fn opDrop(self: *Engine) !void {
        if (self.stack.len() < 1) {
            return error.StackUnderflow;
        }
        const a = try self.stack.pop();
        defer self.allocator.free(a);
    }

    /// OP_DUP: Duplicate the top stack item
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    fn opDup(self: *Engine) !void {
        const value = try self.stack.peek(0);
        try self.stack.pushByteArray(value);
    }

    /// OP_EQUAL: Push 1 if the top two items are equal, 0 otherwise
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    fn opEqual(self: *Engine) EngineError!void {
        const b = try self.stack.pop();
        const a = try self.stack.pop();

        defer self.allocator.free(b);
        defer self.allocator.free(a);

        const equal = std.mem.eql(u8, a, b);
        try self.stack.pushByteArray(if (equal) &[_]u8{1} else &[_]u8{0});
    }

    /// OP_EQUALVERIFY: OP_EQUAL followed by OP_VERIFY
    ///
    /// # Returns
    /// - `EngineError`: If verification fails or an error occurs
    fn opEqualVerify(self: *Engine) !void {
        try self.opEqual();
        try self.opVerify();
    }

    /// OP_HASH160: Hash the top stack item with SHA256 and RIPEMD160
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    fn opHash160(self: *Engine) !void {
        _ = try self.stack.pop();
        // For now, just set the hash to a dummy value
        const hash: [20]u8 = [_]u8{0x00} ** 20;
        // TODO: Implement SHA256 and RIPEMD160
        try self.stack.pushByteArray(&hash);
    }

    /// OP_CHECKSIG: Verify a signature
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    fn opCheckSig(self: *Engine) !void {
        const pubkey = try self.stack.pop();
        const sig = try self.stack.pop();
        defer self.allocator.free(pubkey);
        defer self.allocator.free(sig);
        // TODO: Implement actual signature checking
        // Assume signature is valid for now
        try self.stack.pushByteArray(&[_]u8{1});
    }
};

test "Script execution - OP_FALSE" {
    const allocator = std.testing.allocator;

    // Simple script: OP_FALSE
    const script_bytes = [_]u8{0x00};
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.opFalse();

    // Check if the stack has one item (should be an empty array)
    try std.testing.expectEqual(@as(usize, 1), engine.stack.len());

    // Check the item on the stack (should be an empty array)
    {
        const item = try engine.stack.pop();
        defer allocator.free(item);
        try std.testing.expectEqualSlices(u8, &[_]u8{}, item);
    }
}

test "Script execution - OP_1 OP_1 OP_EQUAL" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_1 OP_EQUAL
    const script_bytes = [_]u8{ 0x51, 0x51, 0x87 };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();

    // Check if the execution result is true (non-empty stack with top element true)
    {
        const result = try engine.stack.pop();
        defer allocator.free(result);
        try std.testing.expect(result.len > 0 and result[0] != 0);
    }

    // Ensure the stack is empty after popping the result
    try std.testing.expectEqual(@as(usize, 0), engine.stack.len());
}

test "Script execution - OP_RETURN" {
    const allocator = std.testing.allocator;

    // Script: OP_1 OP_RETURN OP_2
    const script_bytes = [_]u8{ 0x51, 0x6a, 0x52 };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try std.testing.expectError(error.EarlyReturn, engine.execute());

    // Check if the stack has one item (OP_1 should have been executed)
    try std.testing.expectEqual(@as(usize, 1), engine.stack.len());

    // Check the item on the stack (should be 1)
    {
        const item = try engine.stack.pop();
        defer allocator.free(item);
        try std.testing.expectEqualSlices(u8, &[_]u8{1}, item);
    }
}

test "Script execution - OP_RESERVED" {
    const allocator = std.testing.allocator;
    const script_bytes = [_]u8{0x00};
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, ScriptFlags{});
    defer engine.deinit();

    const reserved_opcode: u8 = 0x50;

    // Expect the ReservedOpcode error when executing the reserved opcode
    try std.testing.expectError(error.ReservedOpcode, engine.opReserved(reserved_opcode));
}

test "Script execution - OP_1 OP_1 OP_1 OP_2Drop" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_1 OP_EQUAL
    const script_bytes = [_]u8{ 0x51, 0x51, 0x51, 0x6d };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();

    // Ensure the stack is empty after popping the result
    try std.testing.expectEqual(@as(usize, 1), engine.stack.len());
}

test "Script execution - OP_1 OP_2 OP_2Dup" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_1 OP_EQUAL
    const script_bytes = [_]u8{ 0x51, 0x52, 0x6e };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();
    const element0 = try engine.stack.peek(0);
    const element1 = try engine.stack.peek(1);
    const element2 = try engine.stack.peek(2);
    const element3 = try engine.stack.peek(3);

    // Ensure the stack is empty after popping the result
    try std.testing.expectEqual(@as(usize, 4), engine.stack.len());
    try std.testing.expectEqualSlices(u8, &[_]u8{2}, element0);
    try std.testing.expectEqualSlices(u8, &[_]u8{1}, element1);
    try std.testing.expectEqualSlices(u8, &[_]u8{2}, element2);
    try std.testing.expectEqualSlices(u8, &[_]u8{1}, element3);
}

test "Script execution - OP_1 OP_2 OP_3 OP_4 OP_3Dup" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_1 OP_EQUAL
    const script_bytes = [_]u8{ 0x51, 0x52, 0x53, 0x54, 0x6f };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();
    const element0 = try engine.stack.peek(0);
    const element1 = try engine.stack.peek(1);
    const element2 = try engine.stack.peek(2);
    const element3 = try engine.stack.peek(3);
    const element4 = try engine.stack.peek(4);
    const element5 = try engine.stack.peek(5);
    const element6 = try engine.stack.peek(6);

    // Ensure the stack is empty after popping the result
    try std.testing.expectEqual(@as(usize, 7), engine.stack.len());
    try std.testing.expectEqualSlices(u8, &[_]u8{4}, element0);
    try std.testing.expectEqualSlices(u8, &[_]u8{3}, element1);
    try std.testing.expectEqualSlices(u8, &[_]u8{2}, element2);
    try std.testing.expectEqualSlices(u8, &[_]u8{4}, element3);
    try std.testing.expectEqualSlices(u8, &[_]u8{3}, element4);
    try std.testing.expectEqualSlices(u8, &[_]u8{2}, element5);
    try std.testing.expectEqualSlices(u8, &[_]u8{1}, element6);
}

test "Script execution - OP_1 OP_2 OP_IFDUP" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_1 OP_EQUAL
    const script_bytes = [_]u8{ 0x51, 0x52, 0x73 };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();
    const element0 = try engine.stack.peek(0);
    const element1 = try engine.stack.peek(1);

    // Ensure the stack is empty after popping the result
    try std.testing.expectEqual(@as(usize, 3), engine.stack.len());
    try std.testing.expectEqualSlices(u8, &[_]u8{2}, element0);
    try std.testing.expectEqualSlices(u8, &[_]u8{2}, element1);
}

test "Script execution - OP_1 OP_2 OP_DEPTH" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_1 OP_EQUAL
    const script_bytes = [_]u8{ 0x51, 0x52, 0x74 };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();
    const element0 = try engine.stack.peek(0);
    const element1 = try engine.stack.peek(1);

    // Ensure the stack is empty after popping the result
    try std.testing.expectEqual(@as(usize, 3), engine.stack.len());
    try std.testing.expectEqualSlices(u8, &[_]u8{2}, element0);
    try std.testing.expectEqualSlices(u8, &[_]u8{2}, element1);
}

test "Script execution - OP_1 OP_2 OP_DROP" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_1 OP_EQUAL
    const script_bytes = [_]u8{ 0x51, 0x52, 0x75 };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();
    try std.testing.expectEqual(@as(usize, 1), engine.stack.len());

    const element0 = try engine.stack.peek(0);

    // Ensure the stack is empty after popping the result
    try std.testing.expectEqualSlices(u8, &[_]u8{1}, element0);
}
