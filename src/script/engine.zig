const std = @import("std");
const Allocator = std.mem.Allocator;
const Stack = @import("stack.zig").Stack;
const Script = @import("lib.zig").Script;
const asBool = @import("lib.zig").asBool;
const ScriptNum = @import("lib.zig").ScriptNum;
const ScriptFlags = @import("lib.zig").ScriptFlags;
const arithmetic = @import("opcodes/arithmetic.zig");
const Opcode = @import("opcodes/constant.zig").Opcode;
const isUnnamedPushNDataOpcode = @import("opcodes/constant.zig").isUnnamedPushNDataOpcode;
const EngineError = @import("lib.zig").EngineError;
const ScriptBuilder = @import("scriptBuilder.zig").ScriptBuilder;
const sha1 = std.crypto.hash.Sha1;
const ripemd160 = @import("bitcoin-primitives").hashes.Ripemd160;
const Sha256 = std.crypto.hash.sha2.Sha256;
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
        // _ = format;
        // _ = args;
        // Uncomment this if you need to access the log
        // In the future it would be cool to log somewhere else than stderr
        std.debug.print(format, args);
    }

    /// Execute the script
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    pub fn execute(self: *Engine) EngineError!void {
        self.log("Executing script: {s}\n", .{std.fmt.fmtSliceHexLower(self.script.data)});

        while (self.pc < self.script.len()) {
            const opcodeByte = self.script.data[self.pc];
            self.log("\nPC: {d}, Opcode: 0x{x:0>2}\n", .{ self.pc, opcodeByte });
            self.logStack();

            self.pc += 1;
            const opcode: Opcode = try Opcode.fromByte(opcodeByte);
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

    fn executeOpcode(self: *Engine, opcode: Opcode) EngineError!void {
        self.log("Executing opcode: 0x{x:0>2}\n", .{opcode.toBytes()});

        // Check if the opcode is a push data opcode
        if (isUnnamedPushNDataOpcode(opcode)) |length| {
            try self.pushData(length);
            return;
        }

        // check if disabled opcode
        if (opcode.isDisabled()) {
            return self.opDisabled();
        }

        try switch (opcode) {
            Opcode.OP_0 => try self.pushData(0),
            Opcode.OP_PUSHDATA1 => try self.opPushData1(),
            Opcode.OP_PUSHDATA2 => try self.opPushData2(),
            Opcode.OP_PUSHDATA4 => try self.opPushData4(),
            Opcode.OP_1NEGATE => try self.op1Negate(),
            .OP_1, .OP_2, .OP_3, .OP_4, .OP_5, .OP_6, .OP_7, .OP_8, .OP_9, .OP_10, .OP_11, .OP_12, .OP_13, .OP_14, .OP_15, .OP_16 => try self.opN(opcode),
            Opcode.OP_NOP => try self.opNop(),
            Opcode.OP_VERIFY => try self.opVerify(),
            Opcode.OP_RETURN => try self.opReturn(),
            Opcode.OP_TOALTSTACK => try self.opToAltStack(),
            Opcode.OP_FROMALTSTACK => try self.opFromAltStack(),
            Opcode.OP_2DROP => try self.op2Drop(),
            Opcode.OP_2DUP => try self.op2Dup(),
            Opcode.OP_3DUP => try self.op3Dup(),
            Opcode.OP_2OVER => try self.op2Over(),
            Opcode.OP_2SWAP => try self.op2Swap(),
            Opcode.OP_IFDUP => self.opIfDup(),
            Opcode.OP_DEPTH => self.opDepth(),
            Opcode.OP_DROP => try self.opDrop(),
            Opcode.OP_DUP => try self.opDup(),
            Opcode.OP_EQUAL => try self.opEqual(),
            Opcode.OP_EQUALVERIFY => try self.opEqualVerify(),
            Opcode.OP_1ADD => try arithmetic.op1Add(self),
            Opcode.OP_1SUB => try arithmetic.op1Sub(self),
            Opcode.OP_NEGATE => try arithmetic.opNegate(self),
            Opcode.OP_ABS => try arithmetic.opAbs(self),
            Opcode.OP_NOT => try arithmetic.opNot(self),
            Opcode.OP_0NOTEQUAL => try arithmetic.op0NotEqual(self),
            Opcode.OP_ADD => try arithmetic.opAdd(self),
            Opcode.OP_SUB => try arithmetic.opSub(self),
            Opcode.OP_BOOLAND => try arithmetic.opBoolAnd(self),
            Opcode.OP_BOOLOR => try arithmetic.opBoolOr(self),
            Opcode.OP_NUMEQUAL => try arithmetic.opNumEqual(self),
            Opcode.OP_NUMEQUALVERIFY => try arithmetic.opNumEqualVerify(self),
            Opcode.OP_NUMNOTEQUAL => try arithmetic.opNumNotEqual(self),
            Opcode.OP_LESSTHAN => try arithmetic.opLessThan(self),
            Opcode.OP_GREATERTHAN => try arithmetic.opGreaterThan(self),
            Opcode.OP_LESSTHANOREQUAL => try arithmetic.opLessThanOrEqual(self),
            Opcode.OP_GREATERTHANOREQUAL => try arithmetic.opGreaterThanOrEqual(self),
            Opcode.OP_MIN => try arithmetic.opMin(self),
            Opcode.OP_MAX => try arithmetic.opMax(self),
            Opcode.OP_WITHIN => try arithmetic.opWithin(self),
            Opcode.OP_RIPEMD160 => try self.opRipemd160(),
            Opcode.OP_SHA256 => try self.opSha256(),
            Opcode.OP_HASH160 => try self.opHash160(),
            Opcode.OP_CHECKSIG => try self.opCheckSig(),
            Opcode.OP_NIP => try self.opNip(),
            Opcode.OP_OVER => try self.opOver(),
            Opcode.OP_PICK => try self.opPick(),
            Opcode.OP_SWAP => try self.opSwap(),
            Opcode.OP_TUCK => try self.opTuck(),
            Opcode.OP_SIZE => try self.opSize(),
            Opcode.OP_SHA1 => try self.opSha1(),
            else => try self.opInvalid(),
        };
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
        try self.stack.pushByteArray(self.script.data[self.pc .. self.pc + n]);
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
        try self.stack.pushByteArray(self.script.data[self.pc .. self.pc + n]);
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
        try self.stack.pushByteArray(self.script.data[self.pc .. self.pc + n]);
        self.pc += n;
    }

    /// OP_1NEGATE: Push the value -1 onto the stack
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    fn op1Negate(self: *Engine) !void {
        try self.stack.pushByteArray(&[_]u8{0x81});
    }

    /// OP_1 to OP_16: Push the value (opcode - 0x50) onto the stack
    ///
    /// # Arguments
    /// - `opcode`: The opcode (0x51 to 0x60)
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    fn opN(self: *Engine, opcode: Opcode) !void {
        const n = opcode.toBytes() - 0x50;
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

    /// OP_VERIFY: Pop the top value and verify it is true
    ///
    /// If verification fails or an error occurs
    fn opVerify(self: *Engine) !void {
        const value = try self.stack.popBool();
        if (!value) {
            return error.VerifyFailed;
        }
    }

    /// OP_RETURN: Immediately halt execution
    fn opReturn(self: *Engine) !void {
        _ = self;
        return error.EarlyReturn;
    }

    /// OP_TOALTSTACK: Puts the value onto the top of the alt stack, and removes it from the main stack.
    fn opToAltStack(self: *Engine) EngineError!void {
        const value = try self.stack.pop();
        try self.alt_stack.pushElement(value);
    }

    /// OP_FROMALTSTACK: Puts the value onto the top of the main stack, and removes it from the alt stack.
    fn opFromAltStack(self: *Engine) EngineError!void {
        const value = try self.alt_stack.pop();
        try self.stack.pushElement(value);
    }

    /// OP_2DROP: Drops top 2 stack items
    fn op2Drop(self: *Engine) !void {
        const first = try self.stack.pop();
        defer self.allocator.free(first);
        const second = try self.stack.pop();
        defer self.allocator.free(second);
    }

    /// OP_2DUP: Duplicates top 2 stack item
    fn op2Dup(self: *Engine) !void {
        const first = try self.stack.peek(0);
        const second = try self.stack.peek(1);
        try self.stack.pushByteArray(second);
        try self.stack.pushByteArray(first);
    }

    /// OP_3DUP: Duplicates top 3 stack item
    fn op3Dup(self: *Engine) !void {
        const first = try self.stack.peek(0);
        const second = try self.stack.peek(1);
        const third = try self.stack.peek(2);
        try self.stack.pushByteArray(third);
        try self.stack.pushByteArray(second);
        try self.stack.pushByteArray(first);
    }

    // OP_2OVER: Copies the pair of items two spaces back in the stack to the front
    fn op2Over(self: *Engine) !void {
        const fourth = try self.stack.peek(3);
        const third = try self.stack.peek(2);
        try self.stack.pushByteArray(fourth);
        try self.stack.pushByteArray(third);
    }

    // OP_2SWAP: Swaps the top two pairs of items
    fn op2Swap(self: *Engine) !void {
        try self.stack.swap(0, 2);
        try self.stack.swap(1, 3);
    }

    /// OP_DEPTH: Puts the number of stack items onto the stack.
    fn opDepth(self: *Engine) !void {
        const stack_length = self.stack.len();
        // Casting should be fine as stack length cannot contain more than 1000.
        try self.stack.pushInt(@intCast(stack_length));
    }

    /// OP_IFDUP: If the top stack value is not 0, duplicate it
    fn opIfDup(self: *Engine) !void {
        const value = try self.stack.peek(0);
        if (asBool(value)) {
            try self.stack.pushByteArray(value);
        }
    }

    /// OP_DROP: Drops top stack item
    fn opDrop(self: *Engine) !void {
        const item = try self.stack.pop();
        defer self.allocator.free(item);
    }

    /// OP_DUP: Duplicate the top stack item
    fn opDup(self: *Engine) !void {
        const value = try self.stack.peek(0);
        try self.stack.pushByteArray(value);
    }

    /// OP_NIP: Removes the second-to-top stack item
    fn opNip(self: *Engine) !void {
        const first = try self.stack.pop();
        errdefer self.allocator.free(first);
        const second = try self.stack.pop();
        defer self.allocator.free(second);
        try self.stack.pushElement(first);
    }

    /// OP_OVER: Copies the second-to-top stack item to the top
    fn opOver(self: *Engine) !void {
        const value = try self.stack.peek(1);
        try self.stack.pushByteArray(value);
    }

    /// OP_SWAP: The top two items on the stack are swapped.
    fn opSwap(self: *Engine) !void {
        const first = try self.stack.pop();
        errdefer self.allocator.free(first);
        const second = try self.stack.pop();
        errdefer self.allocator.free(second);

        try self.stack.pushElement(first);
        try self.stack.pushElement(second);
    }

    /// OP_TUCK: The item at the top of the stack is copied and inserted before the second-to-top item.
    fn opTuck(self: *Engine) !void {
        const first = try self.stack.pop();
        errdefer self.allocator.free(first);
        const second = try self.stack.pop();
        errdefer self.allocator.free(second);

        try self.stack.pushByteArray(first);
        try self.stack.pushElement(second);
        try self.stack.pushElement(first);
    }

    /// OP_SIZE: Pushes the size of the top element
    fn opSize(self: *Engine) !void {
        const first = try self.stack.peek(0);
        // Should be ok as the max len of an elem is MAX_SCRIPT_ELEMENT_SIZE (520)
        const len: i32 = @intCast(first.len);

        try self.stack.pushInt(len);
    }

    /// OP_EQUAL: Push 1 if the top two items are equal, 0 otherwise
    fn opEqual(self: *Engine) EngineError!void {
        const first = try self.stack.pop();
        defer self.allocator.free(first);
        const second = try self.stack.pop();
        defer self.allocator.free(second);

        const are_equal = std.mem.eql(u8, first, second);
        try self.stack.pushBool(are_equal);
    }

    /// OP_EQUALVERIFY: OP_EQUAL followed by OP_VERIFY
    fn opEqualVerify(self: *Engine) !void {
        try self.opEqual();
        try self.opVerify();
    }

    /// OP_Sha256: The input is hashed with SHA-256.
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    fn opSha256(self: *Engine) !void {
        const arr = try self.stack.pop();
        defer self.allocator.free(arr);

        // Create a digest buffer to hold the hash result
        var hash: [Sha256.digest_length]u8 = undefined;
        Sha256.hash(arr, &hash, .{});

        try self.stack.pushByteArray(&hash);
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
        defer self.allocator.free(pubkey);
        const sig = try self.stack.pop();
        defer self.allocator.free(sig);
        // TODO: Implement actual signature checking
        // Assume signature is valid for now
        try self.stack.pushBool(true);
    }

    /// OP_PICK: The item idx back in the stack is copied to the top.
    ///
    /// # Returns
    /// - `EngineError`: If an error occurs during execution
    fn opPick(self: *Engine) !void {
        const idx = try self.stack.popInt();
        const value = try self.stack.peek(@intCast(idx));
        try self.stack.pushByteArray(value);
    }

    fn opDisabled(self: *Engine) !void {
        _ = self;
        return error.DisabledOpcode;
    }

    fn opInvalid(self: *Engine) !void {
        _ = self;
        return error.UnknownOpcode;
    }

    fn opRipemd160(self: *Engine) !void {
        const data = try self.stack.pop();
        defer self.allocator.free(data);
        var hash: [ripemd160.digest_length]u8 = undefined;
        ripemd160.hash(data, &hash, .{});
        try self.stack.pushByteArray(&hash);
    }

    fn opSha1(self: *Engine) !void {
        const data = try self.stack.pop();
        defer self.allocator.free(data);
        var hash: [sha1.digest_length]u8 = undefined;
        sha1.hash(data, &hash, .{});
        try self.stack.pushByteArray(&hash);
    }
};

// Testing SHA1 against known vectors
test "opSha1 function test" {
    const test_cases = [_]struct {
        input: []const u8,
        expected: []const u8,
    }{
        .{ .input = "hello", .expected = "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d" },
        .{ .input = "blockchain", .expected = "56fde8f4392113e0f19e0430f14502e06968669f" },
        .{ .input = "abc", .expected = "a9993e364706816aba3e25717850c26c9cd0d89d" },
        .{ .input = "bitcoin", .expected = "ed1b8d80793e70c0608e8a8508a8dd80f6aa56f9" },
    };

    for (test_cases) |case| {
        const allocator = std.testing.allocator;

        const script_bytes = [_]u8{Opcode.OP_SHA1.toBytes()};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, .{});
        defer engine.deinit();

        // Push the input onto the stack
        try engine.stack.pushByteArray(case.input);

        // Call opSha1
        try engine.execute();

        // Pop the result from the stack
        const result = try engine.stack.pop();
        defer engine.allocator.free(result); // Free the result after use

        // Convert expected hash to bytes
        var expected_output: [sha1.digest_length]u8 = undefined;
        _ = try std.fmt.hexToBytes(&expected_output, case.expected);

        // Compare the result with the expected hash
        try std.testing.expectEqualSlices(u8, &expected_output, result);
    }
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
    try std.testing.expectEqual(1, engine.stack.len());

    // Check the item on the stack (should be 1)
    {
        const item = try engine.stack.pop();
        defer allocator.free(item);
        try std.testing.expectEqualSlices(u8, &[_]u8{1}, item);
    }
}

test "Script execution - OP_TOALTSTACK OP_FROMALTSTACK" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_TOALTSTACK OP_FROMALTSTACK
    const script_bytes = [_]u8{
        Opcode.OP_1.toBytes(),
        Opcode.OP_2.toBytes(),
        Opcode.OP_TOALTSTACK.toBytes(),
        Opcode.OP_TOALTSTACK.toBytes(),
        Opcode.OP_FROMALTSTACK.toBytes(),
    };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();

    try std.testing.expectEqual(1, try engine.stack.peekInt(0));
    try std.testing.expectEqual(2, try engine.alt_stack.peekInt(0));
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
    try std.testing.expectEqual(1, engine.stack.len());
}

