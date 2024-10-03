const std = @import("std");
const bitcoin_primitives = @import("bitcoin-primitives");
const secp256k1 = bitcoin_primitives.secp256k1;
const address_lib = @import("btczee").address;
const mpmc = @import("util/sync/mpmc.zig");
const clap = @import("clap");
const builtin = @import("builtin");

pub const std_options = std.Options{
    .log_level = switch (builtin.mode) {
        .Debug => .debug,
        else => .info,
    },
};

/// Checks all given information's before passing to the vanity address finder function.
/// Returns Ok if all checks were successful.
/// Returns Err if the string is not in base58 format.
fn validateInput(string: []const u8) !void {
    if (string.len == 0) {
        return;
    }

    for (string) |c|
        if (c == '0' or c == 'I' or c == 'O' or c == 'l' or !std.ascii.isAlphanumeric(c))
            return error.NotBase58;

    return;
}

/// A struct to hold bitcoin::secp256k1::SecretKey bitcoin::Key::PublicKey and a string address
pub const KeysAndAddress = struct {
    private_key: secp256k1.SecretKey,
    public_key: secp256k1.PublicKey,
    comp_address: std.BoundedArray(u8, 50),

    /// Generates a randomly generated key pair and their compressed addresses without generating a new Secp256k1.
    /// and Returns them in a KeysAndAddress struct.
    pub fn generateRandom(rand: std.Random, secp: secp256k1.Secp256k1) !KeysAndAddress {
        const secret_key, const pk = secp.generateKeypair(rand);

        // to calculate comp_address we need init p2pkh address with hash160 of pk
        // we need serialize pk and serilized data should be hashed by hash160
        // pk is compressed so we use just pk.serialize
        // TODO create PublicKey type abstraction and add compressed option inside
        // with method that returns hash160 of pk
        const hash = getHashForPublicKey(pk);

        return .{
            .private_key = secret_key,
            .public_key = pk,
            .comp_address = try address_lib.Address.initP2pkh(.{ .inner = hash }, .main).toString(),
        };
    }

    fn getHashForPublicKey(pk: secp256k1.PublicKey) [20]u8 {
        var out: [bitcoin_primitives.hashes.Hash160.digest_length]u8 = undefined;
        bitcoin_primitives.hashes.Hash160.hash(&pk.serialize(), &out, .{});
        return out;
    }

    /// Use safe mode if you're calling this function out of vanity_addr_generator.rs
    /// Generates a the key pair and their compressed addresses from the given private key.
    /// Returns them in a KeysAndAddress struct.
    pub fn generateFromBiguint(
        gpa: std.mem.Allocator,
        s: secp256k1.Secp256k1,
        private_key_biguint: u256,
        safe_mode: bool,
    ) !KeysAndAddress {
        if (safe_mode) {
            if (private_key_biguint == 0) {
                return error.RangeCantBeZero;
            }

            const secp256k1_order = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
            if (private_key_biguint > secp256k1_order) {
                return error.RangeMaxMoreOrder;
            }
        }

        // Convert the BigUint to a 32-byte array, zero-padded on the left
        const private_key_bytes = v: {
            var bytes: [32]u8 = undefined;

            std.mem.writeInt(u256, &bytes, private_key_biguint, .big);
            break :v bytes;
        };
        const private_key = try secp256k1.SecretKey.fromSlice(&private_key_bytes);
        const public_key = secp256k1.PublicKey.fromSecretKey(s, private_key);

        const hash = getHashForPublicKey(public_key);

        return .{
            .private_key = private_key,
            .public_key = public_key,
            .comp_address = try address_lib.Address.initP2pkh(.{ .inner = hash }, .main).toString(gpa),
        };
    }
};

pub const VanityMode = enum {
    prefix,
    suffix,
    anywhere,
};

fn threadSearcher(
    str: []const u8,
    secp: secp256k1.Secp256k1,
    vanity_mode: VanityMode,
    case_sensitive: bool,
    sender: *mpmc.UnboundedChannel(KeysAndAddress).Sender,
    found: *std.atomic.Value(bool),
) void {
    defer std.log.debug("thread stopped", .{});
    var buf: [100]u8 = undefined;
    var found_str = str;

    if (!case_sensitive) found_str = std.ascii.lowerString(&buf, str);

    while (true) {
        if (found.load(.acquire)) return;

        // Generate the key pair and address using generate_from_biguint
        const keys_and_address = KeysAndAddress.generateRandom(
            std.crypto.random,
            secp,
        ) catch |err| {
            std.log.err("catch error on gen: {}", .{err});
            return;
        };

        const f = switch (case_sensitive) {
            inline false => v: {
                const addr = std.ascii.lowerString(buf[50..], keys_and_address.comp_address.constSlice());

                break :v switch (vanity_mode) {
                    .prefix => std.mem.eql(u8, addr[1 .. found_str.len + 1], found_str),
                    .suffix => std.mem.eql(u8, addr[keys_and_address.comp_address.len - found_str.len ..], found_str),
                    .anywhere => std.mem.indexOf(u8, addr, found_str) != null,
                };
            },
            inline true => switch (vanity_mode) {
                .prefix => std.mem.eql(u8, keys_and_address.comp_address.constSlice()[1 .. found_str.len + 1], found_str),
                .suffix => std.mem.eql(u8, keys_and_address.comp_address.constSlice()[keys_and_address.comp_address.len - found_str.len ..], found_str),
                .anywhere => std.mem.indexOf(u8, keys_and_address.comp_address.constSlice(), found_str) != null,
            },
        };

        // send to sender

        if (f) {
            return sender.send(keys_and_address) catch return;
        }
    }
}

