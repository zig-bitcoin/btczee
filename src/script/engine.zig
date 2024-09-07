const std = @import("std");
const Allocator = std.mem.Allocator;
const Stack = @import("stack.zig").Stack;
const StackError = @import("stack.zig").StackError;
const Script = @import("lib.zig").Script;
const ScriptFlags = @import("lib.zig").ScriptFlags;
const arithmetic = @import("opcodes/arithmetic.zig");

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
} || StackError;

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
        };
    }

    /// Deallocate all resources used by the Engine
    pub fn deinit(self: *Engine) void {
        self.stack.deinit();
        self.alt_stack.deinit();
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
        switch (opcode) {
            0x00...0x4b => try self.pushData(opcode),
            0x4c => try self.opPushData1(),
            0x4d => try self.opPushData2(),
            0x4e => try self.opPushData4(),
            0x4f => try self.op1Negate(),
            0x51...0x60 => try self.opN(opcode),
            0x61 => try self.opNop(),
            0x69 => try self.opVerify(),
            0x6a => try self.opReturn(),
            0x76 => try self.opDup(),
            0x87 => try self.opEqual(),
            0x88 => try self.opEqualVerify(),
            0x8b => try arithmetic.op1Add(self),
            0x8c => try arithmetic.op1Sub(self),
            0x8f => try arithmetic.opNegate(self),
            0xa9 => try self.opHash160(),
            0xac => try self.opCheckSig(),
            else => return error.UnknownOpcode,
        }
    }

    // Opcode implementations

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
        try self.stack.push(self.script.data[self.pc .. self.pc + n]);
        self.pc += n;
    }

    /// OP_PUSHDATA1: Push the next byte as N, then push the next N bytes
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    fn opPushData1(self: *Engine) !void {
        if (self.pc + 1 > self.script.len()) {
            return error.ScriptTooShort;
        }
        const n = self.script.data[self.pc];
        self.pc += 1;
        try self.pushData(n);
    }

    /// OP_PUSHDATA2: Push the next 2 bytes as N, then push the next N bytes
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    fn opPushData2(self: *Engine) !void {
        if (self.pc + 2 > self.script.len()) {
            return error.ScriptTooShort;
        }
        const n = std.mem.readInt(u16, self.script.data[self.pc..][0..2], .little);
        self.pc += 2;
        if (self.pc + n > self.script.len()) {
            return error.ScriptTooShort;
        }
        try self.stack.push(self.script.data[self.pc .. self.pc + n]);
        self.pc += n;
    }

    /// OP_PUSHDATA4: Push the next 4 bytes as N, then push the next N bytes
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    fn opPushData4(self: *Engine) !void {
        if (self.pc + 4 > self.script.len()) {
            return error.ScriptTooShort;
        }
        const n = std.mem.readInt(u32, self.script.data[self.pc..][0..4], .little);
        self.pc += 4;
        if (self.pc + n > self.script.len()) {
            return error.ScriptTooShort;
        }
        try self.stack.push(self.script.data[self.pc .. self.pc + n]);
        self.pc += n;
    }

    /// OP_1NEGATE: Push the value -1 onto the stack
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    fn op1Negate(self: *Engine) !void {
        try self.stack.push(&[_]u8{0x81});
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
        try self.stack.push(&[_]u8{n});
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

    /// OP_DUP: Duplicate the top stack item
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    fn opDup(self: *Engine) !void {
        const value = try self.stack.peek(0);
        try self.stack.push(value);
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
        try self.stack.push(if (equal) &[_]u8{1} else &[_]u8{0});
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
        try self.stack.push(&hash);
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
        try self.stack.push(&[_]u8{1});
    }
};

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
