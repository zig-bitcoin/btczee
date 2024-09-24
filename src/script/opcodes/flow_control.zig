const std = @import("std");
const testing = std.testing;
const Engine = @import("../engine.zig").Engine;
const Script = @import("../lib.zig").Script;
const ScriptFlags = @import("../lib.zig").ScriptFlags;
const ConditionalStackError = @import("../cond_stack.zig").ConditionalStackError;
const Opcode = @import("./constant.zig").Opcode;
const OpConditional = @import("./constant.zig").OpConditional;

/// OP_IF: Conditionally executes the following statements
/// If the current branch is executing:
///   - If the stack is empty, treat as false
///   - Otherwise, pop the top stack value and use it as the condition
/// If the current branch is not executing, mark as skip
/// Pushes the resulting condition (0: OpConditional.False, 1: OpConditional.True, 2: OpConditional.Skip) onto the conditional stack
pub fn opIf(engine: *Engine) !void {
    var cond_val: u8 = OpConditional.False.toU8(); // Initialize as false
    if (engine.cond_stack.isBranchExecuting()) {
        if (engine.stack.len() == 0) {
            cond_val = OpConditional.False.toU8(); // Treat empty stack as false
        } else {
            const is_truthy = try engine.stack.popBool();
            if (is_truthy) {
                cond_val = OpConditional.True.toU8(); // Set to true if top stack value is truthy
            }
        }
    } else {
        cond_val = OpConditional.Skip.toU8(); // Set to skip if current branch is not executing
    }
    // Push the condition value onto the conditional stack
    // 0: false, 1: true, 2: skip
    try engine.cond_stack.push(cond_val);
}

/// OP_NOTIF: Similar to OP_IF, but inverts the condition
/// If the current branch is executing:
///   - Pop the top stack value and invert its truthiness
/// If the current branch is not executing, mark as skip
/// Pushes the resulting condition (0: OpConditional.False, 1: OpConditional.True, 2: OpConditional.Skip) onto the conditional stack
pub fn opNotIf(engine: *Engine) !void {
    var cond_val: u8 = OpConditional.True.toU8(); // true (inverted)
    if (engine.cond_stack.isBranchExecuting()) {
        const is_truthy = try engine.stack.popBool();
        if (is_truthy) {
            cond_val = OpConditional.False.toU8(); // false (inverted)
        }
    } else {
        cond_val = OpConditional.Skip.toU8(); // skip
    }
    try engine.cond_stack.push(cond_val);
}

/// OP_ELSE: Toggles the execution state of the current conditional block
/// If the conditional stack is empty, returns an error
pub fn opElse(engine: *Engine) !void {
    if (engine.cond_stack.len() == 0) {
        return ConditionalStackError.UnbalancedConditional;
    }

    const cond_idx = engine.cond_stack.len() - 1;
    switch (engine.cond_stack.stack.items[cond_idx]) {
        OpConditional.False.toU8() => engine.cond_stack.stack.items[cond_idx] = OpConditional.True.toU8(),
        OpConditional.True.toU8() => engine.cond_stack.stack.items[cond_idx] = OpConditional.False.toU8(),
        OpConditional.Skip.toU8() => {}, // Leave unchanged
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

    const script_bytes = [_]u8{ Opcode.OP_1.toBytes(), Opcode.OP_IF.toBytes() };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, ScriptFlags{});
    defer engine.deinit();

    try engine.execute();

    try std.testing.expectEqual(1, engine.cond_stack.len());
    try std.testing.expect(engine.cond_stack.isBranchExecuting());
}

// Test OP_IF with a false condition (OP_0)
// Expect: Conditional stack has one item and branch is not executing
test "OP_IF - false condition" {
    const allocator = testing.allocator;

    const script_bytes = [_]u8{ Opcode.OP_0.toBytes(), Opcode.OP_IF.toBytes() };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, ScriptFlags{});
    defer engine.deinit();

    try engine.execute();

    try testing.expectEqual(1, engine.cond_stack.len());
    try testing.expect(!engine.cond_stack.isBranchExecuting());
}

// Test OP_NOTIF with a true condition (OP_1)
// Expect: Conditional stack has one item and branch is not executing (inverted)
test "OP_NOTIF - true condition" {
    const allocator = std.testing.allocator;

    const script_bytes = [_]u8{ Opcode.OP_1.toBytes(), Opcode.OP_NOTIF.toBytes() };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, ScriptFlags{});
    defer engine.deinit();

    try engine.execute();

    try std.testing.expectEqual(1, engine.cond_stack.len());
    try std.testing.expect(!engine.cond_stack.isBranchExecuting());
}

// Test OP_NOTIF with a false condition (OP_0)
// Expect: Conditional stack has one item and branch is executing (inverted)
test "OP_NOTIF - false condition" {
    const allocator = std.testing.allocator;

    const script_bytes = [_]u8{ Opcode.OP_0.toBytes(), Opcode.OP_NOTIF.toBytes() };
    const script = Script.init(&script_bytes);

    var engine = Engine.init(allocator, script, ScriptFlags{});
    defer engine.deinit();

    try engine.execute();

    try std.testing.expectEqual(1, engine.cond_stack.len());
    try std.testing.expect(engine.cond_stack.isBranchExecuting());
}

test "OP_ELSE" {
    const allocator = std.testing.allocator;

    // Test OP_ELSE with a matching OP_IF
    // Expect: Conditional stack state is toggled correctly
    {
        const script_bytes = [_]u8{ Opcode.OP_IF.toBytes(), Opcode.OP_ELSE.toBytes() };
        const script = Script.init(&script_bytes);
        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        try opIf(&engine);
        try opElse(&engine);
        try std.testing.expectEqual(1, engine.cond_stack.len());
    }

    // Test OP_ELSE without a matching OP_IF
    // Expect: Error due to empty conditional stack
    {
        const script_bytes = [_]u8{Opcode.OP_ELSE.toBytes()};
        const script = Script.init(&script_bytes);
        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        try std.testing.expectError(ConditionalStackError.UnbalancedConditional, opElse(&engine));
    }
}

// Test OP_ENDIF with a matching OP_IF
// Expect: Conditional stack is empty after OP_ENDIF
test "OP_ENDIF" {
    const allocator = std.testing.allocator;

    // Test OP_ENDIF with matching OP_IF
    {
        const script_bytes = [_]u8{ Opcode.OP_IF.toBytes(), Opcode.OP_ENDIF.toBytes() };
        const script = Script.init(&script_bytes);
        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        try engine.stack.pushBool(true); // Push a true value onto the stack
        try opIf(&engine);
        try std.testing.expectEqual(1, engine.cond_stack.len());

        try opEndIf(&engine);
        try std.testing.expectEqual(0, engine.cond_stack.len());
    }

    // Test OP_ENDIF without a matching OP_IF
    // Expect: Error due to empty conditional stack
    {
        const script_bytes = [_]u8{Opcode.OP_ENDIF.toBytes()};
        const script = Script.init(&script_bytes);
        var engine = Engine.init(allocator, script, ScriptFlags{});
        defer engine.deinit();

        try std.testing.expectError(ConditionalStackError.UnbalancedConditional, opEndIf(&engine));
    }
}
