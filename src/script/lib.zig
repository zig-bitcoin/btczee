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
/// A struct allowing for safe reading and writing of bitcoin numbers as well as performing mathematical operations.
///
/// Bitcoin numbers are represented on the stack as 0 to 4 bytes little endian variable-lenght integer,
/// with the most significant bit reserved for the sign flag.
/// In the msb is already used an additionnal bytes will be added to carry the flag.
/// Eg. 0xff is encoded as [0xff, 0x00].
///
/// Thus both `0x80` and `0x00` can be read as zero, while it should be written as [0]u8{}.
/// It also implies that the largest negative number representable is not i32.MIN but i32.MIN + 1 == -i32.MAX.
///
/// The mathematical operation performed on those number are allowd to overflow, making the result expand to 5 bytes.
/// Eg. ScriptNum.MAX + 1 will be encoded [0x0, 0x0, 0x0. 0x80, 0x0].
/// Those overflowed value can successfully be writen back onto the stack as [5]u8, but any attempt to read them bac
/// as number will fail. They can still be read in other way tho (bool, array, etc).
///
/// In order to handle this possibility of overflow the ScripNum are internally represented as i36, not i32.
pub const ScriptNum = struct {
    /// The type used to internaly represent and do math onto the ScriptNum
    pub const InnerReprType = i36;
    /// The greatest valid number handled by the protocol
    pub const MAX: i32 = std.math.maxInt(i32);
    /// The lowest valid number handled by the protocol
    pub const MIN: i32 = std.math.minInt(i32) + 1;

    value: Self.InnerReprType,

    const Self = @This();

    /// Encode `Self.value` as variable-lenght integer
    ///
    /// In case of overflow, it can return as much as 5 bytes.
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
        for (0..elem.len) |idx| elem[idx] = 0;

        @memcpy(elem[0 .. i + 1], bytes[0 .. i + 1]);
        if (is_negative) {
            elem[elem.len - 1] |= 0x80;
        }

        return elem;
    }

    /// Decode a variable-length integer as an instance of Self
    ///
    /// Will error if the input does not represent an int beetween ScriptNum.MIN and ScriptNum.MAX,
    /// meaning that it cannot read back overflown numbers.
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

    /// Add `rhs` to `self`
    ///
    /// * Safety: both arguments should be valid Bitcoin integer values (non overflown)
    pub fn add(self: Self, rhs: Self) Self {
        const result = std.math.add(Self.InnerReprType, self.value, rhs.value) catch unreachable;
        return .{ .value = result };
    }
    /// Substract `rhs` to `self`
    ///
    /// * Safety: both arguments should be valid Bitcoin integer values (non overflown)
    pub fn sub(self: Self, rhs: Self) Self {
        const result = std.math.sub(Self.InnerReprType, self.value, rhs.value) catch unreachable;
        return .{ .value = result };
    }
    /// Increment `self` by 1
    ///
    /// * Safety: `self` should be a valid Bitcoin integer values (non overflown)
    pub fn addOne(self: Self) Self {
        const result = std.math.add(Self.InnerReprType, self.value, 1) catch unreachable;
        return .{ .value = result };
    }
    /// Decrement `self` by 1
    ///
    /// * Safety: `self` should be a valid Bitcoin integer values (non overflown)
    pub fn subOne(self: Self) Self {
        const result = std.math.sub(Self.InnerReprType, self.value, 1) catch unreachable;
        return .{ .value = result };
    }
    /// Return the absolute value of `self`
    ///
    /// * Safety: `self` should be a valid Bitcoin integer values (non overflown)
    pub fn abs(self: Self) Self {
        return if (self.value < 0) .{ .value = std.math.negate(self.value) catch unreachable } else self;
    }
    /// Return the opposite of `self`
    ///
    /// * Safety: `self` should be a valid Bitcoin integer values (non overflown)
    pub fn negate(self: Self) Self {
        return .{ .value = std.math.negate(self.value) catch unreachable };
    }
};
