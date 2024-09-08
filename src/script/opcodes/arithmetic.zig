const std = @import("std");
const testing = std.testing;
const Engine = @import("../engine.zig").Engine;
const Script = @import("../lib.zig").Script;
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
    const result = if (value == std.math.minInt(i64))
        std.math.minInt(i64)
    else
        -value;
    try self.stack.pushInt(result);
}

pub fn opAbs(engine: *Engine) !void {
    const value = try engine.stack.popInt();
    const result = if (value < 0) -value else value;
    try engine.stack.pushInt(result);
}

pub fn opNot(self: *Engine) !void {
    const value = try self.stack.popInt();
    const result: i64 = if (value == 0) 1 else 0;
    try self.stack.pushInt(result);
}

pub fn op0NotEqual(self: *Engine) !void {
    const value = try self.stack.popInt();
    const result: i64 = if (value == 0) 0 else 1;
    try self.stack.pushInt(result);
}

pub fn opAdd(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result = @addWithOverflow(a, b);
    try self.stack.pushInt(result[0]);
}

pub fn opSub(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result = @subWithOverflow(a, b);
    try self.stack.pushInt(result[0]);
}

pub fn opBoolAnd(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result: i64 = if ((a != 0) and (b != 0)) 1 else 0;
    try self.stack.pushInt(result);
}

pub fn opBoolOr(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result: i64 = if ((a != 0) or (b != 0)) 1 else 0;
    try self.stack.pushInt(result);
}

pub fn opNumEqual(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result = if (a == b) true else false;
    try self.stack.pushBool(result);
}

pub fn abstractVerify(self: *Engine) !void {
    const verified = try self.stack.popBool();
    if (!verified) {
        return StackError.VerifyFailed;
    }
}

pub fn opNumEqualVerify(self: *Engine) !void {
    try opNumEqual(self);
    try abstractVerify(self);
}


pub fn opNumNotEqual(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result: i64 = if (a != b) 1 else 0;
    try self.stack.pushInt(result);
}

pub fn opLessThan(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result: i64 = if (a < b) 1 else 0;
    try self.stack.pushInt(result);
}

pub fn opGreaterThan(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result: i64 = if (a > b) 1 else 0;
    try self.stack.pushInt(result);
}

pub fn opLessThanOrEqual(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result: i64 = if (a <= b) 1 else 0;
    try self.stack.pushInt(result);
}

pub fn opGreaterThanOrEqual(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result: i64 = if (a >= b) 1 else 0;
    try self.stack.pushInt(result);
}

pub fn opMin(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result = if (a < b) a else b;
    try self.stack.pushInt(result);
}

pub fn opMax(self: *Engine) !void {
    const b = try self.stack.popInt();
    const a = try self.stack.popInt();
    const result = if (a > b) a else b;
    try self.stack.pushInt(result);
}

pub fn opWithin(self: *Engine) !void {
    const max = try self.stack.popInt();
    const min = try self.stack.popInt();
    const x = try self.stack.popInt();
    const result: i64 = if ((min <= x) and (x < max)) 1 else 0;
    try self.stack.pushInt(result);
}

