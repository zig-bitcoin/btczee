const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

/// Errors that can occur during stack operations
pub const StackError = error{
    StackUnderflow,
    OutOfMemory,
    InvalidValue,
    VerifyFailed,
};

/// Stack for script execution
///
/// This struct implements a stack data structure using a dynamic array.
/// It manages memory allocation and deallocation for stored items.
pub const Stack = struct {
    /// Dynamic array to store stack items
    items: std.ArrayList([]u8),
    /// Memory allocator used for managing item storage
    allocator: Allocator,

    /// Initialize a new Stack
    ///
    /// Args:
    ///     allocator: Memory allocator for managing stack items
    ///
    /// Returns: A new Stack instance
    pub fn init(allocator: Allocator) Stack {
        return .{
            .items = std.ArrayList([]u8).init(allocator),
            .allocator = allocator,
        };
    }

    /// Deallocate all resources used by the Stack
    pub fn deinit(self: *Stack) void {
        // Free memory for each item in the stack
        for (self.items.items) |item| {
            self.allocator.free(item);
        }
        // Deinitialize the ArrayList
        self.items.deinit();
    }

    /// Push an item onto the stack
    ///
    /// # Arguments
    /// - `item`: Slice of bytes to be pushed onto the stack
    ///
    /// # Returns
    /// - `StackError` if out of memory
    pub fn pushByteArray(self: *Stack, item: []const u8) StackError!void {
        // Create a copy of the input item
        const copy = self.allocator.dupe(u8, item) catch return StackError.OutOfMemory;
        errdefer self.allocator.free(copy);

        // Append the copy to the stack
        self.items.append(copy) catch {
            self.allocator.free(copy);
            return StackError.OutOfMemory;
        };
    }

    /// Push an integer onto the stack
    ///
    /// # Arguments
    /// - `value`: The integer value to be pushed onto the stack
    ///
    /// # Returns
    /// - `StackError` if out of memory
    pub fn pushInt(self: *Stack, value: i64) StackError!void {
        var buffer: [8]u8 = undefined;
        const bytes = std.mem.asBytes(&value);
        @memcpy(&buffer, bytes);
        try self.pushByteArray(&buffer);
    }

    /// Pop an integer from the stack
    ///
    /// # Returns
    /// - `i64`: The popped integer value
    /// - `StackError` if the stack is empty or the value is invalid
    pub fn popInt(self: *Stack) StackError!i64 {
        const value = try self.pop();
        defer self.allocator.free(value);

        if (value.len > 8) return StackError.InvalidValue;

        var buffer: [8]u8 = [_]u8{0, 0, 0, 0, 0, 0, 0, 0};
        std.mem.copyBackwards(u8, buffer[0..value.len], value);
        return std.mem.bytesToValue(i64, &buffer);
    }

    /// Pop a boolean value from the stack
    ///
    /// # Returns
    /// - `bool`: The popped boolean value
    /// - `StackError` if the stack is empty
    pub fn popBool(self: *Stack) StackError!bool {
        const value = try self.pop();
        defer self.allocator.free(value);
        return if (value.len == 1 and value[0] != 0) true else false;
    }

    // Function to push a boolean value onto the stack
    pub fn pushBool(self: *Stack, value: bool) !void {
        if (value) {
            try self.pushByteArray(&[_]u8{1});
        } else {
            try self.pushByteArray(&[_]u8{0});
        }
    }

    /// Pop an item from the stack
    ///
    /// # Returns
    /// - `[]u8`: The popped item (caller owns the memory)
    /// - `StackError` if the stack is empty
    pub fn pop(self: *Stack) StackError![]u8 {
        return self.items.popOrNull() orelse return StackError.StackUnderflow;
    }

    /// Peek at an item in the stack without removing it
    ///
    /// # Arguments
    /// - `index`: Index from the top of the stack (0 is the top)
    ///
    /// Returns:
    /// - `[]const u8`: A slice referencing the item at the specified index
    /// - `StackError` if the index is out of bounds
    pub fn peek(self: *Stack, index: usize) StackError![]const u8 {
        if (index >= self.items.items.len) {
            return StackError.StackUnderflow;
        }
        return self.items.items[self.items.items.len - 1 - index];
    }

    /// Get the number of items in the stack
    ///
    /// # Returns
    /// - `usize`: The current number of items in the stack
    pub fn len(self: Stack) usize {
        return self.items.items.len;
    }
};

test "Stack basic operations" {
    const allocator = testing.allocator;
    var stack = Stack.init(allocator);
    defer stack.deinit();

    // Test push and len
    try stack.pushByteArray(&[_]u8{1});
    try testing.expectEqual(@as(usize, 1), stack.len());

    try stack.pushByteArray(&[_]u8{ 2, 3 });
    try testing.expectEqual(@as(usize, 2), stack.len());

    // Test peek
    const top = try stack.peek(0);
    try testing.expectEqualSlices(u8, &[_]u8{ 2, 3 }, top);

    // Test pop
    {
        const popped = try stack.pop();
        defer allocator.free(popped);
        try testing.expectEqualSlices(u8, &[_]u8{ 2, 3 }, popped);
    }
    try testing.expectEqual(@as(usize, 1), stack.len());

    // Test underflow
    try testing.expectError(StackError.StackUnderflow, stack.peek(1));
    {
        const last = try stack.pop();
        defer allocator.free(last);
    }
    try testing.expectError(StackError.StackUnderflow, stack.pop());
}

