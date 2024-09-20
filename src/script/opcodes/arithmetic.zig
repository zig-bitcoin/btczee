const std = @import("std");
const testing = std.testing;
const Engine = @import("../engine.zig").Engine;
const Script = @import("../lib.zig").Script;
const ScriptNum = @import("../lib.zig").ScriptNum;
const ScriptFlags = @import("../lib.zig").ScriptFlags;
const StackError = @import("../stack.zig").StackError;

/// Add 1 to the top stack item
pub fn op1Add(engine: *Engine) !void {
    const value = try engine.stack.popScriptNum();
    const result = value.addOne();
    try engine.stack.pushScriptNum(result);
}

/// Subtract 1 from the top stack item
pub fn op1Sub(engine: *Engine) !void {
    const value = try engine.stack.popScriptNum();
    const result = value.subOne();
    try engine.stack.pushScriptNum(result);
}

/// Negate the top stack item
pub fn opNegate(engine: *Engine) !void {
    const value = try engine.stack.popScriptNum();
    const result = value.negate();
    try engine.stack.pushScriptNum(result);
}

/// Computes the absolute value of the top stack item
pub fn opAbs(engine: *Engine) !void {
    const value = try engine.stack.popScriptNum();
    const result = value.abs();
    try engine.stack.pushScriptNum(result);
}

/// Pushes 1 if the top stack item is 0, 0 otherwise
///
/// The consensus require we treat those as numbers and not boolean,
/// both while reading and writing.
pub fn opNot(engine: *Engine) !void {
    const value = try engine.stack.popInt();
    const result: u8 = if (value == 0) 1 else 0;
    try engine.stack.pushInt(result);
}

/// Pushes 1 if the top stack item is not 0, 0 otherwise
pub fn op0NotEqual(engine: *Engine) !void {
    const value = try engine.stack.popInt();
    const result: u8 = if (value != 0) 1 else 0;
    try engine.stack.pushInt(result);
}

/// Adds the top two stack items
pub fn opAdd(engine: *Engine) !void {
    const first = try engine.stack.popScriptNum();
    const second = try engine.stack.popScriptNum();
    const result = second.add(first);
    try engine.stack.pushScriptNum(result);
}

/// Subtracts the top stack item from the second top stack item
pub fn opSub(engine: *Engine) !void {
    const first = try engine.stack.popScriptNum();
    const second = try engine.stack.popScriptNum();
    const result = second.sub(first);
    try engine.stack.pushScriptNum(result);
}

/// Pushes 1 if both top two stack items are non-zero, 0 otherwise
pub fn opBoolAnd(engine: *Engine) !void {
    const first = try engine.stack.popInt();
    const second = try engine.stack.popInt();
    const result: u8 = @intFromBool(first != 0 and second != 0);
    try engine.stack.pushInt(result);
}

/// Pushes 1 if either of the top two stack items is non-zero, 0 otherwise
pub fn opBoolOr(engine: *Engine) !void {
    const first = try engine.stack.popInt();
    const second = try engine.stack.popInt();
    const result: u8 = @intFromBool(first != 0 or second != 0);
    try engine.stack.pushInt(result);
}

/// Pushes 1 if the top two stack items are equal, 0 otherwise
pub fn opNumEqual(engine: *Engine) !void {
    const b = try engine.stack.popInt();
    const a = try engine.stack.popInt();
    const result: u8 = @intFromBool(a == b);
    try engine.stack.pushInt(result);
}

/// Helper function to verify the top stack item is true
pub fn abstractVerify(engine: *Engine) !void {
    const verified = try engine.stack.popBool();
    if (!verified) {
        return StackError.VerifyFailed;
    }
}

/// Combines opNumEqual and abstractVerify operations
pub fn opNumEqualVerify(engine: *Engine) !void {
    try opNumEqual(engine);
    try abstractVerify(engine);
}

/// Pushes 1 if the top two stack items are not equal, 0 otherwise
pub fn opNumNotEqual(engine: *Engine) !void {
    const b = try engine.stack.popInt();
    const a = try engine.stack.popInt();
    const result: u8 = @intFromBool(a != b);
    try engine.stack.pushInt(result);
}

/// Pushes 1 if the second top stack item is less than the top stack item, 0 otherwise
pub fn opLessThan(engine: *Engine) !void {
    const b = try engine.stack.popInt();
    const a = try engine.stack.popInt();
    const result: u8 = @intFromBool(a < b);
    try engine.stack.pushInt(result);
}