test "Script execution - OP_1 OP_2 OP_2Dup" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_1 OP_EQUAL
    const script_bytes = [_]u8{ 0x51, 0x52, 0x6e };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();
    const element0 = try engine.stack.peekInt(0);
    const element1 = try engine.stack.peekInt(1);
    const element2 = try engine.stack.peekInt(2);
    const element3 = try engine.stack.peekInt(3);

    // Ensure the stack is empty after popping the result
    try std.testing.expectEqual(4, engine.stack.len());
    try std.testing.expectEqual(2, element0);
    try std.testing.expectEqual(1, element1);
    try std.testing.expectEqual(2, element2);
    try std.testing.expectEqual(1, element3);
}

test "Script execution - OP_1 OP_2 OP_3 OP_4 OP_3Dup" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_1 OP_EQUAL
    const script_bytes = [_]u8{ 0x51, 0x52, 0x53, 0x54, 0x6f };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();
    const element0 = try engine.stack.peekInt(0);
    const element1 = try engine.stack.peekInt(1);
    const element2 = try engine.stack.peekInt(2);
    const element3 = try engine.stack.peekInt(3);
    const element4 = try engine.stack.peekInt(4);
    const element5 = try engine.stack.peekInt(5);
    const element6 = try engine.stack.peekInt(6);

    // Ensure the stack is empty after popping the result
    try std.testing.expectEqual(7, engine.stack.len());
    try std.testing.expectEqual(4, element0);
    try std.testing.expectEqual(3, element1);
    try std.testing.expectEqual(2, element2);
    try std.testing.expectEqual(4, element3);
    try std.testing.expectEqual(3, element4);
    try std.testing.expectEqual(2, element5);
    try std.testing.expectEqual(1, element6);
}

