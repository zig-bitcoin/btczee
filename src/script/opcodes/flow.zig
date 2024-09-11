const std = @import("std");
const testing = std.testing;
const Engine = @import("../engine.zig").Engine;
const Script = @import("../lib.zig").Script;
const ScriptFlags = @import("../lib.zig").ScriptFlags;
const StackError = @import("../stack.zig").StackError;
const ConditionalStackError = @import("../cond_stack.zig").ConditionalStackError;

pub const FlowError = error{
    UnbalancedConditional,
};

/// OP_1ADD: Add 1 to the top stack item
pub fn opIf(engine: *Engine) !void {
    var cond_val: u8 = 0; // false
    if (engine.cond_stack.branchExecuting()) {
        if (engine.stack.len() == 0) {
            cond_val = 0; // treat empty stack as false
        } else {
            const ok = try engine.stack.popBool();
            if (ok) {
                cond_val = 1; // true
            }
        }
    } else {
        cond_val = 2; // skip
    }
    try engine.cond_stack.push(cond_val);
}

pub fn opNotIf(engine: *Engine) !void {
    var cond_val: u8 = 1; // true (inverted)
    if (engine.cond_stack.branchExecuting()) {
        const ok = try engine.stack.popBool();
        if (ok) {
            cond_val = 0; // false (inverted)
        }
    } else {
        cond_val = 2; // skip
    }
    try engine.cond_stack.push(cond_val);
}

pub fn opElse(engine: *Engine) !void {
    if (engine.cond_stack.len() == 0) {
        return FlowError.UnbalancedConditional;
    }

    try engine.cond_stack.swapCondition();
}

pub fn opEndIf(engine: *Engine) !void {
    if (engine.cond_stack.len() == 0) {
        return FlowError.UnbalancedConditional;
    }

    try engine.cond_stack.pop();
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

        try std.testing.expectError(FlowError.UnbalancedConditional, opElse(&engine));
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

        try std.testing.expectError(FlowError.UnbalancedConditional, opEndIf(&engine));
    }
}
