// push value
const OP_0 = 0x00;
const OP_FALSE = 0x00;
const OP_PUSHDATA1 = 0x4c;
const OP_PUSHDATA2 = 0x4d;
const OP_PUSHDATA4 = 0x4e;
const OP_1NEGATE = 0x4f;
const OP_RESERVED = 0x50;
const OP_1 = 0x51;
const OP_TRUE= 0x51;
const OP_2 = 0x52;
const OP_3 = 0x53;
const OP_4 = 0x54;
const OP_5 = 0x55;
const OP_6 = 0x56;
const OP_7 = 0x57;
const OP_8 = 0x58;
const OP_9 = 0x59;
const OP_10 = 0x5a;
const OP_11 = 0x5b;
const OP_12 = 0x5c;
const OP_13 = 0x5d;
const OP_14 = 0x5e;
const OP_15 = 0x5f;
const OP_16 = 0x60;

// control
const OP_NOP = 0x61;
const OP_VER = 0x62;
const OP_IF = 0x63;
const OP_NOTIF = 0x64;
const OP_VERIF = 0x65;
const OP_VERNOTIF = 0x66;
const OP_ELSE = 0x67;
const OP_ENDIF = 0x68;
const OP_VERIFY = 0x69;
const OP_RETURN = 0x6a;

// stack ops
const OP_TOALTSTACK = 0x6b;
const OP_FROMALTSTACK = 0x6c;
const OP_2DROP = 0x6d;
const OP_2DUP = 0x6e;
const OP_3DUP = 0x6f;
const OP_2OVER = 0x70;
const OP_2ROT = 0x71;
const OP_2SWAP = 0x72;
const OP_IFDUP = 0x73;
const OP_DEPTH = 0x74;
const OP_DROP = 0x75;
const OP_DUP = 0x76;
const OP_NIP = 0x77;
const OP_OVER = 0x78;
const OP_PICK = 0x79;
const OP_ROLL = 0x7a;
const OP_ROT = 0x7b;
const OP_SWAP = 0x7c;
const OP_TUCK = 0x7d;

// splice ops
const OP_CAT = 0x7e;
const OP_SUBSTR = 0x7f;
const OP_LEFT = 0x80;
const OP_RIGHT = 0x81;
const OP_SIZE = 0x82;

// bit logic
const OP_INVERT = 0x83;
const OP_AND = 0x84;
const OP_OR = 0x85;
const OP_XOR = 0x86;
const OP_EQUAL = 0x87;
const OP_EQUALVERIFY = 0x88;
const OP_RESERVED1 = 0x89;
const OP_RESERVED2 = 0x8a;

// numeric
const OP_1ADD = 0x8b;
const OP_1SUB = 0x8c;
const OP_2MUL = 0x8d;
const OP_2DIV = 0x8e;
const OP_NEGATE = 0x8f;
const OP_ABS = 0x90;
const OP_NOT = 0x91;
const OP_0NOTEQUAL = 0x92;

const OP_ADD = 0x93;
const OP_SUB = 0x94;
const OP_MUL = 0x95;
const OP_DIV = 0x96;
const OP_MOD = 0x97;
const OP_LSHIFT = 0x98;
const OP_RSHIFT = 0x99;

const OP_BOOLAND = 0x9a;
const OP_BOOLOR = 0x9b;
const OP_NUMEQUAL = 0x9c;
const OP_NUMEQUALVERIFY = 0x9d;
const OP_NUMNOTEQUAL = 0x9e;
const OP_LESSTHAN = 0x9f;
const OP_GREATERTHAN = 0xa0;
const OP_LESSTHANOREQUAL = 0xa1;
const OP_GREATERTHANOREQUAL = 0xa2;
const OP_MIN = 0xa3;
const OP_MAX = 0xa4;

const OP_WITHIN = 0xa5;

// crypto
const OP_RIPEMD160 = 0xa6;
const OP_SHA1 = 0xa7;
const OP_SHA256 = 0xa8;
const OP_HASH160 = 0xa9;
const OP_HASH256 = 0xaa;
const OP_CODESEPARATOR = 0xab;
const OP_CHECKSIG = 0xac;
const OP_CHECKSIGVERIFY = 0xad;
const OP_CHECKMULTISIG = 0xae;
const OP_CHECKMULTISIGVERIFY = 0xaf;

// expansion
const OP_NOP1 = 0xb0;
const OP_CHECKLOCKTIMEVERIFY = 0xb1;
const OP_NOP2 = 0xb1;
const OP_CHECKSEQUENCEVERIFY = 0xb2;
const OP_NOP3 = 0xb2;
const OP_NOP4 = 0xb3;
const OP_NOP5 = 0xb4;
const OP_NOP6 = 0xb5;
const OP_NOP7 = 0xb6;
const OP_NOP8 = 0xb7;
const OP_NOP9 = 0xb8;
const OP_NOP10 = 0xb9;

// Opcode added by BIP 342 (Tapscript)
const OP_CHECKSIGADD = 0xba;

const OP_INVALIDOPCODE = 0xff;
