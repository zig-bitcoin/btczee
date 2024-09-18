const std = @import("std");
pub const engine = @import("engine.zig");
pub const stack = @import("stack.zig");
pub const arithmetic = @import("opcodes/arithmetic.zig");
const StackError = @import("stack.zig").StackError;

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

/// Errors that can occur during script execution
pub const EngineError = error{
    /// Script ended unexpectedly
    ScriptTooShort,
    /// OP_VERIFY failed
    VerifyFailed,
    /// OP_RETURN encountered
    EarlyReturn,
    /// Encountered an unknown opcode
    UnknownOpcode,
    /// Encountered a disabled opcode
    DisabledOpcode,
} || StackError;

pub const ScriptNum = struct {
    pub const InnerReprType = i36;

    value: Self.InnerReprType,

    const Self = @This();

    pub fn toBytes(self: Self, allocator: std.mem.Allocator) ![]u8 {
        if (self.value == 0) {
            return allocator.alloc(u8, 0);
        }

        const is_negative = self.value < 0;
        const bytes: [8]u8 = @bitCast(std.mem.nativeToLittle(u64, @abs(self.value)));

        var i: usize = 8;
        while (i > 0) {
            i -= 1;
            if (bytes[i] != 0) {
                i = i;
                break;
            }
        }
        const additional_byte: usize = @intFromBool(bytes[i] & 0x80 != 0);
        var elem = try allocator.alloc(u8, i + 1 + additional_byte);
        errdefer allocator.free(elem);

        @memcpy(elem[0 .. i + 1], bytes[0 .. i + 1]);
        if (is_negative) {
            elem[elem.len - 1] |= 0x80;
        }

        return elem;
    }

    pub fn fromBytes(bytes: []u8) !Self {
        if (bytes.len > 4) {
            return StackError.InvalidValue;
        }
        if (bytes.len == 0) {
            return .{ .value = 0 };
        }

        const is_negative = if (bytes[bytes.len - 1] & 0x80 != 0) true else false;
        bytes[bytes.len - 1] &= 0x7f;

        const abs_value = std.mem.readVarInt(i32, bytes, .little);

        return .{ .value = if (is_negative) -abs_value else abs_value };
    }

    pub fn add(self: Self, rhs: Self) Self {
        const result = std.math.add(Self.InnerReprType, self.value, rhs.value) catch unreachable;
        return .{ .value = result };
    }
    pub fn sub(self: Self, rhs: Self) Self {
        const result = std.math.sub(Self.InnerReprType, self.value, rhs.value) catch unreachable;
        return .{ .value = result };
    }
    pub fn addOne(self: Self) Self {
        const result = std.math.add(Self.InnerReprType, self.value, 1) catch unreachable;
        return .{ .value = result };
    }
    pub fn subOne(self: Self) Self {
        const result = std.math.sub(Self.InnerReprType, self.value, 1) catch unreachable;
        return .{ .value = result };
    }
    pub fn abs(self: Self) Self {
        return if (self.value < 0) .{ .value = std.math.negate(self.value) catch unreachable } else self;
    }
    pub fn negate(self: Self) Self {
        return .{ .value = std.math.negate(self.value) catch unreachable };
    }
};
