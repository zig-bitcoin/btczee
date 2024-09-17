const std = @import("std");
const testing = std.testing;
const Engine = @import("../engine.zig").Engine;
const Script = @import("../lib.zig").Script;
const ScriptFlags = @import("../lib.zig").ScriptFlags;
const ConditionalStackError = @import("../cond_stack.zig").ConditionalStackError;

/// OP_IF: Executes the following statements if the top stack value is not false
pub fn opIf(engine: *Engine) !void {
    var cond_val: u8 = 0; // Initialize as false
    if (engine.cond_stack.branchExecuting()) {
        if (engine.stack.len() == 0) {
            cond_val = 0; // Treat empty stack as false
        } else {
            const is_truthy = try engine.stack.popBool();
            if (is_truthy) {
                cond_val = 1; // Set to true if top stack value is truthy
            }
        }
    } else {
        cond_val = 2; // Set to skip if current branch is not executing
    }
    // Push the condition value onto the conditional stack
    // 0: false, 1: true, 2: skip
    try engine.cond_stack.push(cond_val);
}

/// OP_NOTIF: Executes the following statements if the top stack value is 0
pub fn opNotIf(engine: *Engine) !void {
    var cond_val: u8 = 1; // true (inverted)
    if (engine.cond_stack.branchExecuting()) {
        const is_truthy = try engine.stack.popBool();
        if (is_truthy) {
            cond_val = 0; // false (inverted)
        }
    } else {
        cond_val = 2; // skip
    }
    try engine.cond_stack.push(cond_val);
}

/// OP_ELSE: Executes the following statements if the previous OP_IF or OP_NOTIF was not executed
pub fn opElse(engine: *Engine) !void {
    try engine.cond_stack.swapCondition();
}

/// OP_ENDIF: Ends an OP_IF, OP_NOTIF, or OP_ELSE block
pub fn opEndIf(engine: *Engine) !void {
    _ = try engine.cond_stack.pop();
}

// Add tests for opIf
test "OP_IF - true condition" {
    const allocator = testing.allocator;

    const script_bytes = [_]u8{ 0x51, 0x63 }; // OP_1 OP_IF
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, ScriptFlags{});
    defer engine.deinit();

    try engine.execute();

    try std.testing.expectEqual(@as(usize, 1), engine.cond_stack.len());
    try std.testing.expect(engine.cond_stack.branchExecuting());
}

test "OP_IF - false condition" {
    const allocator = testing.allocator;

    const script_bytes = [_]u8{ 0x00, 0x63 }; // OP_0 OP_IF
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, ScriptFlags{});
    defer engine.deinit();

    try engine.execute();

    try testing.expectEqual(@as(usize, 1), engine.cond_stack.len());
    try testing.expect(!engine.cond_stack.branchExecuting());
}

test "OP_NOTIF - true condition" {
    const allocator = std.testing.allocator;

    const script_bytes = [_]u8{ 0x51, 0x64 }; // OP_1 OP_NOTIF
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, ScriptFlags{});
    defer engine.deinit();

    try engine.execute();

    try std.testing.expectEqual(@as(usize, 1), engine.cond_stack.len());
    try std.testing.expect(!engine.cond_stack.branchExecuting());
}

test "OP_NOTIF - false condition" {
    const allocator = std.testing.allocator;

    const script_bytes = [_]u8{ 0x00, 0x64 }; // OP_0 OP_NOTIF
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, ScriptFlags{});
    defer engine.deinit();

    try engine.execute();

    try std.testing.expectEqual(@as(usize, 1), engine.cond_stack.len());
    try std.testing.expect(engine.cond_stack.branchExecuting());
}

// Add this test at the end of the file
test "OP_ELSE" {
    const allocator = std.testing.allocator;

    // Test OP_ELSE with matching OP_IF
    {
        const script_bytes = [_]u8{ 0x63, 0x67 }; // OP_IF OP_ELSE
        const script = Script.init(&script_bytes);
        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        try opIf(&engine);
        try opElse(&engine);
        try std.testing.expectEqual(@as(usize, 1), engine.cond_stack.len());
    }

    // Test OP_ELSE with no matching OP_IF
    {
        const script_bytes = [_]u8{0x67}; // OP_ELSE
        const script = Script.init(&script_bytes);
        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        try std.testing.expectError(ConditionalStackError.EmptyConditionalStack, opElse(&engine));
    }
}

// Add this test at the end of the file
test "OP_ENDIF" {
    const allocator = std.testing.allocator;

    // Test OP_ENDIF with matching OP_IF
    {
        const script_bytes = [_]u8{ 0x63, 0x68 }; // OP_IF OP_ENDIF
        const script = Script.init(&script_bytes);
        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        try engine.stack.pushByteArray(&[_]u8{1}); // Push a true value onto the stack
        try opIf(&engine);
        try std.testing.expectEqual(@as(usize, 1), engine.cond_stack.len());

        try opEndIf(&engine);
        try std.testing.expectEqual(@as(usize, 0), engine.cond_stack.len());
    }

    // Test OP_ENDIF with no matching OP_IF
    {
        const script_bytes = [_]u8{0x68}; // OP_ENDIF
        const script = Script.init(&script_bytes);
        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        try std.testing.expectError(ConditionalStackError.EmptyConditionalStack, opEndIf(&engine));
    }
}
