const std = @import("std");
const Allocator = std.mem.Allocator;
const testing = std.testing;

pub const StackError = error{
    StackUnderflow,
    OutOfMemory,
};

/// Stack for script execution
pub const Stack = struct {
    items: std.ArrayList([]u8),
    allocator: Allocator,

    pub fn init(allocator: Allocator) Stack {
        return .{
            .items = std.ArrayList([]u8).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Stack) void {
        for (self.items.items) |item| {
            self.allocator.free(item);
        }
        self.items.deinit();
    }

    pub fn push(self: *Stack, item: []const u8) StackError!void {
        const copy = self.allocator.dupe(u8, item) catch return StackError.OutOfMemory;
        errdefer self.allocator.free(copy);
        self.items.append(copy) catch {
            self.allocator.free(copy);
            return StackError.OutOfMemory;
        };
    }

    pub fn pop(self: *Stack) StackError![]u8 {
        return self.items.popOrNull() orelse return StackError.StackUnderflow;
    }

    pub fn peek(self: *Stack, index: usize) StackError![]const u8 {
        if (index >= self.items.items.len) {
            return StackError.StackUnderflow;
        }
        return self.items.items[self.items.items.len - 1 - index];
    }

    pub fn len(self: Stack) usize {
        return self.items.items.len;
    }
};

test "Stack operations" {
    const allocator = testing.allocator;
    var stack = Stack.init(allocator);
    defer stack.deinit();

    // Test push and len
    try stack.push(&[_]u8{1});
    try testing.expectEqual(@as(usize, 1), stack.len());

    try stack.push(&[_]u8{ 2, 3 });
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
        try stack.push(&[_]u8{ 1, 2, 3 });
        try stack.push(&[_]u8{ 4, 5 });

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
