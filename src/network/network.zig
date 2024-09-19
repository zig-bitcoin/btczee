/// What kind of network we are on.
pub const NetworkKind = enum {
    /// The Bitcoin mainnet network.
    main,
    /// Some kind of testnet network.
    @"test",

    pub fn fromNetwork(n: Network) NetworkKind {
        return n.toKind();
    }
};

/// The cryptocurrency network to act on.
pub const Network = enum {
    /// Mainnet Bitcoin.
    bitcoin,
    /// Bitcoin's testnet network.
    testnet,
    /// Bitcoin's signet network.
    signet,
    /// Bitcoin's regtest network.
    regtest,

    pub fn toKind(self: Network) NetworkKind {
        return switch (self) {
            .bitcoin => .main,
            .testnet, .signet, .regtest => .@"test",
        };
    }

    // TODO: fromMagic and etc
};
