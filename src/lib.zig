//! btczee is a Bitcoin protocol implementation in Zig.
//! It can be used as a binary or a library.
//! Warning: This is still a work in progress and is not yet ready for production use.
//!
//! btczee can be run as:
//! - a wallet
//! - a miner
//! - a full node
//!
//! btczee is licensed under the MIT license.
pub const config = @import("config/config.zig");
pub const mempool = @import("core/mempool.zig");
pub const p2p = @import("network/p2p.zig");
pub const rpc = @import("network/rpc.zig");
pub const storage = @import("storage/storage.zig");
pub const wallet = @import("wallet/wallet.zig");
pub const miner = @import("miner/miner.zig");
pub const node = @import("node/node.zig");
pub const script = @import("script/lib.zig");

test {
    @import("std").testing.refAllDeclsRecursive(@This());
}