/// Search for the vanity address with given threads within given range.
/// First come served! If a thread finds a vanity address that satisfy all the requirements it sends
/// the keys_and_address::KeysAndAddress struct wia std::sync::mpsc channel and find_vanity_address function kills all the other
/// threads and closes the channel and returns the found KeysAndAddress struct that includes
/// key pair and the desired address.
/// returns error if there is no match withing given range.
fn findVanityAddress(
    gpa: std.mem.Allocator,
    str: []const u8,
    threads: usize,
    case_sensitive: bool,
    vanity_mode: VanityMode,
    secp: secp256k1.Secp256k1,
) !KeysAndAddress {
    var chan = mpmc.UnboundedChannel(KeysAndAddress).init(gpa);
    defer chan.deinit();
    var sender = try chan.sender();
    defer sender.deinit();

    var receiver = try chan.receiver();
    defer receiver.deinit();

    var found = std.atomic.Value(bool).init(false);

    const started = std.time.milliTimestamp();

    var wg = std.Thread.WaitGroup{};

    for (0..threads) |_| {
        wg.spawnManager(threadSearcher, .{
            str,
            secp,
            vanity_mode,
            case_sensitive,
            &sender,
            &found,
        });
    }

    const key = receiver.recv() orelse unreachable;
    defer key.release();

    found.store(true, .seq_cst);

    wg.wait();

    std.log.info("\n\nfound in {d} sec\n\n", .{@as(f32, @floatFromInt(std.time.milliTimestamp() - started)) / 1000.0});

    return key.value.*;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{
        .thread_safe = true,
    }){};
    defer std.debug.assert(gpa.deinit() == .ok);

    // fba.threadSafeAllocator()
    var secp = secp256k1.Secp256k1.genNew();
    defer secp.deinit();

    var clap_res = v: {
        // First we specify what parameters our program can take.
        // We can use `parseParamsComptime` to parse a string into an array of `Param(Help)`
        const params = comptime clap.parseParamsComptime(
            \\-h, --help                       Display this help and exit.
            \\-p, --prefix                     Finds a vanity address which has 'string' prefix. [default]
            \\-s, --suffix                     Finds a vanity address which has 'string' suffix.
            \\-a, --anywhere                   Finds a vanity address which includes 'string' at any part            
            \\-t, --threads <usize>            Number of threads to be used. [default: 16]
            \\-c, --case-sensitive             Use case sensitive comparison to match addresses.
            \\<str>                            String used to match addresses
        );

        // Initialize our diagnostics, which can be used for reporting useful errors.
        // This is optional. You can also pass `.{}` to `clap.parse` if you don't
        // care about the extra information `Diagnostics` provides.
        var diag = clap.Diagnostic{};
        var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
            .diagnostic = &diag,
            .allocator = gpa.allocator(),
        }) catch |err| {
            // Report useful error and exit
            diag.report(std.io.getStdErr().writer(), err) catch {};
            return err;
        };
        errdefer res.deinit();

        // helper to print help
        if (res.args.help != 0)
            return clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});

        break :v res;
    };
    defer clap_res.deinit();

    const case_sensitive = if (clap_res.args.@"case-sensitive" != 0) true else false;
    const vanity_mode = if (clap_res.args.suffix != 0) VanityMode.suffix else if (clap_res.args.anywhere != 0) VanityMode.anywhere else VanityMode.prefix;
    const threads: usize = if (clap_res.args.threads) |n| n else 16;

    if (clap_res.positionals.len != 1) return error.WrongPositionalArguments;

    const expected_str = clap_res.positionals[0];

    validateInput(expected_str) catch |err| {
        switch (err) {
            error.NotBase58 => {
                std.log.err("Your input is not in base58. Don't include zero: '0', uppercase i: 'I', uppercase o: 'O', lowercase L: 'l' \nor any non-alphanumeric character in your input!", .{});
                return;
            },
            else => return err,
        }
    };

    std.log.info("Searching key pair which their address has the string: '{s}' (case sensitive = {any}) with {d} threads. Mode = {any}.", .{ expected_str, case_sensitive, threads, vanity_mode });

    const key = try findVanityAddress(gpa.allocator(), expected_str, threads, case_sensitive, vanity_mode, secp);

    std.log.info("private_key(hex): {s}\npublic_key(compressed): {s}\naddress(compressed): {s}", .{
        key.private_key.toString(),
        key.public_key.toString(),
        key.comp_address.constSlice(),
    });
}