test "OP_1ADD operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        input: i64,
        expected: i64,
    }{
        .{ .input = 0, .expected = 1 },
        .{ .input = -1, .expected = 0 },
        .{ .input = 42, .expected = 43 },
        .{ .input = -100, .expected = -99 },
        .{ .input = std.math.maxInt(i64), .expected = std.math.minInt(i64) }, // Overflow case
        .{ .input = std.math.minInt(i64), .expected = std.math.minInt(i64) + 1 },
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
        input: i64,
        expected: i64,
    }{
        .{ .input = 0, .expected = -1 },
        .{ .input = 1, .expected = 0 },
        .{ .input = -1, .expected = -2 },
        .{ .input = 42, .expected = 41 },
        .{ .input = -100, .expected = -101 },
        .{ .input = std.math.maxInt(i64), .expected = std.math.maxInt(i64) - 1 },
        .{ .input = std.math.minInt(i64), .expected = std.math.maxInt(i64) }, // Underflow case
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
        input: i64,
        expected: i64,
    }{
        .{ .input = 0, .expected = 0 },
        .{ .input = 1, .expected = -1 },
        .{ .input = -1, .expected = 1 },
        .{ .input = 42, .expected = -42 },
        .{ .input = -42, .expected = 42 },
        .{ .input = std.math.maxInt(i64), .expected = -std.math.maxInt(i64) },
        .{ .input = std.math.minInt(i64), .expected = std.math.minInt(i64) }, // Special case
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
        input: i64,
        expected: i64,
    }{
        .{ .input = 1, .expected = 1 },
        .{ .input = -1, .expected = 1 },
        .{ .input = 0, .expected = 0 },
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
        input: i64,
        expected: i64,
    }{
        .{ .input = 0, .expected = 1 },
        .{ .input = 1, .expected = 0 },
        .{ .input = -1, .expected = 0 },
        .{ .input = 42, .expected = 0 },
        .{ .input = -42, .expected = 0 },
        .{ .input = std.math.maxInt(i64), .expected = 0 },
        .{ .input = std.math.minInt(i64), .expected = 0 },
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
        const result = try engine.stack.popInt();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_0NOTEQUAL operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        input: i64,
        expected: i64,
    }{
        .{ .input = 0, .expected = 0 },
        .{ .input = 1, .expected = 1 },
        .{ .input = -1, .expected = 1 },
        .{ .input = 42, .expected = 1 },
        .{ .input = -42, .expected = 1 },
        .{ .input = std.math.maxInt(i64), .expected = 1 },
        .{ .input = std.math.minInt(i64), .expected = 1 },
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
        a: i64,
        b: i64,
        expected: i64,
    }{
        .{ .a = 0, .b = 0, .expected = 0 },
        .{ .a = 0, .b = 1, .expected = 1 },
        .{ .a = 1, .b = 0, .expected = 1 },
        .{ .a = 1, .b = 1, .expected = 2 },
        .{ .a = -1, .b = 1, .expected = 0 },
        .{ .a = 42, .b = 42, .expected = 84 },
        .{ .a = -42, .b = 42, .expected = 0 },
        .{ .a = std.math.maxInt(i64), .b = 1, .expected = std.math.minInt(i64) },
        .{ .a = std.math.minInt(i64), .b = -1, .expected = std.math.maxInt(i64) },
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
        a: i64,
        b: i64,
        expected: i64,
    }{
        .{ .a = 0, .b = 0, .expected = 0 },
        .{ .a = 0, .b = 1, .expected = -1 },
        .{ .a = 1, .b = 0, .expected = 1 },
        .{ .a = 1, .b = 1, .expected = 0 },
        .{ .a = -1, .b = 1, .expected = -2 },
        .{ .a = 42, .b = 42, .expected = 0 },
        .{ .a = -42, .b = 42, .expected = -84 },
        .{ .a = std.math.maxInt(i64), .b = -1, .expected = std.math.minInt(i64) },
        .{ .a = std.math.minInt(i64), .b = 1, .expected = std.math.maxInt(i64) },
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

test "OP_BOOLAND operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: i64,
        b: i64,
        expected: i64,
    }{
        .{ .a = 0, .b = 0, .expected = 0 },
        .{ .a = 0, .b = 1, .expected = 0 },
        .{ .a = 1, .b = 0, .expected = 0 },
        .{ .a = 1, .b = 1, .expected = 1 },
        .{ .a = -1, .b = 1, .expected = 1 },
        .{ .a = 42, .b = 42, .expected = 1 },
        .{ .a = -42, .b = 42, .expected = 1 },
        .{ .a = std.math.maxInt(i64), .b = 1, .expected = 1 },
        .{ .a = std.math.minInt(i64), .b = -1, .expected = 1 },
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

        // Execute OP_BOOLAND
        try opBoolAnd(&engine);

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
        a: i64,
        b: i64,
        expected: i64,
    }{
        .{ .a = 0, .b = 0, .expected = 0 },
        .{ .a = 0, .b = 1, .expected = 1 },
        .{ .a = 1, .b = 0, .expected = 1 },
        .{ .a = 1, .b = 1, .expected = 1 },
        .{ .a = -1, .b = 1, .expected = 1 },
        .{ .a = 42, .b = 42, .expected = 1 },
        .{ .a = -42, .b = 42, .expected = 1 },
        .{ .a = std.math.maxInt(i64), .b = 1, .expected = 1 },
        .{ .a = std.math.minInt(i64), .b = -1, .expected = 1 },
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
        const result = try engine.stack.popInt();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

// ... existing code ...
test "OP_NUMEQUAL operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: i64,
        b: i64,
        expected: bool, // Change type to bool
    }{
        .{ .a = 0, .b = 0, .expected = true },
        .{ .a = 0, .b = 1, .expected = false },
        .{ .a = 1, .b = 0, .expected = false },
        .{ .a = 1, .b = 1, .expected = true },
        .{ .a = -1, .b = 1, .expected = false },
        .{ .a = 42, .b = 42, .expected = true },
        .{ .a = -42, .b = 42, .expected = false },
        .{ .a = std.math.maxInt(i64), .b = 1, .expected = false },
        .{ .a = std.math.minInt(i64), .b = -1, .expected = false },
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
        try testing.expectEqual(tc.expected, result); // No change needed here

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

//test for the others skipping OP_NUMEQUALVERIFY

test "OP_NUMNOTEQUAL operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: i64,
        b: i64,
        expected: i64,
    }{
        .{ .a = 0, .b = 0, .expected = 0 },
        .{ .a = 0, .b = 1, .expected = 1 },
        .{ .a = 1, .b = 0, .expected = 1 },
        .{ .a = 1, .b = 1, .expected = 0 },
        .{ .a = -1, .b = 1, .expected = 1 },
        .{ .a = 42, .b = 42, .expected = 0 },
        .{ .a = -42, .b = 42, .expected = 1 },
        .{ .a = std.math.maxInt(i64), .b = 1, .expected = 1 },
        .{ .a = std.math.minInt(i64), .b = -1, .expected = 1 },
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
        const result = try engine.stack.popInt();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_LESSTHAN operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: i64,
        b: i64,
        expected: i64,
    }{
        .{ .a = 0, .b = 0, .expected = 0 },
        .{ .a = 0, .b = 1, .expected = 1 },
        .{ .a = 1, .b = 0, .expected = 0 },
        .{ .a = 1, .b = 1, .expected = 0 },
        .{ .a = -1, .b = 1, .expected = 1 },
        .{ .a = 42, .b = 42, .expected = 0 },
        .{ .a = -42, .b = 42, .expected = 1 },
        .{ .a = std.math.maxInt(i64), .b = 1, .expected = 0 },
        .{ .a = std.math.minInt(i64), .b = -1, .expected = 1 },
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
        const result = try engine.stack.popInt();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_GREATERTHAN operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: i64,
        b: i64,
        expected: i64,
    }{
        .{ .a = 0, .b = 0, .expected = 0 },
        .{ .a = 0, .b = 1, .expected = 0 },
        .{ .a = 1, .b = 0, .expected = 1 },
        .{ .a = 1, .b = 1, .expected = 0 },
        .{ .a = -1, .b = 1, .expected = 0 },
        .{ .a = 42, .b = 42, .expected = 0 },
        .{ .a = -42, .b = 42, .expected = 0 },
        .{ .a = std.math.maxInt(i64), .b = 1, .expected = 1 },
        .{ .a = std.math.minInt(i64), .b = -1, .expected = 0 },
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
        const result = try engine.stack.popInt();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_LESSTHANOREQUAL operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: i64,
        b: i64,
        expected: i64,
    }{
        .{ .a = 0, .b = 0, .expected = 1 },
        .{ .a = 0, .b = 1, .expected = 1 },
        .{ .a = 1, .b = 0, .expected = 0 },
        .{ .a = 1, .b = 1, .expected = 1 },
        .{ .a = -1, .b = 1, .expected = 1 },
        .{ .a = 42, .b = 42, .expected = 1 },
        .{ .a = -42, .b = 42, .expected = 1 },
        .{ .a = std.math.maxInt(i64), .b = 1, .expected = 0 },
        .{ .a = std.math.minInt(i64), .b = -1, .expected = 1 },
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
        const result = try engine.stack.popInt();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(@as(usize, 0), engine.stack.len());
    }
}