/// Pushes 1 if the second top stack item is greater than the top stack item, 0 otherwise
pub fn opGreaterThan(engine: *Engine) !void {
    const b = try engine.stack.popInt();
    const a = try engine.stack.popInt();
    const result = @intFromBool(a > b);
    try engine.stack.pushInt(result);
}

/// Pushes 1 if the second top stack item is less than or equal to the top stack item, 0 otherwise
pub fn opLessThanOrEqual(engine: *Engine) !void {
    const b = try engine.stack.popInt();
    const a = try engine.stack.popInt();
    const result = @intFromBool(a <= b);
    try engine.stack.pushInt(result);
}

/// Pushes 1 if the second top stack item is greater than or equal to the top stack item, 0 otherwise
pub fn opGreaterThanOrEqual(engine: *Engine) !void {
    const b = try engine.stack.popInt();
    const a = try engine.stack.popInt();
    const result = @intFromBool(a >= b);
    try engine.stack.pushInt(result);
}

/// Pushes the minimum of the top two stack items
pub fn opMin(engine: *Engine) !void {
    const b = try engine.stack.popInt();
    const a = try engine.stack.popInt();
    const result = if (a < b) a else b;
    try engine.stack.pushInt(result);
}

/// Pushes the maximum of the top two stack items
pub fn opMax(engine: *Engine) !void {
    const b = try engine.stack.popInt();
    const a = try engine.stack.popInt();
    const result = if (a > b) a else b;
    try engine.stack.pushInt(result);
}

/// Pushes true if x is within the range [min, max], false otherwise
pub fn opWithin(engine: *Engine) !void {
    const max = try engine.stack.popInt();
    const min = try engine.stack.popInt();
    const x = try engine.stack.popInt();
    const result = @intFromBool(min <= x and x < max);
    try engine.stack.pushInt(result);
}

test "OP_1ADD operation" {
    const allocator = testing.allocator;

    // Test cases
    const normalTestCases = [_]struct {
        input: i32,
        expected: i32,
    }{
        .{ .input = 0, .expected = 1 },
        .{ .input = -1, .expected = 0 },
        .{ .input = 42, .expected = 43 },
        .{ .input = -100, .expected = -99 },
        .{ .input = ScriptNum.MIN, .expected = ScriptNum.MIN + 1 },
    };
    const overflowTestCases = [_]struct {
        input: i32,
        expected: []const u8,
    }{
        .{ .input = ScriptNum.MAX, .expected = &[_]u8{ 0x0, 0x0, 0x0, 0x80, 0x0 } },
    };

    for (normalTestCases) |tc| {
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
        try testing.expectEqual(0, engine.stack.len());
    }
    for (overflowTestCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input values onto the stack
        try engine.stack.pushInt(tc.input);

        // Execute OP_1ADD
        try op1Add(&engine);

        // Check the result
        const result = try engine.stack.pop();
        defer engine.allocator.free(result);
        try testing.expect(std.mem.eql(u8, tc.expected, result));

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(0, engine.stack.len());
    }
}

test "OP_1SUB operation" {
    const allocator = testing.allocator;

    // Test cases
    const normalTestCases = [_]struct {
        input: i32,
        expected: i32,
    }{
        .{ .input = 0, .expected = -1 },
        .{ .input = 1, .expected = 0 },
        .{ .input = -1, .expected = -2 },
        .{ .input = 42, .expected = 41 },
        .{ .input = -100, .expected = -101 },
        .{ .input = ScriptNum.MAX, .expected = ScriptNum.MAX - 1 },
    };
    const overflowTestCases = [_]struct {
        input: i32,
        expected: []const u8,
    }{
        .{ .input = ScriptNum.MIN, .expected = &[_]u8{ 0x0, 0x0, 0x0, 0x80, 0x80 } }, // Overflow case
    };

    for (normalTestCases) |tc| {
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
        try testing.expectEqual(0, engine.stack.len());
    }
    for (overflowTestCases) |tc| {
        // Create a dummy script (content doesn't matter for this test)
        const script_bytes = [_]u8{0x00};
        const script = Script.init(&script_bytes);

        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        // Push the input values onto the stack
        try engine.stack.pushInt(tc.input);

        // Execute OP_1SUB
        try op1Sub(&engine);

        // Check the result
        const result = try engine.stack.pop();
        defer engine.allocator.free(result);
        try testing.expect(std.mem.eql(u8, tc.expected, result));

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(0, engine.stack.len());
    }
}

