const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

/// Errors that can occur during stack operations
pub const ConditionalStackError = error{
    StackUnderflow,
    OutOfMemory,
};

pub const ConditionalValues = enum(u8) {
    False = 0,
    True = 1,
    Skip = 2,
};

/// ConditionalStack for script execution
///
pub const ConditionalStack = struct {
    stack: std.ArrayList(ConditionalValues),
    /// Memory allocator used for managing item storage
    allocator: Allocator,

    /// Initialize a new ConditionalStack
    pub fn init(allocator: Allocator) ConditionalStack {
        return .{
            .stack = std.ArrayList(ConditionalValues).init(allocator),
            .allocator = allocator,
        };
    }

    /// Deallocate all resources used by the ConditionalStack
    pub fn deinit(self: *ConditionalStack) void {
        self.stack.deinit();
    }

    /// Push an item onto the stack
    pub fn push(self: *ConditionalStack, item: ConditionalValues) ConditionalStackError!void {
        self.stack.append(item) catch {
            return ConditionalStackError.OutOfMemory;
        };
    }

    /// Delete an item from the stack
    pub fn delete(self: *ConditionalStack) ConditionalStackError!void {
        if (self.stack.items.len == 0) {
            return ConditionalStackError.StackUnderflow;
        }
        self.stack.items.len -= 1;
    }

    pub fn branchExecuting(self: ConditionalStack) bool {
        if (self.stack.items.len == 0) {
            return true;
        }
        return self.stack.items[self.stack.items.len-1] == ConditionalValues.True;
    }

    /// Swap the top value of the conditional stack between True and False.
    /// If the top value is Skip, it remains unchanged.
    pub fn swap(self: *ConditionalStack) ConditionalStackError!void {
        if (self.stack.items.len == 0) {
            return ConditionalStackError.StackUnderflow;
        }
        const index = self.stack.items.len - 1;

        switch (self.stack.items[index]) {
            ConditionalValues.False => self.stack.items[index] = ConditionalValues.True,
            ConditionalValues.True => self.stack.items[index] = ConditionalValues.False,
            ConditionalValues.Skip => {},
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
    try cond_stack.push(ConditionalValues.True);
    try testing.expectEqual(1, cond_stack.len());
    
    // Test delete
    try cond_stack.delete();
    try testing.expectEqual(0, cond_stack.len());
}