test "OP_MIN operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: i64,
        b: i64,
        expected: i64,
    }{
        .{ .a = 0, .b = 0, .expected = 0 },
        .{ .a = 0, .b = 1, .expected = 0 },
        .{ .a = 1, .b = 0, .expected = 0 },
        .{ .a = 1, .b = 1, .expected = 1 },
        .{ .a = -1, .b = 1, .expected = -1 },
        .{ .a = 42, .b = 42, .expected = 42 },
        .{ .a = -42, .b = 42, .expected = -42 },
        .{ .a = std.math.maxInt(i64), .b = 1, .expected = 1 },
        .{ .a = std.math.minInt(i64), .b = -1, .expected = std.math.minInt(i64) },
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
        a: i64,
        b: i64,
        expected: i64,
    }{
        .{ .a = 0, .b = 0, .expected = 0 },
        .{ .a = 0, .b = 1, .expected = 1 },
        .{ .a = 1, .b = 0, .expected = 1 },
        .{ .a = 1, .b = 1, .expected = 1 },
        .{ .a = -1, .b = 1, .expected = 1 },
        .{ .a = 42, .b = 42, .expected = 42 },
        .{ .a = -42, .b = 42, .expected = 42 },
        .{ .a = std.math.maxInt(i64), .b = 1, .expected = std.math.maxInt(i64) },
        .{ .a = std.math.minInt(i64), .b = -1, .expected = -1 },
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

//write test for OP_WITHIN
test "OP_WITHIN operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        min: i64,
        max: i64,
        x: i64,
        expected: i64,
    }{
        .{ .min = 0, .max = 0, .x = 0, .expected = 1 },
        .{ .min = 0, .max = 1, .x = 0, .expected = 1 },
        .{ .min = 0, .max = 1, .x = 1, .expected = 0 },
        .{ .min = 1, .max = 0, .x = 0, .expected = 0 },
        .{ .min = 1, .max = 1, .x = 1, .expected = 1 },
        .{ .min = -1, .max = 1, .x = 0, .expected = 1 },
        .{ .min = 42, .max = 42, .x = 42, .expected = 0 },
        .{ .min = -42, .max = 42, .x = 42, .expected = 0 },
        .{ .min = std.math.maxInt(i64), .max = 1, .x = 1, .expected = 0 },
        .{ .min = std.math.minInt(i64), .max = -1, .x = -1, .expected = 1 },
    };

    for (testCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input values onto the stack
        try engine.stack.pushInt(tc.min);
        try engine.stack.pushInt(tc.max);
        try engine.stack.pushInt(tc.x);

        // Execute OP_WITHIN
        try opWithin(&engine);

        // Check the result
        const result = try engine.stack.popInt();
        try testing.expectEqual(tc.expected, result);

        // Ensure the stack is empty after popping the result
        try testing
            .expectEqual(@as(usize, 0), engine.stack.len());
    }
}