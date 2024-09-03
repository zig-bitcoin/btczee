const std = @import("std");

const zul = @import("zul");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    try benchmarkZul(allocator);
}

const Context = struct {};

fn bech32(_: Context, _: std.mem.Allocator, _: *std.time.Timer) !void {}

fn benchmarkZul(_: std.mem.Allocator) !void {
    const ctx = Context{};

    (try zul.benchmark.runC(ctx, bech32, .{})).print("bech32");
}
