//
// ___.    __
// \_ |___/  |_  ____ ________ ____   ____
//  | __ \   __\/ ___\\___   // __ \_/ __ \
//  | \_\ \  | \  \___ /    /\  ___/\  ___/
// |___  /__|  \___  >_____ \\___  >\___  >
//      \/          \/      \/    \/     \/
//
// Bitcoin Implementation in Zig
// =============================

//==== Imports ====//
const std = @import("std");
const Config = @import("config/config.zig").Config;
const Mempool = @import("core/mempool.zig").Mempool;
const Storage = @import("storage/storage.zig").Storage;
const P2P = @import("network/p2p.zig").P2P;
const RPC = @import("network/rpc.zig").RPC;
const Node = @import("node/node.zig").Node;
const ArgParser = @import("util/ArgParser.zig");

//==== Main Entry Point ====//
pub fn main() !void {
    // Initialize the allocator
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = gpa_state.allocator();
    defer _ = gpa_state.deinit();

    // Parse command-line arguments
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    // Set up buffered stdout
    var stdout_buffered = std.io.bufferedWriter(std.io.getStdOut().writer());
    const stdout = stdout_buffered.writer();

    // Run the main program logic
    try mainFull(.{
        .allocator = gpa,
        .args = args[1..],
        .stdout = stdout.any(),
    });

    // Flush the buffered stdout
    return stdout_buffered.flush();
}

//==== Main Program Logic ====//
pub fn mainFull(options: struct {
    allocator: std.mem.Allocator,
    args: []const []const u8,
    stdout: std.io.AnyWriter,
}) !void {
    var program = Program{
        .allocator = options.allocator,
        .args = .{ .args = options.args },
        .stdout = options.stdout,
    };

    return program.mainCommand();
}

//==== Program Structure ====//
const Program = @This();

allocator: std.mem.Allocator,
args: ArgParser,
stdout: std.io.AnyWriter,

//==== Usage Messages ====//
const main_usage =
    \\Usage: btczee [command] [args]
    \\
    \\Commands:
    \\  node     <subcommand>
    \\  wallet   <subcommand>
    \\  help                   Display this message
    \\
;

const node_sub_usage =
    \\Usage:
    \\  btczee node [command] [args]
    \\  btczee node [options] [ids]...
    \\
    \\Commands:
    \\  help                   Display this message
    \\
;

const wallet_sub_usage =
    \\Usage:
    \\  btczee wallet [command] [args]
    \\
    \\Commands:
    \\  create                 Create a new wallet
    \\  load                   Load an existing wallet
    \\  help                   Display this message
    \\
;

//==== Command Handlers ====//

// Main Command Handler
pub fn mainCommand(program: *Program) !void {
    while (program.args.next()) {
        if (program.args.flag(&.{"node"}))
            return program.nodeSubCommand();
        if (program.args.flag(&.{"wallet"}))
            return program.walletSubCommand();
        if (program.args.flag(&.{ "-h", "--help", "help" }))
            return program.stdout.writeAll(main_usage);
        if (program.args.positional()) |_| {
            try std.io.getStdErr().writeAll(main_usage);
            return error.InvalidArgument;
        }
    }
    try std.io.getStdErr().writeAll(main_usage);
    return error.InvalidArgument;
}

// Node Subcommand Handler
fn nodeSubCommand(program: *Program) !void {
    if (program.args.next()) {
        if (program.args.flag(&.{ "-h", "--help", "help" }))
            return program.stdout.writeAll(node_sub_usage);
    }
    return program.runNodeCommand();
}

// Wallet Subcommand Handler
fn walletSubCommand(program: *Program) !void {
    if (program.args.next()) {
        if (program.args.flag(&.{"create"}))
            return program.walletCreateCommand();
        if (program.args.flag(&.{"load"}))
            return program.walletLoadCommand();
        if (program.args.flag(&.{ "-h", "--help", "help" }))
            return program.stdout.writeAll(wallet_sub_usage);
    }
    try std.io.getStdErr().writeAll(wallet_sub_usage);
    return error.InvalidArgument;
}

//==== Command Implementations ====//

// Node Command Implementation
fn runNodeCommand(program: *Program) !void {
    // Load configuration
    var config = try Config.load(program.allocator, "bitcoin.conf.example");
    defer config.deinit();

    // Initialize components
    var mempool = try Mempool.init(program.allocator, &config);
    var storage = try Storage.init(&config);
    var p2p = try P2P.init(program.allocator, &config);
    var rpc = try RPC.init(program.allocator, &config, &mempool, &storage);

    var node = try Node.init(&mempool, &storage, &p2p, &rpc);
    // Node has the responsibility to deinitialize all the components
    defer node.deinit();

    // Start the node
    try node.start();
}

// Wallet Create Command Implementation
fn walletCreateCommand(program: *Program) !void {
    return program.stdout.writeAll("Wallet creation not implemented yet\n");
}

// Wallet Load Command Implementation
fn walletLoadCommand(program: *Program) !void {
    return program.stdout.writeAll("Wallet loading not implemented yet\n");
}

//==== End of File ====//
