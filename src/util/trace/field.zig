const std = @import("std");
const time = @import("../time/time.zig");
const Allocator = std.mem.Allocator;

pub const Field = struct {
    name: []const u8,
    value: Value,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, name: []const u8, value: anytype) Self {
        return Self{
            .name = name,
            .value = Value.init(allocator, value),
        };
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.value.deinit(allocator);
    }

    pub fn custom_format(self: *const Self, writer: anytype) void {
        std.fmt.format(writer, "{s}=", .{self.name}) catch @panic("could not format");
        self.value.format_as_str(writer);
        std.fmt.format(writer, " ", .{}) catch @panic("could not format");
    }
};

pub const Value = union(enum(u8)) {
    null: void,
    string: []const u8,
    bool: bool,
    float: f64,
    int: i64,
    uint: u64,
    enumm: [:0]const u8,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, val: anytype) Self {
        return valToValue(allocator, val);
    }

    fn format_as_str(self: *const Self, writer: anytype) void {
        switch (self.*) {
            .string => |str| {
                std.fmt.format(writer, "\"{s}\"", .{str}) catch unreachable;
            },
            .bool => |b| {
                if (b) {
                    std.fmt.format(writer, "true", .{}) catch unreachable;
                } else {
                    std.fmt.format(writer, "false", .{}) catch unreachable;
                }
            },
            .uint => |u| {
                std.fmt.format(writer, "{d}", .{u}) catch unreachable;
            },
            .int => |i| {
                std.fmt.format(writer, "{d}", .{i}) catch unreachable;
            },
            .float => |f| {
                std.fmt.format(writer, "{d}", .{f}) catch unreachable;
            },
            .null => {
                std.fmt.format(writer, "null", .{}) catch unreachable;
            },
            .enumm => |e| {
                std.fmt.format(writer, "{s}", .{e}) catch unreachable;
            },
        }
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        switch (self.*) {
            Value.string => |str| {
                allocator.free(str);
            },
            else => {},
        }
    }
};

fn valToValue(allocator: Allocator, val: anytype) Value {
    switch (@typeInfo(@TypeOf(val))) {
        .@"enum" => |_| {
            return .{ .enumm = @tagName(val) };
        },
        .enum_literal => {
            return .{ .enumm = @tagName(val) };
        },
        .bool => return .{ .bool = val },
        .optional => |info| {
            _ = info;
            if (val) |v| {
                return valToValue(allocator, v);
            }
            return Value.null;
        },
        .pointer => |info| {
            switch (info.size) {
                .One => {
                    const inner_child_type = switch (@typeInfo(info.child)) {
                        .array => |a| a.child,
                        else => unreachable,
                    };
                    const inner_child_len = switch (@typeInfo(info.child)) {
                        .array => |a| a.len,
                        else => unreachable,
                    };
                    if (inner_child_type == u8) {
                        const str = allocator.alloc(u8, inner_child_len) catch unreachable;
                        @memcpy(str, val[0..]);
                        return .{ .string = str };
                    } else {
                        @compileError("┓\n|\n|--> Invalid field type: can only create value for []u8, not type '" ++ @typeName(@TypeOf(val)) ++ "'\n\n");
                    }
                },
                .Slice => {
                    if (@typeInfo(info.child).int.bits == 8) {
                        const str = allocator.alloc(u8, val.len) catch unreachable;
                        @memcpy(str, val[0..]);
                        return .{ .string = str };
                    } else {
                        @compileError("┓\n|\n|--> Invalid field type: can only create value for []u8, not type '" ++ @typeName(@TypeOf(val)) ++ "'\n\n");
                    }
                },
                else => {},
            }
        },
        .float => |info| {
            _ = info;
            return .{ .float = @as(f64, val) };
        },
        .int => |info| {
            switch (info.signedness) {
                .unsigned => {
                    return .{ .uint = @as(u64, val) };
                },
                .signed => {
                    return .{ .int = @as(i64, val) };
                },
            }
        },
        .comptime_int => {
            return .{ .int = @as(i64, val) };
        },
        .comptime_float => {
            return .{ .float = @as(f64, val) };
        },
        else => {},
    }

    @compileError("┓\n|\n|--> Invalid field type: cannot add field of type'" ++ @typeName(@TypeOf(val)) ++ "' to log entry\n\n");
}
