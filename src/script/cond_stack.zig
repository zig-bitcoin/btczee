const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

/// Errors that can occur during stack operations
pub const ConditionalStackError = error{
    StackUnderflow,
    OutOfMemory,
    InvalidValue,
};

/// ConditionalStack for script execution
///
pub const ConditionalStack = struct {
    stack: std.ArrayList(u8),
    /// Memory allocator used for managing item storage
    allocator: Allocator,

    /// Initialize a new ConditionalStack
    pub fn init(allocator: Allocator) ConditionalStack {
        return .{
            .stack = std.ArrayList(u8).init(allocator),
            .allocator = allocator,
        };
    }

    /// Deallocate all resources used by the ConditionalStack
    pub fn deinit(self: *ConditionalStack) void {
        self.stack.deinit();
    }

    /// Push an item onto the stack
    pub fn push(self: *ConditionalStack, item: u8) ConditionalStackError!void {
        self.stack.append(item) catch {
            return ConditionalStackError.OutOfMemory;
        };
    }

    /// Pop an item from the stack
    pub fn pop(self: *ConditionalStack) ConditionalStackError!void {
        // _ = self.stack.popOrNull() orelse return ConditionalStackError.StackUnderflow;
        self.stack.items.len -= 1;
    }

    pub fn branchExecuting(self: ConditionalStack) bool {
        if (self.stack.items.len == 0) {
            return true;
        }
        return self.stack.items[self.stack.items.len-1] == 1;
    }

    pub fn swap(self: *ConditionalStack) ConditionalStackError!void {
        if (self.stack.items.len == 0) {
            return ConditionalStackError.StackUnderflow;
        }
        const index = self.stack.items.len - 1;

        switch (self.stack.items[index]) {
            0 => self.stack.items[index] = 1,
            1 => self.stack.items[index] = 0,
            2 => self.stack.items[index] = 3,
            else => return ConditionalStackError.InvalidValue,
        }
    }

    /// Get the number of items in the stack
    pub fn len(self: ConditionalStack) usize {
        return self.stack.items.len;
    }
};

test "ConditionalStack basic operations" {
    const allocator = testing.allocator;
    var cond_stack = ConditionalStack.init(allocator);
    defer cond_stack.deinit();

    // Test branch executing
    try testing.expectEqual(true, cond_stack.branchExecuting());

    // Test push and len
    try cond_stack.push(5);
    try testing.expectEqual(1, cond_stack.len());

    // Test push and len
    try cond_stack.push(10);
    try testing.expectEqual(2, cond_stack.len());
    
    // Tese pop
    {
        try cond_stack.pop();
        try testing.expectEqual(1, cond_stack.len());
    }
}
