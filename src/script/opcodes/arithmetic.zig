const std = @import("std");
const testing = std.testing;
const Engine = @import("../engine.zig").Engine;
const Script = @import("../lib.zig").Script;
const ScriptNum = @import("../lib.zig").ScriptNum;
const ScriptFlags = @import("../lib.zig").ScriptFlags;
const StackError = @import("../stack.zig").StackError;

/// OP_1ADD: Add 1 to the top stack item
pub fn op1Add(self: *Engine) !void {
    const value = try self.stack.popInt();
    const result = @addWithOverflow(value, 1);
    try self.stack.pushInt(result[0]);
}

/// OP_1SUB: Subtract 1 from the top stack item
pub fn op1Sub(self: *Engine) !void {
    const value = try self.stack.popInt();
    const result = @subWithOverflow(value, 1);
    try self.stack.pushInt(result[0]);
}

/// OP_NEGATE: Negate the top stack item
pub fn opNegate(self: *Engine) !void {
    const value = try self.stack.popInt();
    const result = if (value == std.math.minInt(ScriptNum))
        std.math.minInt(ScriptNum)
    else
        -value;
    try self.stack.pushInt(result);
}

/// Computes the absolute value of the top stack item
pub fn opAbs(engine: *Engine) !void {
    const value = try engine.stack.popInt();
    const result = if (value == std.math.minInt(ScriptNum))
        std.math.minInt(ScriptNum) // Handle overflow case
    else if (value < 0)
        -value
    else
        value;
    try engine.stack.pushInt(result);
}

/// Pushes true if the top stack item is 0, false otherwise
pub fn opNot(self: *Engine) !void {
    const value = try self.stack.popInt();
    const result = if (value == 0) true else false;
    try self.stack.pushBool(result);
}

/// Pushes 1 if the top stack item is not 0, 0 otherwise
pub fn op0NotEqual(self: *Engine) !void {
    const value = try self.stack.popInt();
    const result: ScriptNum = if (value != 0) 1 else 0;
    try self.stack.pushInt(result);
}

/// Adds the top two stack items
pub fn opAdd(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result = @addWithOverflow(a, b);
    try self.stack.pushInt(result[0]);
}

/// Subtracts the top stack item from the second top stack item
pub fn opSub(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result = @subWithOverflow(a, b);
    try self.stack.pushInt(result[0]);
}

/// Pushes true if both top two stack items are non-zero, false otherwise
pub fn opBoolAnd(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result = if ((a != 0) and (b != 0)) true else false;
    try self.stack.pushBool(result);
}

/// Pushes true if either of the top two stack items is non-zero, false otherwise
pub fn opBoolOr(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result = if ((a != 0) or (b != 0)) true else false;
    try self.stack.pushBool(result);
}

/// Pushes true if the top two stack items are equal, false otherwise
pub fn opNumEqual(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result = if (a == b) true else false;
    try self.stack.pushBool(result);
}

/// Helper function to verify the top stack item is true
pub fn abstractVerify(self: *Engine) !void {
    const verified = try self.stack.popBool();
    if (!verified) {
        return StackError.VerifyFailed;
    }
}

/// Combines opNumEqual and abstractVerify operations
pub fn opNumEqualVerify(self: *Engine) !void {
    try opNumEqual(self);
    try abstractVerify(self);
}

/// Pushes true if the top two stack items are not equal, false otherwise
pub fn opNumNotEqual(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result = if (a != b) true else false;
    try self.stack.pushBool(result);
}

/// Pushes true if the second top stack item is less than the top stack item, false otherwise
pub fn opLessThan(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result = if (a < b) true else false;
    try self.stack.pushBool(result);
}

/// Pushes true if the second top stack item is greater than the top stack item, false otherwise
pub fn opGreaterThan(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result = if (a > b) true else false;
    try self.stack.pushBool(result);
}

/// Pushes true if the second top stack item is less than or equal to the top stack item, false otherwise
pub fn opLessThanOrEqual(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result = if (a <= b) true else false;
    try self.stack.pushBool(result);
}

/// Pushes true if the second top stack item is greater than or equal to the top stack item, false otherwise
pub fn opGreaterThanOrEqual(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result = if (a >= b) true else false;
    try self.stack.pushBool(result);
}

/// Pushes the minimum of the top two stack items
pub fn opMin(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result = if (a < b) a else b;
    try self.stack.pushInt(result);
}

/// Pushes the maximum of the top two stack items
pub fn opMax(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result = if (a > b) a else b;
    try self.stack.pushInt(result);
}