test "Script execution - OP_1 OP_2 OP_3 OP_4 OP_2OVER" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_2 OP_3 OP_4 OP_2OVER
    const script_bytes = [_]u8{
        Opcode.OP_1.toBytes(),
        Opcode.OP_2.toBytes(),
        Opcode.OP_3.toBytes(),
        Opcode.OP_4.toBytes(),
        Opcode.OP_2OVER.toBytes(),
    };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();
    try std.testing.expectEqual(6, engine.stack.len());

    const element0 = try engine.stack.peekInt(0);
    const element1 = try engine.stack.peekInt(1);
    const element2 = try engine.stack.peekInt(2);
    const element3 = try engine.stack.peekInt(3);
    const element4 = try engine.stack.peekInt(4);
    const element5 = try engine.stack.peekInt(5);

    try std.testing.expectEqual(2, element0);
    try std.testing.expectEqual(1, element1);
    try std.testing.expectEqual(4, element2);
    try std.testing.expectEqual(3, element3);
    try std.testing.expectEqual(2, element4);
    try std.testing.expectEqual(1, element5);
}

test "Script execution - OP_1 OP_2 OP_3 OP_4 OP_2SWAP" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_2 OP_3 OP_4 OP_2SWAP
    const script_bytes = [_]u8{
        Opcode.OP_1.toBytes(),
        Opcode.OP_2.toBytes(),
        Opcode.OP_3.toBytes(),
        Opcode.OP_4.toBytes(),
        Opcode.OP_2SWAP.toBytes(),
    };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();
    try std.testing.expectEqual(4, engine.stack.len());

    const element0 = try engine.stack.peekInt(0);
    const element1 = try engine.stack.peekInt(1);
    const element2 = try engine.stack.peekInt(2);
    const element3 = try engine.stack.peekInt(3);

    try std.testing.expectEqual(2, element0);
    try std.testing.expectEqual(1, element1);
    try std.testing.expectEqual(4, element2);
    try std.testing.expectEqual(3, element3);
}

