pub const engine = @import("engine.zig");
pub const stack = @import("stack.zig");
pub const arithmetic = @import("opcodes/arithmetic.zig");
pub const cond_stack = @import("cond_stack.zig");

/// Maximum number of bytes pushable to the stack
const MAX_SCRIPT_ELEMENT_SIZE = 520;

/// Maximum number of non-push operations per script
const MAX_OPS_PER_SCRIPT = 201;

/// Maximum number of public keys per multisig
const MAX_PUBKEYS_PER_MULTISIG = 20;

/// Maximum script length in bytes
const MAX_SCRIPT_SIZE = 10000;

/// Maximum number of values on execution stack
const MAX_STACK_SIZE = 1000;

/// Arithmetic opcodes can't take inputs larger than this
const MAX_SCRIPT_NUM_LENGTH = 4;

/// ScriptFlags represents flags for verifying scripts
pub const ScriptFlags = packed struct {
    verify_none: bool = false,
    verify_p2sh: bool = false,
    verify_strictenc: bool = false,
    verify_dersig: bool = false,
    verify_low_s: bool = false,
    verify_nulldummy: bool = false,
    verify_sigpushonly: bool = false,
    verify_minimaldata: bool = false,
    verify_discourage_upgradable_nops: bool = false,
    verify_cleanstack: bool = false,
    verify_checklocktimeverify: bool = false,
    verify_checksequenceverify: bool = false,
    verify_witness: bool = false,
    verify_discourage_upgradable_witness_program: bool = false,
    verify_minimalif: bool = false,
    verify_nullfail: bool = false,
    verify_witness_pubkeytype: bool = false,
    verify_const_scriptcode: bool = false,
};

/// Represents a Bitcoin script
pub const Script = struct {
    data: []const u8,

    /// Initialize a new Script from bytes
    pub fn init(data: []const u8) Script {
        return .{ .data = data };
    }

    /// Get the length of the script
    pub fn len(self: Script) usize {
        return self.data.len;
    }

    /// Check if the script is empty
    pub fn isEmpty(self: Script) bool {
        return self.len() == 0;
    }
};
