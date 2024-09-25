const std = @import("std");
const P2P = @import("../network/p2p.zig").P2P;
const Block = @import("../types/block.zig").Block;
const Transaction = @import("../types/transaction.zig").Transaction;

pub const IBD = struct {
    p2p: *P2P,

    pub fn init(p2p: *P2P) IBD {
        return .{
            .p2p = p2p,
        };
    }
    
    pub fn start(_: *IBD) !void {}
};