test "Script execution - OP_1 OP_2 OP_IFDUP" {
    const allocator = std.testing.allocator;

    // Simple script: OOP_1 OP_2 OP_IFDUP
    const script_bytes = [_]u8{ 0x51, 0x52, 0x73 };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();
    const element0 = try engine.stack.peekInt(0);
    const element1 = try engine.stack.peekInt(1);

    try std.testing.expectEqual(3, engine.stack.len());
    try std.testing.expectEqual(2, element0);
    try std.testing.expectEqual(2, element1);
}

test "Script execution - OP_OVER" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_2 OP_3 OP_OVER
    const script_bytes = [_]u8{
        Opcode.OP_1.toBytes(),
        Opcode.OP_2.toBytes(),
        Opcode.OP_3.toBytes(),
        Opcode.OP_OVER.toBytes(),
    };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();

    // Ensure the stack has the expected number of elements
    try std.testing.expectEqual(@as(usize, 4), engine.stack.len());

    // Check the stack elements
    const element0 = try engine.stack.peekInt(0);
    const element1 = try engine.stack.peekInt(1);
    const element2 = try engine.stack.peekInt(2);
    const element3 = try engine.stack.peekInt(3);

    try std.testing.expectEqual(2, element0);
    try std.testing.expectEqual(3, element1);
    try std.testing.expectEqual(2, element2);
    try std.testing.expectEqual(1, element3);
}