test "Stack memory management" {
    const allocator = testing.allocator;
    {
        var stack = Stack.init(allocator);
        defer stack.deinit();

        // Push some items
        try stack.pushByteArray(&[_]u8{ 1, 2, 3 });
        try stack.pushByteArray(&[_]u8{ 4, 5 });

        // Pop and ensure memory is handled correctly
        {
            const item1 = try stack.pop();
            defer allocator.free(item1);
            try testing.expectEqualSlices(u8, &[_]u8{ 4, 5 }, item1);
        }

        {
            const item2 = try stack.pop();
            defer allocator.free(item2);
            try testing.expectEqualSlices(u8, &[_]u8{ 1, 2, 3 }, item2);
        }

        // Stack should be empty now
        try testing.expectEqual(@as(usize, 0), stack.len());
    }
    // The stack should be fully deallocated here
}

test "Stack push and peek multiple items" {
    const allocator = testing.allocator;
    var stack = Stack.init(allocator);
    defer stack.deinit();

    // Push multiple items
    try stack.pushByteArray(&[_]u8{1});
    try stack.pushByteArray(&[_]u8{2});
    try stack.pushByteArray(&[_]u8{3});

    // Peek at different indices
    try testing.expectEqualSlices(u8, &[_]u8{3}, try stack.peek(0));
    try testing.expectEqualSlices(u8, &[_]u8{2}, try stack.peek(1));
    try testing.expectEqualSlices(u8, &[_]u8{1}, try stack.peek(2));

    // Verify length
    try testing.expectEqual(@as(usize, 3), stack.len());

    // Attempt to peek beyond stack size
    try testing.expectError(StackError.StackUnderflow, stack.peek(3));
}

test "Stack push empty slice" {
    const allocator = testing.allocator;
    var stack = Stack.init(allocator);
    defer stack.deinit();

    // Push an empty slice
    try stack.pushByteArray(&[_]u8{});

    // Verify it was pushed correctly
    try testing.expectEqual(@as(usize, 1), stack.len());
    try testing.expectEqualSlices(u8, &[_]u8{}, try stack.peek(0));

    // Pop and verify
    const popped = try stack.pop();
    defer allocator.free(popped);
    try testing.expectEqualSlices(u8, &[_]u8{}, popped);
}

test "Stack out of memory simulation" {
    const allocator = testing.allocator;
    var stack = Stack.init(allocator);
    defer stack.deinit();

    // Simulate out of memory by using a failing allocator
    stack.allocator = testing.failing_allocator;

    // Attempt to push, which should fail
    try testing.expectError(StackError.OutOfMemory, stack.pushByteArray(&[_]u8{1}));

    // Verify the stack is still empty
    try testing.expectEqual(@as(usize, 0), stack.len());
}

test "Stack pushInt and popInt" {
    const allocator = testing.allocator;
    var stack = Stack.init(allocator);
    defer stack.deinit();

    // Test pushing and popping positive integers
    try stack.pushInt(42);
    try testing.expectEqual(@as(i64, 42), try stack.popInt());

    // Test pushing and popping negative integers
    try stack.pushInt(-123);
    try testing.expectEqual(@as(i64, -123), try stack.popInt());

    // Test pushing and popping zero
    try stack.pushInt(0);
    try testing.expectEqual(@as(i64, 0), try stack.popInt());

    // Test pushing and popping large integers
    try stack.pushInt(std.math.maxInt(i64));
    try testing.expectEqual(std.math.maxInt(i64), try stack.popInt());

    try stack.pushInt(std.math.minInt(i64));
    try testing.expectEqual(std.math.minInt(i64), try stack.popInt());

    // Test popping from empty stack
    try testing.expectError(StackError.StackUnderflow, stack.popInt());
}

test "Stack pushByteArray" {
    const allocator = testing.allocator;
    var stack = Stack.init(allocator);
    defer stack.deinit();

    // Test pushing and popping a byte array
    const bytes = [_]u8{ 0x12, 0x34, 0x56, 0x78 };
    try stack.pushByteArray(&bytes);

    const popped = try stack.pop();
    defer allocator.free(popped);
    try testing.expectEqualSlices(u8, &bytes, popped);

    // Test pushing and popping an empty byte array
    try stack.pushByteArray(&[_]u8{});
    const empty = try stack.pop();
    defer allocator.free(empty);
    try testing.expectEqualSlices(u8, &[_]u8{}, empty);
}

test "Stack popBool" {
    const allocator = testing.allocator;
    var stack = Stack.init(allocator);
    defer stack.deinit();

    // Test popping true
    try stack.pushByteArray(&[_]u8{1});
    try testing.expect(try stack.popBool());

    // Test popping false
    try stack.pushByteArray(&[_]u8{0});
    try testing.expect(!(try stack.popBool()));

    // Test popping non-zero value as true
    try stack.pushByteArray(&[_]u8{255});
    try testing.expect(try stack.popBool());

    // Test popping empty array as false
    try stack.pushByteArray(&[_]u8{});
    try testing.expect(!(try stack.popBool()));

    // Test popping from empty stack
    try testing.expectError(StackError.StackUnderflow, stack.popBool());
}
