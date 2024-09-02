const std = @import("std");

const scriptWitness = struct {
    stack: [][]u8,
};

/// A combination of a transaction hash and an index n into its vout
const OutPoint = struct {
    hash: u32, 
    index: u32,
};

// An input of a transaction.  It contains the location of the previous
// transaction's output that it claims and a signature that matches the
// output's public key.
const TxIn = struct {
    prevOutPoint: OutPoint,
    sigScript: []u8,
    sequence: u32,
    txWitness: scriptWitness,
};

const TxOut = struct {
    value: i64,
    scriptPubKey: []u8,
};

const Transaction = struct {
    vin: []TxIn,
    vout: []TxOut,
    version: u32,
    lockTime: u32,

    pub fn init(vin: []TxIn, vout: []TxOut, version: u32, lockTime: u32) Transaction {
        return Transaction{
            .vin = vin,
            .vout = vout,
            .version = version,
            .lockTime = lockTime,
        };
    }

    pub fn isCoinBase() bool { } // TODO

    pub fn hasWitness() bool { } // TODO
};