test "Script execution - OP_1 OP_2 OP_DEPTH" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_2 OP_DEPTH
    const script_bytes = [_]u8{ 0x51, 0x52, 0x74 };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();
    const element0 = try engine.stack.peekInt(0);
    const element1 = try engine.stack.peekInt(1);

    try std.testing.expectEqual(3, engine.stack.len());
    try std.testing.expectEqual(2, element0);
    try std.testing.expectEqual(2, element1);
}

test "Script execution - OP_1 OP_2 OP_DROP" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_2 OP_DROP
    const script_bytes = [_]u8{ 0x51, 0x52, 0x75 };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();
    try std.testing.expectEqual(1, engine.stack.len());

    const element0 = try engine.stack.peekInt(0);

    try std.testing.expectEqual(1, element0);
}

test "Script execution - OP_PICK" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_2 OP_3 OP_2 OP_PICK
    const script_bytes = [_]u8{
        Opcode.OP_1.toBytes(),
        Opcode.OP_2.toBytes(),
        Opcode.OP_3.toBytes(),
        Opcode.OP_2.toBytes(),
        Opcode.OP_PICK.toBytes(),
    };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();
    try std.testing.expectEqual(4, engine.stack.len());

    const element0 = try engine.stack.peekInt(0);
    const element1 = try engine.stack.peekInt(1);
    const element2 = try engine.stack.peekInt(2);
    const element3 = try engine.stack.peekInt(3);

    try std.testing.expectEqual(1, element0);
    try std.testing.expectEqual(3, element1);
    try std.testing.expectEqual(2, element2);
    try std.testing.expectEqual(1, element3);
}

