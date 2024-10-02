pub const messages = @import("./messages/lib.zig");
pub const NetworkAddress = @import("types/NetworkAddress.zig");
pub const InventoryItem = @import("types/InventoryItem.zig");
pub const InventoryVector = @import("types/InventoryVector.zig");

/// Network services
pub const ServiceFlags = struct {
    pub const NODE_NETWORK: u64 = 0x1;
    pub const NODE_GETUTXO: u64 = 0x2;
    pub const NODE_BLOOM: u64 = 0x4;
    pub const NODE_WITNESS: u64 = 0x8;
    pub const NODE_XTHIN: u64 = 0x10;
    pub const NODE_NETWORK_LIMITED: u64 = 0x0400;
};

pub const CommandNames = struct {
    pub const VERSION = "version";
    pub const VERACK = "verack";
    pub const ADDR = "addr";
    pub const INV = "inv";
    pub const GETDATA = "getdata";
    pub const NOTFOUND = "notfound";
    pub const GETBLOCKS = "getblocks";
    pub const GETHEADERS = "getheaders";
    pub const TX = "tx";
    pub const BLOCK = "block";
    pub const HEADERS = "headers";
    pub const GETADDR = "getaddr";
    pub const MEMPOOL = "mempool";
    pub const CHECKORDER = "checkorder";
    pub const SUBMITORDER = "submitorder";
    pub const REPLY = "reply";
    pub const PING = "ping";
    pub const PONG = "pong";
    pub const REJECT = "reject";
    pub const FILTERLOAD = "filterload";
    pub const FILTERADD = "filteradd";
    pub const FILTERCLEAR = "filterclear";
    pub const MERKLEBLOCK = "merkleblock";
    pub const ALERT = "alert";
    pub const SENDHEADERS = "sendheaders";
    pub const FEEFILTER = "feefilter";
    pub const SENDCMPCT = "sendcmpct";
    pub const CMPCTBLOCK = "cmpctblock";
    pub const GETBLOCKTXN = "getblocktxn";
    pub const BLOCKTXN = "blocktxn";
};