test "OP_NEGATE operation" {
    const allocator = testing.allocator;

    // Test cases
    const normalTestCases = [_]struct {
        input: i32,
        expected: i32,
    }{
        .{ .input = 0, .expected = 0 },
        .{ .input = 1, .expected = -1 },
        .{ .input = -1, .expected = 1 },
        .{ .input = 42, .expected = -42 },
        .{ .input = -42, .expected = 42 },
        .{ .input = ScriptNum.MAX, .expected = ScriptNum.MIN },
        .{ .input = ScriptNum.MIN, .expected = ScriptNum.MAX },
    };

    for (normalTestCases) |tc| {
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
        try testing.expectEqual(0, engine.stack.len());
    }
}

test "OP_ABS operation" {
    const allocator = testing.allocator;

    // Test cases
    const normalTestCases = [_]struct {
        input: i32,
        expected: i32,
    }{
        .{ .input = 0, .expected = 0 },
        .{ .input = 1, .expected = 1 },
        .{ .input = -1, .expected = 1 },
        .{ .input = 42, .expected = 42 },
        .{ .input = -42, .expected = 42 },
        .{ .input = ScriptNum.MAX, .expected = ScriptNum.MAX },
        .{ .input = ScriptNum.MIN, .expected = ScriptNum.MAX },
    };
    for (normalTestCases) |tc| {
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
        try testing.expectEqual(0, engine.stack.len());
    }
}

test "OP_NOT operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        input: i32,
        expected: bool,
    }{
        .{ .input = 0, .expected = true },
        .{ .input = 1, .expected = false },
        .{ .input = -1, .expected = false },
        .{ .input = 42, .expected = false },
        .{ .input = -42, .expected = false },
        .{ .input = ScriptNum.MAX, .expected = false },
        .{ .input = ScriptNum.MIN, .expected = false }, // Special case
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
        try testing.expectEqual(0, engine.stack.len());
    }
}

test "OP_0NOTEQUAL operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        input: i32,
        expected: i32,
    }{
        .{ .input = 0, .expected = 0 },
        .{ .input = 1, .expected = 1 },
        .{ .input = -1, .expected = 1 },
        .{ .input = 42, .expected = 1 },
        .{ .input = -42, .expected = 1 },
        .{ .input = ScriptNum.MAX, .expected = 1 },
        .{ .input = ScriptNum.MIN, .expected = 1 }, // Special case
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
        try testing.expectEqual(0, engine.stack.len());
    }
}

test "OP_ADD operation" {
    const allocator = testing.allocator;

    // Test cases
    const normalTestCases = [_]struct {
        a: i32,
        b: i32,
        expected: i32,
    }{
        .{ .a = 0, .b = 0, .expected = 0 },
        .{ .a = 0, .b = 1, .expected = 1 },
        .{ .a = 1, .b = 0, .expected = 1 },
        .{ .a = 1, .b = 1, .expected = 2 },
        .{ .a = -1, .b = 1, .expected = 0 },
        .{ .a = 42, .b = 42, .expected = 84 },
        .{ .a = -42, .b = 42, .expected = 0 },
    };
    const overflowTestCases = [_]struct {
        a: i32,
        b: i32,
        expected: []const u8,
    }{
        .{ .a = ScriptNum.MAX, .b = 1, .expected = &[_]u8{ 0x0, 0x0, 0x0, 0x80, 0x0 } },
        .{ .a = ScriptNum.MIN, .b = -1, .expected = &[_]u8{ 0x0, 0x0, 0x0, 0x80, 0x80 } },
        .{ .a = ScriptNum.MAX, .b = ScriptNum.MAX, .expected = &[_]u8{ 0xfe, 0xff, 0xff, 0xff, 0x0 } },
        .{ .a = ScriptNum.MIN, .b = ScriptNum.MIN, .expected = &[_]u8{ 0xfe, 0xff, 0xff, 0xff, 0x80 } },
    };

    for (normalTestCases) |tc| {
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
        try testing.expectEqual(0, engine.stack.len());
    }
    for (overflowTestCases) |tc| {
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
        const result = try engine.stack.pop();
        defer engine.allocator.free(result);
        try testing.expect(std.mem.eql(u8, tc.expected, result));

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(0, engine.stack.len());
    }
}

