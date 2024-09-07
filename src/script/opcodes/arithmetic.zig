const std = @import("std");
const testing = std.testing;
const Engine = @import("../engine.zig").Engine;
const Script = @import("../lib.zig").Script;
const ScriptFlags = @import("../lib.zig").ScriptFlags;

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
