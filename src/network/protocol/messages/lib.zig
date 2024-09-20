const std = @import("std");
pub const VersionMessage = @import("version.zig").VersionMessage;
pub const VerackMessage = @import("verack.zig").VerackMessage;
pub const GetaddrMessage = @import("getaddr.zig").GetaddrMessage;

pub const MessageTypes = enum { Version, Verack, Getaddr };

pub const Message = union(MessageTypes) {
    Version: VersionMessage,
    Verack: VerackMessage,
    Getaddr: GetaddrMessage,

    pub fn deinit(self: Message, allocator: std.mem.Allocator) void {
        switch (self) {
            .Version => |m| m.deinit(allocator),
            .Verack => {},
            .Getaddr => {},
        }
    }
    pub fn checksum(self: Message) [4]u8 {
        return switch (self) {
            .Version => |m| m.checksum(),
            .Verack => |m| m.checksum(),
            .Getaddr => |m| m.checksum(),
        };
    }

    pub fn hintSerializedLen(self: Message) usize {
        return switch (self) {
            .Version => |m| m.hintSerializedLen(),
            .Verack => |m| m.hintSerializedLen(),
            .Getaddr => |m| m.hintSerializedLen(),
        };
    }
};
