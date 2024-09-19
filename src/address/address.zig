const std = @import("std");
const bitcoin_primitives = @import("bitcoin-primitives");

const NetworkKind = @import("../network/network.zig").NetworkKind;
const Sha256 = std.crypto.hash.sha2.Sha256;
const Hash160 = bitcoin_primitives.hashes.Hash160;

/// The different types of addresses.
pub const AddressType = enum {
    /// Pay to pubkey hash.
    p2pkh,
    /// Pay to script hash.
    p2sh,
    /// Pay to witness pubkey hash.
    p2wpkh,
    /// Pay to witness script hash.
    p2wsh,
    /// Pay to taproot.
    p2tr,
};

// TODO move to crypto
/// A hash of a public key.
pub const PubkeyHash = struct {
    // hash160
    inner: [Hash160.digest_length]u8,
};

/// SegWit version of a public key hash.
pub const WpubkeyHash = struct {
    // hash160
    inner: [Hash160.digest_length]u8,
};

/// A hash of Bitcoin Script bytecode.
pub const ScriptHash = struct {
    // hash160
    inner: [Hash160.digest_length]u8,
};
/// SegWit version of a Bitcoin Script bytecode hash.
pub const WScriptHash = struct {
    // sha256 hash
    inner: [Sha256.digest_length]u8,
};

/// Known bech32 human-readable parts.
///
/// This is the human-readable part before the separator (`1`) in a bech32 encoded address e.g.,
/// the "bc" in "bc1p2wsldez5mud2yam29q22wgfh9439spgduvct83k3pm50fcxa5dps59h4z5".
pub const KnownHrp = enum {
    /// The main Bitcoin network.
    mainnet,
    /// The test networks, testnet and signet.
    testnets,
    /// The regtest network.
    regtest,
};

// TODO move blockdata constants
/// Mainnet (bitcoin) pubkey address prefix.
pub const pubkey_address_prefix_main: u8 = 0; // 0x00
/// Test (tesnet, signet, regtest) pubkey address prefix.
pub const pubkey_address_prefix_test: u8 = 111; // 0x6f

pub const Address = union(enum) {
    p2pkh: struct { hash: PubkeyHash, network: NetworkKind },
    p2sh: struct { hash: ScriptHash, network: NetworkKind },
    // TODO WitnessProgram
    // segwit: struct { program: WitnessProgram, hrp: KnownHrp },

    /// inint p2pkh address
    pub fn initP2pkh(hash: PubkeyHash, network: NetworkKind) Address {
        return .{
            .p2pkh = .{
                .hash = hash,
                .network = network,
            },
        };
    }

    // TODO make other types of address
    /// Encoding address to string
    /// caller responsible to free data
    pub fn toString(self: Address) !std.BoundedArray(u8, 50) {
        var buf: [50]u8 = undefined;
        switch (self) {
            .p2pkh => |addr| {
                const prefixed: [21]u8 = [1]u8{switch (addr.network) {
                    .main => pubkey_address_prefix_main,
                    .@"test" => pubkey_address_prefix_test,
                }} ++ addr.hash.inner;

                var encoder = bitcoin_primitives.base58.Encoder{};

                var res = try std.BoundedArray(u8, 50).init(0);

                res.resize(encoder.encodeCheck(&res.buffer, &buf, &prefixed)) catch unreachable;

                return res;
            },
            // TODO: implement another types of address
            else => unreachable,
        }
    }
};