test "Script execution - OP_DISABLED" {
    const allocator = std.testing.allocator;

    // Simple script to run a disabled opcode
    const script_bytes = [_]u8{0x95};
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    // Expect an error when running a disabled opcode
    try std.testing.expectError(error.DisabledOpcode, engine.opDisabled());
}

test "Script execution - OP_INVALID" {
    const allocator = std.testing.allocator;

    // Simple script to run an invalid opcode
    const script_bytes = [_]u8{0xff};
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    // Expect an error when running an invalid opcode
    try std.testing.expectError(error.UnknownOpcode, engine.opInvalid());
}

test "Script execution OP_1 OP_2 OP_3 OP_NIP" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_2 OP_3 OP_NIP
    const script_bytes = [_]u8{ 0x51, 0x52, 0x53, 0x77 };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();
    try std.testing.expectEqual(2, engine.stack.len());

    const element0 = try engine.stack.peekInt(0);
    const element1 = try engine.stack.peekInt(1);

    // Ensure the stack is empty after popping the result
    try std.testing.expectEqual(3, element0);
    try std.testing.expectEqual(1, element1);
}

test "Script execution OP_1 OP_2 OP_3 OP_OVER" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_2 OP_3 OP_OVER
    const script_bytes = [_]u8{ 0x51, 0x52, 0x53, 0x78 };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();
    try std.testing.expectEqual(4, engine.stack.len());

    const element0 = try engine.stack.peekInt(0);
    const element1 = try engine.stack.peekInt(1);

    try std.testing.expectEqual(2, element0);
    try std.testing.expectEqual(3, element1);
}

test "Script execution OP_1 OP_2 OP_3 OP_SWAP" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_2 OP_3 OP_SWAP
    const script_bytes = [_]u8{ 0x51, 0x52, 0x53, 0x7c };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();
    try std.testing.expectEqual(3, engine.stack.len());

    const element0 = try engine.stack.peekInt(0);
    const element1 = try engine.stack.peekInt(1);

    try std.testing.expectEqual(2, element0);
    try std.testing.expectEqual(3, element1);
}

test "Script execution OP_1 OP_2 OP_3 OP_TUCK" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_2 OP_3 OP_TUCK
    const script_bytes = [_]u8{ Opcode.OP_1.toBytes(), Opcode.OP_2.toBytes(), Opcode.OP_3.toBytes(), Opcode.OP_TUCK.toBytes() };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();
    try std.testing.expectEqual(4, engine.stack.len());

    const element0 = try engine.stack.peekInt(0);
    const element1 = try engine.stack.peekInt(1);
    const element2 = try engine.stack.peekInt(2);
    const element3 = try engine.stack.peekInt(3);

    try std.testing.expectEqual(3, element0);
    try std.testing.expectEqual(2, element1);
    try std.testing.expectEqual(3, element2);
    try std.testing.expectEqual(1, element3);
}

