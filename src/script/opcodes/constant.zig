const std = @import("std");

pub const Opcode = enum(u8) {
    // Constants
    OP_0 = 0x00,
    OP_FALSE = 0x00,
    OP_PUSHDATA1 = 0x4c,
    OP_PUSHDATA2 = 0x4d,
    OP_PUSHDATA4 = 0x4e,
    OP_1NEGATE = 0x4f,
    OP_RESERVED = 0x50,
    OP_1 = 0x51,
    OP_TRUE = 0x51,
    OP_2 = 0x52,
    OP_3 = 0x53,
    OP_4 = 0x54,
    OP_5 = 0x55,
    OP_6 = 0x56,
    OP_7 = 0x57,
    OP_8 = 0x58,
    OP_9 = 0x59,
    OP_10 = 0x5a,
    OP_11 = 0x5b,
    OP_12 = 0x5c,
    OP_13 = 0x5d,
    OP_14 = 0x5e,
    OP_15 = 0x5f,
    OP_16 = 0x60,

    // Flow control
    OP_NOP = 0x61,
    OP_VER = 0x62, // disabled
    OP_IF = 0x63,
    OP_NOTIF = 0x64,
    OP_VERIF = 0x65, // disabled
    OP_VERNOTIF = 0x66, // disabled
    OP_ELSE = 0x67,
    OP_ENDIF = 0x68,
    OP_VERIFY = 0x69,
    OP_RETURN = 0x6a,

    // Stack
    OP_TOALTSTACK = 0x6b,
    OP_FROMALTSTACK = 0x6c,
    OP_2DROP = 0x6d,
    OP_2DUP = 0x6e,
    OP_3DUP = 0x6f,
    OP_2OVER = 0x70,
    OP_2ROT = 0x71,
    OP_2SWAP = 0x72,
    OP_IFDUP = 0x73,
    OP_DEPTH = 0x74,
    OP_DROP = 0x75,
    OP_DUP = 0x76,
    OP_NIP = 0x77,
    OP_OVER = 0x78,
    OP_PICK = 0x79,
    OP_ROLL = 0x7a,
    OP_ROT = 0x7b,
    OP_SWAP = 0x7c,
    OP_TUCK = 0x7d,

    // Data manipulation
    OP_CAT = 0x7e,
    OP_SPLIT = 0x7f,
    OP_NUM2BIN = 0x80,
    OP_BIN2NUM = 0x81,
    OP_SIZE = 0x82,

    // Bitwise logic
    OP_INVERT = 0x83,
    OP_AND = 0x84,
    OP_OR = 0x85,
    OP_XOR = 0x86,
    OP_EQUAL = 0x87,
    OP_EQUALVERIFY = 0x88,
    OP_RESERVED1 = 0x89,
    OP_RESERVED2 = 0x8a,

    // Arithmetic
    OP_1ADD = 0x8b,
    OP_1SUB = 0x8c,
    OP_2MUL = 0x8d, // disabled
    OP_2DIV = 0x8e, // disabled
    OP_NEGATE = 0x8f,
    OP_ABS = 0x90,
    OP_NOT = 0x91,
    OP_0NOTEQUAL = 0x92,
    OP_ADD = 0x93,
    OP_SUB = 0x94,
    OP_MUL = 0x95,
    OP_DIV = 0x96,
    OP_MOD = 0x97,
    OP_LSHIFT = 0x98,
    OP_RSHIFT = 0x99,
    OP_BOOLAND = 0x9a,
    OP_BOOLOR = 0x9b,
    OP_NUMEQUAL = 0x9c,
    OP_NUMEQUALVERIFY = 0x9d,
    OP_NUMNOTEQUAL = 0x9e,
    OP_LESSTHAN = 0x9f,
    OP_GREATERTHAN = 0xa0,
    OP_LESSTHANOREQUAL = 0xa1,
    OP_GREATERTHANOREQUAL = 0xa2,
    OP_MIN = 0xa3,
    OP_MAX = 0xa4,
    OP_WITHIN = 0xa5,

    // Cryptography
    OP_RIPEMD160 = 0xa6,
    OP_SHA1 = 0xa7,
    OP_SHA256 = 0xa8,
    OP_HASH160 = 0xa9,
    OP_HASH256 = 0xaa,
    OP_CODESEPARATOR = 0xab,
    OP_CHECKSIG = 0xac,
    OP_CHECKSIGVERIFY = 0xad,
    OP_CHECKMULTISIG = 0xae,
    OP_CHECKMULTISIGVERIFY = 0xaf,

    // Reserved NOP codes
    OP_NOP1 = 0xb0,
    OP_CHECKLOCKTIMEVERIFY = 0xb1,
    OP_NOP2 = 0xb1,
    OP_CHECKSEQUENCEVERIFY = 0xb2,
    OP_NOP3 = 0xb2,
    OP_NOP4 = 0xb3,
    OP_NOP5 = 0xb4,
    OP_NOP6 = 0xb5,
    OP_NOP7 = 0xb6,
    OP_NOP8 = 0xb7,
    OP_NOP9 = 0xb8,
    OP_NOP10 = 0xb9,

    // Pseudo-words
    OP_PUBKEYHASH = 0xfd,
    OP_PUBKEY = 0xfe,
    OP_INVALIDOPCODE = 0xff,

    pub fn toString(self: Opcode) []const u8 {
        return switch (self) {
            .OP_0, .OP_FALSE => "OP_0",
            .OP_PUSHDATA1 => "OP_PUSHDATA1",
            .OP_PUSHDATA2 => "OP_PUSHDATA2",
            .OP_PUSHDATA4 => "OP_PUSHDATA4",
            .OP_1NEGATE => "OP_1NEGATE",
            .OP_RESERVED => "OP_RESERVED",
            .OP_1, .OP_TRUE => "OP_1",
            .OP_2 => "OP_2",
            .OP_3 => "OP_3",
            .OP_4 => "OP_4",
            .OP_5 => "OP_5",
            .OP_6 => "OP_6",
            .OP_7 => "OP_7",
            .OP_8 => "OP_8",
            .OP_9 => "OP_9",
            .OP_10 => "OP_10",
            .OP_11 => "OP_11",
            .OP_12 => "OP_12",
            .OP_13 => "OP_13",
            .OP_14 => "OP_14",
            .OP_15 => "OP_15",
            .OP_16 => "OP_16",
            .OP_NOP => "OP_NOP",
            .OP_VER => "OP_VER",
            .OP_IF => "OP_IF",
            .OP_NOTIF => "OP_NOTIF",
            .OP_VERIF => "OP_VERIF",
            .OP_VERNOTIF => "OP_VERNOTIF",
            .OP_ELSE => "OP_ELSE",
            .OP_ENDIF => "OP_ENDIF",
            .OP_VERIFY => "OP_VERIFY",
            .OP_RETURN => "OP_RETURN",
            .OP_TOALTSTACK => "OP_TOALTSTACK",
            .OP_FROMALTSTACK => "OP_FROMALTSTACK",
            .OP_2DROP => "OP_2DROP",
            .OP_2DUP => "OP_2DUP",
            .OP_3DUP => "OP_3DUP",
            .OP_2OVER => "OP_2OVER",
            .OP_2ROT => "OP_2ROT",
            .OP_2SWAP => "OP_2SWAP",
            .OP_IFDUP => "OP_IFDUP",
            .OP_DEPTH => "OP_DEPTH",
            .OP_DROP => "OP_DROP",
            .OP_DUP => "OP_DUP",
            .OP_NIP => "OP_NIP",
            .OP_OVER => "OP_OVER",
            .OP_PICK => "OP_PICK",
            .OP_ROLL => "OP_ROLL",
            .OP_ROT => "OP_ROT",
            .OP_SWAP => "OP_SWAP",
            .OP_TUCK => "OP_TUCK",
            .OP_CAT => "OP_CAT",
            .OP_SPLIT => "OP_SPLIT",
            .OP_NUM2BIN => "OP_NUM2BIN",
            .OP_BIN2NUM => "OP_BIN2NUM",
            .OP_SIZE => "OP_SIZE",
            .OP_INVERT => "OP_INVERT",
            .OP_AND => "OP_AND",
            .OP_OR => "OP_OR",
            .OP_XOR => "OP_XOR",
            .OP_EQUAL => "OP_EQUAL",
            .OP_EQUALVERIFY => "OP_EQUALVERIFY",
            .OP_RESERVED1 => "OP_RESERVED1",
            .OP_RESERVED2 => "OP_RESERVED2",
            .OP_1ADD => "OP_1ADD",
            .OP_1SUB => "OP_1SUB",
            .OP_2MUL => "OP_2MUL",
            .OP_2DIV => "OP_2DIV",
            .OP_NEGATE => "OP_NEGATE",
            .OP_ABS => "OP_ABS",
            .OP_NOT => "OP_NOT",
            .OP_0NOTEQUAL => "OP_0NOTEQUAL",
            .OP_ADD => "OP_ADD",
            .OP_SUB => "OP_SUB",
            .OP_MUL => "OP_MUL",
            .OP_DIV => "OP_DIV",
            .OP_MOD => "OP_MOD",
            .OP_LSHIFT => "OP_LSHIFT",
            .OP_RSHIFT => "OP_RSHIFT",
            .OP_BOOLAND => "OP_BOOLAND",
            .OP_BOOLOR => "OP_BOOLOR",
            .OP_NUMEQUAL => "OP_NUMEQUAL",
            .OP_NUMEQUALVERIFY => "OP_NUMEQUALVERIFY",
            .OP_NUMNOTEQUAL => "OP_NUMNOTEQUAL",
            .OP_LESSTHAN => "OP_LESSTHAN",
            .OP_GREATERTHAN => "OP_GREATERTHAN",
            .OP_LESSTHANOREQUAL => "OP_LESSTHANOREQUAL",
            .OP_GREATERTHANOREQUAL => "OP_GREATERTHANOREQUAL",
            .OP_MIN => "OP_MIN",
            .OP_MAX => "OP_MAX",
            .OP_WITHIN => "OP_WITHIN",
            .OP_RIPEMD160 => "OP_RIPEMD160",
            .OP_SHA1 => "OP_SHA1",
            .OP_SHA256 => "OP_SHA256",
            .OP_HASH160 => "OP_HASH160",
            .OP_HASH256 => "OP_HASH256",
            .OP_CODESEPARATOR => "OP_CODESEPARATOR",
            .OP_CHECKSIG => "OP_CHECKSIG",
            .OP_CHECKSIGVERIFY => "OP_CHECKSIGVERIFY",
            .OP_CHECKMULTISIG => "OP_CHECKMULTISIG",
            .OP_CHECKMULTISIGVERIFY => "OP_CHECKMULTISIGVERIFY",
            .OP_NOP1 => "OP_NOP1",
            .OP_CHECKLOCKTIMEVERIFY, .OP_NOP2 => "OP_CHECKLOCKTIMEVERIFY",
            .OP_CHECKSEQUENCEVERIFY, .OP_NOP3 => "OP_CHECKSEQUENCEVERIFY",
            .OP_NOP4 => "OP_NOP4",
            .OP_NOP5 => "OP_NOP5",
            .OP_NOP6 => "OP_NOP6",
            .OP_NOP7 => "OP_NOP7",
            .OP_NOP8 => "OP_NOP8",
            .OP_NOP9 => "OP_NOP9",
            .OP_NOP10 => "OP_NOP10",
            .OP_PUBKEYHASH => "OP_PUBKEYHASH",
            .OP_PUBKEY => "OP_PUBKEY",
            .OP_INVALIDOPCODE => "OP_INVALIDOPCODE",
        };
    }

    pub fn isDisabled(self: Opcode) bool {
        return switch (self) {
            .OP_VER, .OP_VERIF, .OP_VERNOTIF, .OP_2MUL, .OP_2DIV => true,
            else => false,
        };
    }

    pub fn isReserved(self: Opcode) bool {
        return switch (self) {
            .OP_RESERVED, .OP_RESERVED1, .OP_RESERVED2 => true,
            else => false,
        };
    }

    pub fn isPushData(self: Opcode) bool {
        return switch (self) {
            .OP_PUSHDATA1, .OP_PUSHDATA2, .OP_PUSHDATA4 => true,
            else => false,
        };
    }

    pub fn isConditional(self: Opcode) bool {
        return switch (self) {
            .OP_IF, .OP_NOTIF, .OP_ELSE, .OP_ENDIF => true,
            else => false,
        };
    }

    pub fn fromByte(byte: u8) !Opcode {
        return std.meta.intToEnum(Opcode, byte) catch {
            return error.InvalidOpcode;
        };
    }
};

// Helper function to get all opcodes
pub fn getAllOpcodes() []const Opcode {
    return std.enums.values(Opcode);
}

// Helper function to get opcode from string representation
pub fn opcodeFromString(name: []const u8) ?Opcode {
    for (getAllOpcodes()) |opcode| {
        if (std.mem.eql(u8, opcode.toString(), name)) {
            return opcode;
        }
    }
    return null;
}