/// Pushes true if x is within the range [min, max], false otherwise
pub fn opWithin(self: *Engine) !void {
    const max = try self.stack.popInt();
    const min = try self.stack.popInt();
    const x = try self.stack.popInt();
    const result = if ((min <= x) and (x < max)) true else false;
    try self.stack.pushBool(result);
}

test "OP_1ADD operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        input: ScriptNum,
        expected: ScriptNum,
    }{
        .{ .input = 0, .expected = 1 },
        .{ .input = -1, .expected = 0 },
        .{ .input = 42, .expected = 43 },
        .{ .input = -100, .expected = -99 },
        .{ .input = std.math.maxInt(ScriptNum), .expected = std.math.minInt(ScriptNum) }, // Overflow case
        .{ .input = std.math.minInt(ScriptNum), .expected = std.math.minInt(ScriptNum) + 1 },
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input value onto the stack
        try engine.stack.pushInt(tc.input);

        // Execute OP_1ADD
        try op1Add(&engine);

        // Check the result
        const result = try engine.stack.popInt();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_1SUB operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        input: ScriptNum,
        expected: ScriptNum,
    }{
        .{ .input = 0, .expected = -1 },
        .{ .input = 1, .expected = 0 },
        .{ .input = -1, .expected = -2 },
        .{ .input = 42, .expected = 41 },
        .{ .input = -100, .expected = -101 },
        .{ .input = std.math.maxInt(ScriptNum), .expected = std.math.maxInt(ScriptNum) - 1 },
        .{ .input = std.math.minInt(ScriptNum), .expected = std.math.maxInt(ScriptNum) }, // Underflow case
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input value onto the stack
        try engine.stack.pushInt(tc.input);

        // Execute OP_1SUB
        try op1Sub(&engine);

        // Check the result
        const result = try engine.stack.popInt();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_NEGATE operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        input: ScriptNum,
        expected: ScriptNum,
    }{
        .{ .input = 0, .expected = 0 },
        .{ .input = 1, .expected = -1 },
        .{ .input = -1, .expected = 1 },
        .{ .input = 42, .expected = -42 },
        .{ .input = -42, .expected = 42 },
        .{ .input = std.math.maxInt(ScriptNum), .expected = -std.math.maxInt(ScriptNum) },
        .{ .input = std.math.minInt(ScriptNum), .expected = std.math.minInt(ScriptNum) }, // Special case
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input value onto the stack
        try engine.stack.pushInt(tc.input);

        // Execute OP_NEGATE
        try opNegate(&engine);

        // Check the result
        const result = try engine.stack.popInt();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_ABS operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        input: ScriptNum,
        expected: ScriptNum,
    }{
        .{ .input = 0, .expected = 0 },
        .{ .input = 1, .expected = 1 },
        .{ .input = -1, .expected = 1 },
        .{ .input = 42, .expected = 42 },
        .{ .input = -42, .expected = 42 },
        .{ .input = std.math.maxInt(ScriptNum), .expected = std.math.maxInt(ScriptNum) },
        .{ .input = std.math.minInt(ScriptNum), .expected = std.math.minInt(ScriptNum) }, // Special case
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input value onto the stack
        try engine.stack.pushInt(tc.input);

        // Execute OP_ABS
        try opAbs(&engine);

        // Check the result
        const result = try engine.stack.popInt();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_NOT operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        input: ScriptNum,
        expected: bool,
    }{
        .{ .input = 0, .expected = true },
        .{ .input = 1, .expected = false },
        .{ .input = -1, .expected = false },
        .{ .input = 42, .expected = false },
        .{ .input = -42, .expected = false },
        .{ .input = std.math.maxInt(ScriptNum), .expected = false },
        .{ .input = std.math.minInt(ScriptNum), .expected = false }, // Special case
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input value onto the stack
        try engine.stack.pushInt(tc.input);

        // Execute OP_NOT
        try opNot(&engine);

        // Check the result
        const result = try engine.stack.popBool();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_0NOTEQUAL operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        input: ScriptNum,
        expected: ScriptNum,
    }{
        .{ .input = 0, .expected = 0 },
        .{ .input = 1, .expected = 1 },
        .{ .input = -1, .expected = 1 },
        .{ .input = 42, .expected = 1 },
        .{ .input = -42, .expected = 1 },
        .{ .input = std.math.maxInt(ScriptNum), .expected = 1 },
        .{ .input = std.math.minInt(ScriptNum), .expected = 1 }, // Special case
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input value onto the stack
        try engine.stack.pushInt(tc.input);

        // Execute OP_0NOTEQUAL
        try op0NotEqual(&engine);

        // Check the result
        const result = try engine.stack.popInt();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_ADD operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: ScriptNum,
        b: ScriptNum,
        expected: ScriptNum,
    }{
        .{ .a = 0, .b = 0, .expected = 0 },
        .{ .a = 0, .b = 1, .expected = 1 },
        .{ .a = 1, .b = 0, .expected = 1 },
        .{ .a = 1, .b = 1, .expected = 2 },
        .{ .a = -1, .b = 1, .expected = 0 },
        .{ .a = 42, .b = 42, .expected = 84 },
        .{ .a = -42, .b = 42, .expected = 0 },
        .{ .a = std.math.maxInt(ScriptNum), .b = 1, .expected = std.math.minInt(ScriptNum) }, // Overflow case
        .{ .a = std.math.minInt(ScriptNum), .b = -1, .expected = std.math.maxInt(ScriptNum) }, // Underflow case
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input values onto the stack
        try engine.stack.pushInt(tc.a);
        try engine.stack.pushInt(tc.b);

        // Execute OP_ADD
        try opAdd(&engine);

        // Check the result
        const result = try engine.stack.popInt();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_SUB operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: ScriptNum,
        b: ScriptNum,
        expected: ScriptNum,
    }{
        .{ .a = 0, .b = 0, .expected = 0 },
        .{ .a = 0, .b = 1, .expected = -1 },
        .{ .a = 1, .b = 0, .expected = 1 },
        .{ .a = 1, .b = 1, .expected = 0 },
        .{ .a = -1, .b = 1, .expected = -2 },
        .{ .a = 42, .b = 42, .expected = 0 },
        .{ .a = -42, .b = 42, .expected = -84 },
        .{ .a = std.math.maxInt(ScriptNum), .b = -1, .expected = std.math.minInt(ScriptNum) }, // Overflow case
        .{ .a = std.math.minInt(ScriptNum), .b = 1, .expected = std.math.maxInt(ScriptNum) }, // Underflow case
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input values onto the stack
        try engine.stack.pushInt(tc.a);
        try engine.stack.pushInt(tc.b);

        // Execute OP_SUB
        try opSub(&engine);

        // Check the result
        const result = try engine.stack.popInt();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_BOOLOR operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: ScriptNum,
        b: ScriptNum,
        expected: bool,
    }{
        .{ .a = 0, .b = 0, .expected = false },
        .{ .a = 0, .b = 1, .expected = true },
        .{ .a = 1, .b = 0, .expected = true },
        .{ .a = 1, .b = 1, .expected = true },
        .{ .a = -1, .b = 1, .expected = true },
        .{ .a = 42, .b = 42, .expected = true },
        .{ .a = -42, .b = 42, .expected = true },
        .{ .a = std.math.maxInt(ScriptNum), .b = 1, .expected = true },
        .{ .a = std.math.minInt(ScriptNum), .b = -1, .expected = true },
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input values onto the stack
        try engine.stack.pushInt(tc.a);
        try engine.stack.pushInt(tc.b);

        // Execute OP_BOOLOR
        try opBoolOr(&engine);

        // Check the result
        const result = try engine.stack.popBool();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_NUMEQUAL operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: ScriptNum,
        b: ScriptNum,
        expected: bool,
    }{
        .{ .a = 0, .b = 0, .expected = true },
        .{ .a = 0, .b = 1, .expected = false },
        .{ .a = 1, .b = 0, .expected = false },
        .{ .a = 1, .b = 1, .expected = true },
        .{ .a = -1, .b = 1, .expected = false },
        .{ .a = 42, .b = 42, .expected = true },
        .{ .a = -42, .b = 42, .expected = false },
        .{ .a = std.math.maxInt(ScriptNum), .b = 1, .expected = false },
        .{ .a = std.math.minInt(ScriptNum), .b = -1, .expected = false },
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input values onto the stack
        try engine.stack.pushInt(tc.a);
        try engine.stack.pushInt(tc.b);

        // Execute OP_NUMEQUAL
        try opNumEqual(&engine);

        // Check the result
        const result = try engine.stack.popBool();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_NUMNOTEQUAL operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: ScriptNum,
        b: ScriptNum,
        expected: bool,
    }{
        .{ .a = 0, .b = 0, .expected = false },
        .{ .a = 0, .b = 1, .expected = true },
        .{ .a = 1, .b = 0, .expected = true },
        .{ .a = 1, .b = 1, .expected = false },
        .{ .a = -1, .b = 1, .expected = true },
        .{ .a = 42, .b = 42, .expected = false },
        .{ .a = -42, .b = 42, .expected = true },
        .{ .a = std.math.maxInt(ScriptNum), .b = 1, .expected = true },
        .{ .a = std.math.minInt(ScriptNum), .b = -1, .expected = true },
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input values onto the stack
        try engine.stack.pushInt(tc.a);
        try engine.stack.pushInt(tc.b);

        // Execute OP_NUMNOTEQUAL
        try opNumNotEqual(&engine);

        // Check the result
        const result = try engine.stack.popBool();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_LESSTHAN operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: ScriptNum,
        b: ScriptNum,
        expected: bool,
    }{
        .{ .a = 0, .b = 0, .expected = false },
        .{ .a = 0, .b = 1, .expected = true },
        .{ .a = 1, .b = 0, .expected = false },
        .{ .a = 1, .b = 1, .expected = false },
        .{ .a = -1, .b = 1, .expected = true },
        .{ .a = 42, .b = 42, .expected = false },
        .{ .a = -42, .b = 42, .expected = true },
        .{ .a = std.math.maxInt(ScriptNum), .b = 1, .expected = false },
        .{ .a = std.math.minInt(ScriptNum), .b = -1, .expected = true },
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input values onto the stack
        try engine.stack.pushInt(tc.a);
        try engine.stack.pushInt(tc.b);

        // Execute OP_LESSTHAN
        try opLessThan(&engine);

        // Check the result
        const result = try engine.stack.popBool();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_GREATERTHAN operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: ScriptNum,
        b: ScriptNum,
        expected: bool,
    }{
        .{ .a = 0, .b = 0, .expected = false },
        .{ .a = 0, .b = 1, .expected = false },
        .{ .a = 1, .b = 0, .expected = true },
        .{ .a = 1, .b = 1, .expected = false },
        .{ .a = -1, .b = 1, .expected = false },
        .{ .a = 42, .b = 42, .expected = false },
        .{ .a = -42, .b = 42, .expected = false },
        .{ .a = std.math.maxInt(ScriptNum), .b = 1, .expected = true },
        .{ .a = std.math.minInt(ScriptNum), .b = -1, .expected = false },
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input values onto the stack
        try engine.stack.pushInt(tc.a);
        try engine.stack.pushInt(tc.b);

        // Execute OP_GREATERTHAN
        try opGreaterThan(&engine);

        // Check the result
        const result = try engine.stack.popBool();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_LESSTHANOREQUAL operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: ScriptNum,
        b: ScriptNum,
        expected: bool,
    }{
        .{ .a = 0, .b = 0, .expected = true },
        .{ .a = 0, .b = 1, .expected = true },
        .{ .a = 1, .b = 0, .expected = false },
        .{ .a = 1, .b = 1, .expected = true },
        .{ .a = -1, .b = 1, .expected = true },
        .{ .a = 42, .b = 42, .expected = true },
        .{ .a = -42, .b = 42, .expected = true },
        .{ .a = std.math.maxInt(ScriptNum), .b = 1, .expected = false },
        .{ .a = std.math.minInt(ScriptNum), .b = -1, .expected = true },
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input values onto the stack
        try engine.stack.pushInt(tc.a);
        try engine.stack.pushInt(tc.b);

        // Execute OP_LESSTHANOREQUAL
        try opLessThanOrEqual(&engine);

        // Check the result
        const result = try engine.stack.popBool();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_GREATERTHANOREQUAL operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: ScriptNum,
        b: ScriptNum,
        expected: bool,
    }{
        .{ .a = 0, .b = 0, .expected = true },
        .{ .a = 0, .b = 1, .expected = false },
        .{ .a = 1, .b = 0, .expected = true },
        .{ .a = 1, .b = 1, .expected = true },
        .{ .a = -1, .b = 1, .expected = false },
        .{ .a = 42, .b = 42, .expected = true },
        .{ .a = -42, .b = 42, .expected = false },
        .{ .a = std.math.maxInt(ScriptNum), .b = 1, .expected = true },
        .{ .a = std.math.minInt(ScriptNum), .b = -1, .expected = false },
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input values onto the stack
        try engine.stack.pushInt(tc.a);
        try engine.stack.pushInt(tc.b);

        // Execute OP_GREATERTHANOREQUAL
        try opGreaterThanOrEqual(&engine);

        // Check the result
        const result = try engine.stack.popBool();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_MIN operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: ScriptNum,
        b: ScriptNum,
        expected: ScriptNum,
    }{
        .{ .a = 0, .b = 0, .expected = 0 },
        .{ .a = 0, .b = 1, .expected = 0 },
        .{ .a = 1, .b = 0, .expected = 0 },
        .{ .a = 1, .b = 1, .expected = 1 },
        .{ .a = -1, .b = 1, .expected = -1 },
        .{ .a = 42, .b = 42, .expected = 42 },
        .{ .a = -42, .b = 42, .expected = -42 },
        .{ .a = std.math.maxInt(ScriptNum), .b = 1, .expected = 1 },
        .{ .a = std.math.minInt(ScriptNum), .b = -1, .expected = std.math.minInt(ScriptNum) },
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input values onto the stack
        try engine.stack.pushInt(tc.a);
        try engine.stack.pushInt(tc.b);

        // Execute OP_MIN
        try opMin(&engine);

        // Check the result
        const result = try engine.stack.popInt();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_MAX operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: ScriptNum,
        b: ScriptNum,
        expected: ScriptNum,
    }{
        .{ .a = 0, .b = 0, .expected = 0 },
        .{ .a = 0, .b = 1, .expected = 1 },
        .{ .a = 1, .b = 0, .expected = 1 },
        .{ .a = 1, .b = 1, .expected = 1 },
        .{ .a = -1, .b = 1, .expected = 1 },
        .{ .a = 42, .b = 42, .expected = 42 },
        .{ .a = -42, .b = 42, .expected = 42 },
        .{ .a = std.math.maxInt(ScriptNum), .b = 1, .expected = std.math.maxInt(ScriptNum) },
        .{ .a = std.math.minInt(ScriptNum), .b = -1, .expected = -1 },
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input values onto the stack
        try engine.stack.pushInt(tc.a);
        try engine.stack.pushInt(tc.b);

        // Execute OP_MAX
        try opMax(&engine);

        // Check the result
        const result = try engine.stack.popInt();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_WITHIN operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        x: ScriptNum,
        min: ScriptNum,
        max: ScriptNum,
        expected: bool,
    }{
        .{ .x = 0, .min = -1, .max = 1, .expected = true },
        .{ .x = 1, .min = 0, .max = 2, .expected = true },
        .{ .x = -1, .min = -2, .max = 0, .expected = true },
        .{ .x = 2, .min = 0, .max = 1, .expected = false },
        .{ .x = -2, .min = -1, .max = 0, .expected = false },
        .{ .x = 0, .min = 0, .max = 0, .expected = false },
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input values onto the stack
        try engine.stack.pushInt(tc.x);
        try engine.stack.pushInt(tc.min);
        try engine.stack.pushInt(tc.max);

        // Execute OP_WITHIN
        try opWithin(&engine);

        // Check the result
        const result = try engine.stack.popBool();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_NUMEQUALVERIFY operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: ScriptNum,
        b: ScriptNum,
        shouldVerify: bool,
    }{
        .{ .a = 0, .b = 0, .shouldVerify = true },
        .{ .a = 1, .b = 1, .shouldVerify = true },
        .{ .a = -1, .b = -1, .shouldVerify = true },
        .{ .a = std.math.maxInt(ScriptNum), .b = std.math.maxInt(ScriptNum), .shouldVerify = true },
        .{ .a = std.math.minInt(ScriptNum), .b = std.math.minInt(ScriptNum), .shouldVerify = true },
        .{ .a = 0, .b = 1, .shouldVerify = false },
        .{ .a = 1, .b = 0, .shouldVerify = false },
        .{ .a = -1, .b = 1, .shouldVerify = false },
        .{ .a = 42, .b = 43, .shouldVerify = false },
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input values onto the stack
        try engine.stack.pushInt(tc.a);
        try engine.stack.pushInt(tc.b);

        // Execute OP_NUMEQUALVERIFY
        if (tc.shouldVerify) {
            // If it should verify, expect no error
            try opNumEqualVerify(&engine);
            // Ensure the stack is empty after successful verification
            try testing.expectEqual(@as(usize, 0), engine.stack.len());
        } else {
            // If it should not verify, expect VerifyFailed error
            try testing.expectError(StackError.VerifyFailed, opNumEqualVerify(&engine));
            // The stack should be empty even after a failed verification
            try testing.expectEqual(@as(usize, 0), engine.stack.len());
        }
    }
}
