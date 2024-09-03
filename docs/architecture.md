# Architecture

## Components

### P2P

P2P is responsible for handling the peer-to-peer network.

The main logic is implemented in `src/p2p.zig`.

### RPC

RPC is responsible for handling the RPC requests from the clients.

The main logic is implemented in `src/rpc.zig`.

### Storage

Storage is responsible for handling the blockchain data.

The main logic is implemented in `src/storage.zig`.

### Mempool

Mempool is responsible for handling the mempool of pending transactions.

The main logic is implemented in `src/mempool.zig`.