test "Script execution OP_1 OP_2 OP_3 OP_SIZE" {
    const allocator = std.testing.allocator;

    // Simple script: OP_1 OP_1 OP_EQUAL
    const script_bytes = [_]u8{ 0x51, 0x52, 0x53, 0x82 };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit();

    try engine.execute();
    try std.testing.expectEqual(4, engine.stack.len());

    const element0 = try engine.stack.popInt();
    const element1 = try engine.stack.peekInt(0);

    try std.testing.expectEqual(1, element0);
    try std.testing.expectEqual(3, element1);
}

test "Script execution OP_RIPEMD160" {
    const test_cases = [_]struct {
        input: []const u8,
        expected: []const u8,
    }{
        .{ .input = "", .expected = "9c1185a5c5e9fc54612808977ee8f548b2258d31" },
        .{ .input = "a", .expected = "0bdc9d2d256b3ee9daae347be6f4dc835a467ffe" },
        .{ .input = "abc", .expected = "8eb208f7e05d987a9b044a8e98c6b087f15a0bfc" },
        .{ .input = "message digest", .expected = "5d0689ef49d2fae572b881b123a85ffa21595f36" },
    };

    for (test_cases) |case| {
        const allocator = std.testing.allocator;

        const script_bytes = [_]u8{Opcode.OP_RIPEMD160.toBytes()};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, .{});
        defer engine.deinit();

        // Push the input onto the stack
        try engine.stack.pushByteArray(case.input);

        // Call opRipemd160
        try engine.execute();

        // Pop the result from the stack
        const result = try engine.stack.pop();
        defer engine.allocator.free(result); // Free the result after use

        // Convert expected hash to bytes
        var expected_output: [ripemd160.digest_length]u8 = undefined;
        _ = try std.fmt.hexToBytes(&expected_output, case.expected);

        // Compare the result with the expected hash
        try std.testing.expectEqualSlices(u8, &expected_output, result);
    }
}

test "Script execution - OP_SHA256" {
    const allocator = std.testing.allocator;

    const script_bytes = [_]u8{ Opcode.OP_1.toBytes(), Opcode.OP_SHA256.toBytes() };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, .{});
    defer engine.deinit(); // Ensure engine is deinitialized and memory is freed

    try engine.execute();

    try std.testing.expectEqual(1, engine.stack.len());

    const hash_bytes = try engine.stack.pop(); // Pop the result
    defer engine.allocator.free(hash_bytes); // Free the popped byte array

    try std.testing.expectEqual(Sha256.digest_length, hash_bytes.len);

    var expected_hash: [Sha256.digest_length]u8 = undefined;
    Sha256.hash(&[_]u8{1}, &expected_hash, .{});
    try std.testing.expectEqualSlices(u8, expected_hash[0..], hash_bytes);
}

test "ScriptBuilder Smoke test" {
    var sb = try ScriptBuilder.new(std.testing.allocator, null);
    defer sb.deinit();

    var engine = try (try (try (try sb.addInt(1)).addInt(2)).addOpcode(Opcode.OP_ADD)).build();

    try engine.execute();

    defer engine.deinit();

    try std.testing.expectEqual(1, engine.stack.len());
}

//METHOD 1
test "ScriptBuilder OP_SWAP METHOD 1" {
    var sb = try ScriptBuilder.new(std.testing.allocator, 4);

    var engine = try (try (try (try (try sb.addInt(1)).addInt(2)).addInt(3)).addOpcode(Opcode.OP_SWAP)).build();

    try engine.execute();

    defer sb.deinit();
    defer engine.deinit();

    try std.testing.expectEqual(@as(usize, 3), engine.stack.len());

    const element0 = try engine.stack.peekInt(0);
    const element1 = try engine.stack.peekInt(1);

    try std.testing.expectEqual(2, element0);
    try std.testing.expectEqual(3, element1);
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
    var engine = try sb.build();
    try engine.execute();
    defer engine.deinit();

    try std.testing.expectEqual(3, engine.stack.len());

    const element0 = try engine.stack.peekInt(0);
    const element1 = try engine.stack.peekInt(1);

    try std.testing.expectEqual(2, element0);
    try std.testing.expectEqual(3, element1);
}
