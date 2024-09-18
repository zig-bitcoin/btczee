const std = @import("std");
const testing = std.testing;
const Engine = @import("../engine.zig").Engine;
const Script = @import("../lib.zig").Script;
const ScriptFlags = @import("../lib.zig").ScriptFlags;
const ConditionalStackError = @import("../cond_stack.zig").ConditionalStackError;

/// OP_IF: Conditionally executes the following statements
/// If the current branch is executing:
///   - If the stack is empty, treat as false
///   - Otherwise, pop the top stack value and use it as the condition
/// If the current branch is not executing, mark as skip
/// Pushes the resulting condition (0: false, 1: true, 2: skip) onto the conditional stack
pub fn opIf(engine: *Engine) !void {
    var cond_val: u8 = 0; // Initialize as false
    if (engine.cond_stack.isBranchExecuting()) {
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

/// OP_NOTIF: Similar to OP_IF, but inverts the condition
/// If the current branch is executing:
///   - Pop the top stack value and invert its truthiness
/// If the current branch is not executing, mark as skip
/// Pushes the resulting condition (0: false, 1: true, 2: skip) onto the conditional stack
pub fn opNotIf(engine: *Engine) !void {
    var cond_val: u8 = 1; // true (inverted)
    if (engine.cond_stack.isBranchExecuting()) {
        const is_truthy = try engine.stack.popBool();
        if (is_truthy) {
            cond_val = 0; // false (inverted)
        }
    } else {
        cond_val = 2; // skip
    }
    try engine.cond_stack.push(cond_val);
}

/// OP_ELSE: Toggles the execution state of the current conditional block
/// If the conditional stack is empty, returns an error
/// Otherwise, flips the condition on top of the stack:
///   - 0 (false) becomes 1 (true)
///   - 1 (true) becomes 0 (false)
///   - 2 (skip) remains unchanged
/// Returns an error for any other condition value
pub fn opElse(engine: *Engine) !void {
    if (engine.cond_stack.len() == 0) {
        return ConditionalStackError.EmptyConditionalStack;
    }

    const cond_idx = engine.cond_stack.len() - 1;
    switch (engine.cond_stack.stack.items[cond_idx]) {
        0 => engine.cond_stack.stack.items[cond_idx] = 1,
        1 => engine.cond_stack.stack.items[cond_idx] = 0,
        2 => {}, // Leave unchanged
        else => return ConditionalStackError.InvalidCondition,
    }
}

/// OP_ENDIF: Terminates an OP_IF, OP_NOTIF, or OP_ELSE block
/// Removes the top item from the conditional stack
/// Returns an error if the conditional stack is empty
pub fn opEndIf(engine: *Engine) !void {
    _ = try engine.cond_stack.pop();
}

// Test OP_IF with a true condition (OP_1)
// Expect: Conditional stack has one item and branch is executing
test "OP_IF - true condition" {
    const allocator = testing.allocator;

    const script_bytes = [_]u8{ 0x51, 0x63 }; // OP_1 OP_IF
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, ScriptFlags{});
    defer engine.deinit();

    try engine.execute();

    try std.testing.expectEqual(@as(usize, 1), engine.cond_stack.len());
    try std.testing.expect(engine.cond_stack.isBranchExecuting());
}

// Test OP_IF with a false condition (OP_0)
// Expect: Conditional stack has one item and branch is not executing
test "OP_IF - false condition" {
    const allocator = testing.allocator;

    const script_bytes = [_]u8{ 0x00, 0x63 }; // OP_0 OP_IF
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, ScriptFlags{});
    defer engine.deinit();

    try engine.execute();

    try testing.expectEqual(@as(usize, 1), engine.cond_stack.len());
    try testing.expect(!engine.cond_stack.isBranchExecuting());
}

// Test OP_NOTIF with a true condition (OP_1)
// Expect: Conditional stack has one item and branch is not executing (inverted)
test "OP_NOTIF - true condition" {
    const allocator = std.testing.allocator;

    const script_bytes = [_]u8{ 0x51, 0x64 }; // OP_1 OP_NOTIF
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, ScriptFlags{});
    defer engine.deinit();

    try engine.execute();

    try std.testing.expectEqual(@as(usize, 1), engine.cond_stack.len());
    try std.testing.expect(!engine.cond_stack.isBranchExecuting());
}

// Test OP_NOTIF with a false condition (OP_0)
// Expect: Conditional stack has one item and branch is executing (inverted)
test "OP_NOTIF - false condition" {
    const allocator = std.testing.allocator;

    const script_bytes = [_]u8{ 0x00, 0x64 }; // OP_0 OP_NOTIF
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, ScriptFlags{});
    defer engine.deinit();

    try engine.execute();

    try std.testing.expectEqual(@as(usize, 1), engine.cond_stack.len());
    try std.testing.expect(engine.cond_stack.isBranchExecuting());
}

test "OP_ELSE" {
    const allocator = std.testing.allocator;

    // Test OP_ELSE with a matching OP_IF
    // Expect: Conditional stack state is toggled correctly
    {
        const script_bytes = [_]u8{ 0x63, 0x67 }; // OP_IF OP_ELSE
        const script = Script.init(&script_bytes);
        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        try opIf(&engine);
        try opElse(&engine);
        try std.testing.expectEqual(@as(usize, 1), engine.cond_stack.len());
    }

    // Test OP_ELSE without a matching OP_IF
    // Expect: Error due to empty conditional stack
    {
        const script_bytes = [_]u8{0x67}; // OP_ELSE
        const script = Script.init(&script_bytes);
        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        try std.testing.expectError(ConditionalStackError.EmptyConditionalStack, opElse(&engine));
    }
}

// Test OP_ENDIF with a matching OP_IF
// Expect: Conditional stack is empty after OP_ENDIF
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

    // Test OP_ENDIF without a matching OP_IF
    // Expect: Error due to empty conditional stack
    {
        const script_bytes = [_]u8{0x68}; // OP_ENDIF
        const script = Script.init(&script_bytes);
        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        try std.testing.expectError(ConditionalStackError.EmptyConditionalStack, opEndIf(&engine));
    }
}
