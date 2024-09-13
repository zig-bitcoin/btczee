const std = @import("std");
const testing = std.testing;
const Allocator = std.mem.Allocator;

/// Errors that can occur during stack operations
pub const ConditionalStackError = error {
    EmptyConditionalStack,
    InvalidCondition,
};

pub const ConditionalStack = struct {
const Self = @This();

    stack: std.ArrayList(u8),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Self {
        return .{
            .stack = std.ArrayList(u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.stack.deinit();
    }

    pub fn push(self: *Self, value: u8) !void {
        try self.stack.append(value);
    }

    pub fn pop(self: *Self) !void {
        if (self.stack.items.len == 0) {
            return ConditionalStackError.EmptyConditionalStack;
        }
        _ = self.stack.pop();
    }

    pub fn branchExecuting(self: *Self) bool {
        if (self.stack.items.len == 0) {
            return true;
        } else {
            return self.stack.items[self.stack.items.len - 1] == 1;
        }
    }

    pub fn len(self: *Self) usize {
        return self.stack.items.len;
    }

    pub fn swapCondition(self: *Self) !void {
        if (self.stack.items.len == 0) {
            return ConditionalStackError.EmptyConditionalStack;
        }

        const cond_idx = self.stack.items.len - 1;
        switch (self.stack.items[cond_idx]) {
            0 => self.stack.items[cond_idx] = 1,
            1 => self.stack.items[cond_idx] = 0,
            2 => self.stack.items[cond_idx] = 2,
            else => return ConditionalStackError.InvalidCondition,
        }
    }
};

test "ConditionalStack - initialization and deinitialization" {
    const allocator = testing.allocator;
    var cond_stack = ConditionalStack.init(allocator);
    defer cond_stack.deinit();

    try testing.expectEqual(@as(usize, 0), cond_stack.len());
}

test "ConditionalStack - push and pop" {
    const allocator = testing.allocator;
    var cond_stack = ConditionalStack.init(allocator);
    defer cond_stack.deinit();

    try cond_stack.push(1);
    try testing.expectEqual(@as(usize, 1), cond_stack.len());

    try cond_stack.push(0);
    try testing.expectEqual(@as(usize, 2), cond_stack.len());

    try cond_stack.pop();
    try testing.expectEqual(@as(usize, 1), cond_stack.len());

    try cond_stack.pop();
    try testing.expectEqual(@as(usize, 0), cond_stack.len());

    try testing.expectError(ConditionalStackError.EmptyConditionalStack, cond_stack.pop());
}

test "ConditionalStack - branchExecuting" {
    const allocator = testing.allocator;
    var cond_stack = ConditionalStack.init(allocator);
    defer cond_stack.deinit();

    try testing.expect(cond_stack.branchExecuting());

    try cond_stack.push(1);
    try testing.expect(cond_stack.branchExecuting());

    try cond_stack.push(0);
    try testing.expect(!cond_stack.branchExecuting());

    try cond_stack.push(2);
    try testing.expect(!cond_stack.branchExecuting());
}

test "ConditionalStack - swapCondition" {
    const allocator = testing.allocator;
    var cond_stack = ConditionalStack.init(allocator);
    defer cond_stack.deinit();

    try testing.expectError(ConditionalStackError.EmptyConditionalStack, cond_stack.swapCondition());

    try cond_stack.push(0);
    try cond_stack.swapCondition();
    try testing.expectEqual(@as(u8, 1), cond_stack.stack.items[0]);

    try cond_stack.swapCondition();
    try testing.expectEqual(@as(u8, 0), cond_stack.stack.items[0]);

    try cond_stack.pop();
    try cond_stack.push(2);
    try cond_stack.swapCondition();
    try testing.expectEqual(@as(u8, 2), cond_stack.stack.items[0]);

    try cond_stack.pop();
    try cond_stack.push(3);
    try testing.expectError(ConditionalStackError.InvalidCondition, cond_stack.swapCondition());
}

test "ConditionalStack - multiple operations" {
    const allocator = testing.allocator;
    var cond_stack = ConditionalStack.init(allocator);
    defer cond_stack.deinit();

    try cond_stack.push(1);
    try cond_stack.push(0);
    try cond_stack.push(2);

    try testing.expectEqual(@as(usize, 3), cond_stack.len());
    try testing.expect(!cond_stack.branchExecuting());

    try cond_stack.pop();
    try testing.expectEqual(@as(usize, 2), cond_stack.len());
    try testing.expect(!cond_stack.branchExecuting());

    try cond_stack.swapCondition();
    try testing.expect(cond_stack.branchExecuting());

    try cond_stack.pop();
    try testing.expectEqual(@as(usize, 1), cond_stack.len());
    try testing.expect(cond_stack.branchExecuting());
}