test "OP_SUB operation" {
    const allocator = testing.allocator;

    // Test cases
    const normalTestCases = [_]struct {
        a: i32,
        b: i32,
        expected: i32,
    }{
        .{ .a = 0, .b = 0, .expected = 0 },
        .{ .a = 0, .b = 1, .expected = -1 },
        .{ .a = 1, .b = 0, .expected = 1 },
        .{ .a = 1, .b = 1, .expected = 0 },
        .{ .a = -1, .b = 1, .expected = -2 },
        .{ .a = 42, .b = 42, .expected = 0 },
        .{ .a = -42, .b = 42, .expected = -84 },
    };
    // Those will overflow, meaning the cannot be read back as numbers, but can still successfully be pushed on the stack
    const overflowTestCases = [_]struct {
        a: i32,
        b: i32,
        expected: []const u8,
    }{
        .{ .a = ScriptNum.MAX, .b = -1, .expected = &[_]u8{ 0x0, 0x0, 0x0, 0x80, 0x0 } },
        .{ .a = ScriptNum.MIN, .b = 1, .expected = &[_]u8{ 0x0, 0x0, 0x0, 0x80, 0x80 } },
        .{ .a = ScriptNum.MIN, .b = ScriptNum.MAX, .expected = &[_]u8{ 0xfe, 0xff, 0xff, 0xff, 0x80 } },
        .{ .a = ScriptNum.MAX, .b = ScriptNum.MIN, .expected = &[_]u8{ 0xfe, 0xff, 0xff, 0xff, 0x00 } },
    };

    for (normalTestCases) |tc| {
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
        try testing.expectEqual(0, engine.stack.len());
    }
    for (overflowTestCases) |tc| {
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
        const result = try engine.stack.pop();
        defer engine.allocator.free(result);
        try testing.expect(std.mem.eql(u8, tc.expected, result));

        // Ensure the stack is empty after popping the result
        try testing.expectEqual(0, engine.stack.len());
    }
}

test "OP_BOOLOR operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: i32,
        b: i32,
        expected: bool,
    }{
        .{ .a = 0, .b = 0, .expected = false },
        .{ .a = 0, .b = 1, .expected = true },
        .{ .a = 1, .b = 0, .expected = true },
        .{ .a = 1, .b = 1, .expected = true },
        .{ .a = -1, .b = 1, .expected = true },
        .{ .a = 42, .b = 42, .expected = true },
        .{ .a = -42, .b = 42, .expected = true },
        .{ .a = ScriptNum.MAX, .b = 1, .expected = true },
        .{ .a = ScriptNum.MIN, .b = -1, .expected = true },
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
        try testing.expectEqual(0, engine.stack.len());
    }
}

test "OP_NUMEQUAL operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: i32,
        b: i32,
        expected: bool,
    }{
        .{ .a = 0, .b = 0, .expected = true },
        .{ .a = 0, .b = 1, .expected = false },
        .{ .a = 1, .b = 0, .expected = false },
        .{ .a = 1, .b = 1, .expected = true },
        .{ .a = -1, .b = 1, .expected = false },
        .{ .a = 42, .b = 42, .expected = true },
        .{ .a = -42, .b = 42, .expected = false },
        .{ .a = ScriptNum.MAX, .b = 1, .expected = false },
        .{ .a = ScriptNum.MIN, .b = -1, .expected = false },
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
        try testing.expectEqual(0, engine.stack.len());
    }
}

test "OP_NUMNOTEQUAL operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: i32,
        b: i32,
        expected: bool,
    }{
        .{ .a = 0, .b = 0, .expected = false },
        .{ .a = 0, .b = 1, .expected = true },
        .{ .a = 1, .b = 0, .expected = true },
        .{ .a = 1, .b = 1, .expected = false },
        .{ .a = -1, .b = 1, .expected = true },
        .{ .a = 42, .b = 42, .expected = false },
        .{ .a = -42, .b = 42, .expected = true },
        .{ .a = ScriptNum.MAX, .b = 1, .expected = true },
        .{ .a = ScriptNum.MIN, .b = -1, .expected = true },
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
        try testing.expectEqual(0, engine.stack.len());
    }
}

test "OP_LESSTHAN operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: i32,
        b: i32,
        expected: bool,
    }{
        .{ .a = 0, .b = 0, .expected = false },
        .{ .a = 0, .b = 1, .expected = true },
        .{ .a = 1, .b = 0, .expected = false },
        .{ .a = 1, .b = 1, .expected = false },
        .{ .a = -1, .b = 1, .expected = true },
        .{ .a = 42, .b = 42, .expected = false },
        .{ .a = -42, .b = 42, .expected = true },
        .{ .a = ScriptNum.MAX, .b = 1, .expected = false },
        .{ .a = ScriptNum.MIN, .b = -1, .expected = true },
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
        try testing.expectEqual(0, engine.stack.len());
    }
}

