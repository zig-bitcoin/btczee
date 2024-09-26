const P2P = @import("../network/p2p.zig").P2P;

pub const IBD = struct {
    p2p: *P2P,

    pub fn init(p2p: *P2P) IBD {
        return .{
            .p2p = p2p,
        };
    }
    
    pub fn start(_: *IBD) !void {}
};
