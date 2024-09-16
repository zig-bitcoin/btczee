const std = @import("std");
pub const VersionMessage = @import("version.zig").VersionMessage;

pub const MessageTypes = enum { Version };

pub const Message = union(MessageTypes) {
    Version: VersionMessage,

    pub fn deinit(self: Message, allocator: std.mem.Allocator) void {
        switch (self) {
            .Version => |m| m.deinit(allocator),
        }
    }
};
