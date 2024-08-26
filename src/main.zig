const std = @import("std");
const cli = @import("zig-cli");

// Configuration settings for the CLI
const Args = struct {
    mint: bool = false,
    mnemonic: bool = false,
};

var cfg: Args = .{};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var r = try cli.AppRunner.init(allocator);
    defer r.deinit();

    // Define the CLI app
    const app = cli.App{
        .version = "0.0.1",
        .author = "@AbdelStark",
        .command = .{
            .name = "btczee",
            .target = .{
                .subcommands = &.{
                    .{
                        .name = "info",
                        .description = .{
                            .one_line = "Display information about btczee",
                        },
                        .options = &.{},
                        .target = .{ .action = .{ .exec = displayInfo } },
                    },
                },
            },
        },
    };

    return r.run(&app);
}

fn displayInfo() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print("Version: 0.1.0\n", .{});
}
