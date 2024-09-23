const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// Errors that can occur during stack operations
pub const ConditionalStackError = error{
    InvalidCondition,
    DisabledOpcode,
    UnbalancedConditional,
};

/// ConditionalStack represents a stack of conditional values used in script execution
///
/// This struct implements a stack data structure using a dynamic array.
/// It manages conditional values (0, 1, 2) for branching in script execution.
pub const ConditionalStack = struct {
    const Self = @This();

    /// Dynamic array to store conditional values
    stack: std.ArrayList(u8),
    /// Memory allocator used for managing stack storage
    allocator: Allocator,

    /// Initialize a new ConditionalStack
    ///
    /// Args:
    ///     allocator: Memory allocator for managing stack storage
    ///
    /// Returns: A new ConditionalStack instance
    pub fn init(allocator: Allocator) Self {
        return .{
            .stack = std.ArrayList(u8).init(allocator),
            .allocator = allocator,
        };
    }

    /// Deallocate all resources used by the ConditionalStack
    pub fn deinit(self: *Self) void {
        self.stack.deinit();
    }

    /// Push a conditional value onto the stack
    ///
    /// In Bitcoin script, conditional values are strictly limited to:
    /// - 0: represents false
    /// - 1: represents true
    ///
    /// Args:
    ///     value: The conditional value to push (must be 0 or 1)
    ///
    /// Returns:
    ///     Possible error if allocation fails
    pub fn push(self: *Self, value: u8) !void {
        try self.stack.append(value);
    }

    /// Pop a conditional value from the stack
    pub fn pop(self: *ConditionalStack) !void {
        if (self.stack.items.len == 0) {
            return ConditionalStackError.UnbalancedConditional;
        }
        _ = self.stack.pop();
    }

    /// Check if the current branch is executing based on the top of the stack
    ///
    /// Returns:
    ///     true if the stack is empty or the top value is 1, false otherwise
    pub fn isBranchExecuting(self: *Self) bool {
        if (self.stack.items.len == 0) {
            return true;
        } else {
            return self.stack.items[self.stack.items.len - 1] == 1;
        }
    }

    /// Get the current length of the stack
    ///
    /// Returns:
    ///     The number of items currently in the stack
    pub fn len(self: *Self) usize {
        return self.stack.items.len;
    }
};

test "ConditionalStack - initialization and deinitialization" {
    const allocator = testing.allocator;
    var cond_stack = ConditionalStack.init(allocator);
    defer cond_stack.deinit();

    try testing.expectEqual(0, cond_stack.len());
}

test "ConditionalStack - push and pop" {
    const allocator = testing.allocator;
    var cond_stack = ConditionalStack.init(allocator);
    defer cond_stack.deinit();

    try cond_stack.push(1);
    try testing.expectEqual(1, cond_stack.len());

    try cond_stack.push(0);
    try testing.expectEqual(2, cond_stack.len());

    try cond_stack.pop();
    try testing.expectEqual(1, cond_stack.len());

    try cond_stack.pop();
    try testing.expectEqual(0, cond_stack.len());

    try testing.expectError(ConditionalStackError.UnbalancedConditional, cond_stack.pop());
}

test "ConditionalStack - isBranchExecuting" {
    const allocator = testing.allocator;
    var cond_stack = ConditionalStack.init(allocator);
    defer cond_stack.deinit();

    try testing.expect(cond_stack.isBranchExecuting());

    try cond_stack.push(1);
    try testing.expect(cond_stack.isBranchExecuting());

    try cond_stack.push(0);
    try testing.expect(!cond_stack.isBranchExecuting());

    try cond_stack.push(2);
    try testing.expect(!cond_stack.isBranchExecuting());
}

test "ConditionalStack - multiple operations" {
    const allocator = testing.allocator;
    var cond_stack = ConditionalStack.init(allocator);
    defer cond_stack.deinit();

    try cond_stack.push(1);
    try cond_stack.push(0);
    try cond_stack.push(2);

    try testing.expectEqual(3, cond_stack.len());
    try testing.expect(!cond_stack.isBranchExecuting());

    _ = try cond_stack.pop(); // Use _ to explicitly discard the return value
    try testing.expectEqual(2, cond_stack.len());
    try testing.expect(!cond_stack.isBranchExecuting());

    _ = try cond_stack.pop(); // Use _ to explicitly discard the return value
    try testing.expectEqual(1, cond_stack.len());
    try testing.expect(cond_stack.isBranchExecuting());
}