test "OP_GREATERTHAN operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: i32,
        b: i32,
        expected: bool,
    }{
        .{ .a = 0, .b = 0, .expected = false },
        .{ .a = 0, .b = 1, .expected = false },
        .{ .a = 1, .b = 0, .expected = true },
        .{ .a = 1, .b = 1, .expected = false },
        .{ .a = -1, .b = 1, .expected = false },
        .{ .a = 42, .b = 42, .expected = false },
        .{ .a = -42, .b = 42, .expected = false },
        .{ .a = ScriptNum.MAX, .b = 1, .expected = true },
        .{ .a = ScriptNum.MIN, .b = -1, .expected = false },
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
        try testing.expectEqual(0, engine.stack.len());
    }
}

test "OP_LESSTHANOREQUAL operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: i32,
        b: i32,
        expected: bool,
    }{
        .{ .a = 0, .b = 0, .expected = true },
        .{ .a = 0, .b = 1, .expected = true },
        .{ .a = 1, .b = 0, .expected = false },
        .{ .a = 1, .b = 1, .expected = true },
        .{ .a = -1, .b = 1, .expected = true },
        .{ .a = 42, .b = 42, .expected = true },
        .{ .a = -42, .b = 42, .expected = true },
        .{ .a = ScriptNum.MAX, .b = 1, .expected = false },
        .{ .a = ScriptNum.MIN, .b = -1, .expected = true },
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
        try testing.expectEqual(0, engine.stack.len());
    }
}

test "OP_GREATERTHANOREQUAL operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: i32,
        b: i32,
        expected: bool,
    }{
        .{ .a = 0, .b = 0, .expected = true },
        .{ .a = 0, .b = 1, .expected = false },
        .{ .a = 1, .b = 0, .expected = true },
        .{ .a = 1, .b = 1, .expected = true },
        .{ .a = -1, .b = 1, .expected = false },
        .{ .a = 42, .b = 42, .expected = true },
        .{ .a = -42, .b = 42, .expected = false },
        .{ .a = ScriptNum.MAX, .b = 1, .expected = true },
        .{ .a = ScriptNum.MIN, .b = -1, .expected = false },
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
        try testing.expectEqual(0, engine.stack.len());
    }
}

test "OP_MIN operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: i32,
        b: i32,
        expected: i32,
    }{
        .{ .a = 0, .b = 0, .expected = 0 },
        .{ .a = 0, .b = 1, .expected = 0 },
        .{ .a = 1, .b = 0, .expected = 0 },
        .{ .a = 1, .b = 1, .expected = 1 },
        .{ .a = -1, .b = 1, .expected = -1 },
        .{ .a = 42, .b = 42, .expected = 42 },
        .{ .a = -42, .b = 42, .expected = -42 },
        .{ .a = ScriptNum.MAX, .b = 1, .expected = 1 },
        .{ .a = ScriptNum.MIN, .b = -1, .expected = ScriptNum.MIN },
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
        try testing.expectEqual(0, engine.stack.len());
    }
}

test "OP_MAX operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: i32,
        b: i32,
        expected: i32,
    }{
        .{ .a = 0, .b = 0, .expected = 0 },
        .{ .a = 0, .b = 1, .expected = 1 },
        .{ .a = 1, .b = 0, .expected = 1 },
        .{ .a = 1, .b = 1, .expected = 1 },
        .{ .a = -1, .b = 1, .expected = 1 },
        .{ .a = 42, .b = 42, .expected = 42 },
        .{ .a = -42, .b = 42, .expected = 42 },
        .{ .a = ScriptNum.MAX, .b = 1, .expected = ScriptNum.MAX },
        .{ .a = ScriptNum.MIN, .b = -1, .expected = -1 },
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
        try testing.expectEqual(0, engine.stack.len());
    }
}

test "OP_WITHIN operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        x: i32,
        min: i32,
        max: i32,
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
        try testing.expectEqual(0, engine.stack.len());
    }
}

test "OP_NUMEQUALVERIFY operation" {
    const allocator = testing.allocator;

    // Test cases
    const testCases = [_]struct {
        a: i32,
        b: i32,
        shouldVerify: bool,
    }{
        .{ .a = 0, .b = 0, .shouldVerify = true },
        .{ .a = 1, .b = 1, .shouldVerify = true },
        .{ .a = -1, .b = -1, .shouldVerify = true },
        .{ .a = ScriptNum.MAX, .b = ScriptNum.MAX, .shouldVerify = true },
        .{ .a = ScriptNum.MIN, .b = ScriptNum.MIN, .shouldVerify = true },
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
            try testing.expectEqual(0, engine.stack.len());
        } else {
            // If it should not verify, expect VerifyFailed error
            try testing.expectError(StackError.VerifyFailed, opNumEqualVerify(&engine));
            // The stack should be empty even after a failed verification
            try testing.expectEqual(0, engine.stack.len());
        }
    }
}
