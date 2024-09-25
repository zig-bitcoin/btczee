const std = @import("std");

pub fn read_bytes_exact(allocator: std.mem.Allocator, r: anytype, bytes_nb: u64) ![]u8 {
    comptime {
        if (!std.meta.hasFn(@TypeOf(r), "readAll")) @compileError("Expects r to have fn 'readNoEof'.");
    }

    const bytes = try allocator.alloc(u8, bytes_nb);
    errdefer allocator.free(bytes);
    try r.readNoEof(bytes);
    return bytes;
}
