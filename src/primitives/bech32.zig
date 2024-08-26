const std = @import("std");
const Allocator = std.mem.Allocator;

/// The character set used in the data section of bech32 strings.
const charset = "qpzry9x8gf2tvdw0s3jn54khce6mua7l";

/// Generator polynomial for the bech32 BCH checksum.
const generator = [_]u32{ 0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3 };

/// Bech32 checksum versions
pub const Version = enum {
    v0,
    m,
    unknown,
};

/// Error type for bech32 operations
pub const Bech32Error = error{
    InvalidLength,
    InvalidCharacter,
    InvalidSeparatorIndex,
    InvalidChecksum,
    MixedCase,
    NonCharsetChar,
    InvalidDataByte,
    InvalidBitGroups,
    InvalidIncompleteGroup,
    OutOfMemory,
};

/// Converts a string to a byte slice where each byte is the index of the corresponding character in 'charset'.
fn toBytes(str: []const u8) Bech32Error![]const u8 {
    for (str) |c| {
        if (std.mem.indexOfScalar(u8, charset, c) == null) {
            return Bech32Error.NonCharsetChar;
        }
    }
    return str;
}

/// Calculates the BCH checksum for a given HRP and data.
fn bech32Polymod(values: []const u8) u32 {
    var chk: u32 = 1;
    for (values) |v| {
        const top = chk >> 25;
        chk = (chk & 0x1ffffff) << 5 ^ v;
        for (generator, 0..) |g, i| {
            if (((top >> @as(u5, @intCast(i))) & 1) == 1) {
                chk ^= g;
            }
        }
    }
    return chk;
}

/// Expands the human-readable part for use in checksum computation.
fn hrpExpand(hrp: []const u8, allocator: Allocator) ![]u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, hrp.len * 2 + 1);
    errdefer result.deinit();

    for (hrp) |c| {
        try result.append(c >> 5);
    }
    try result.append(0);
    for (hrp) |c| {
        try result.append(c & 31);
    }
    return result.toOwnedSlice();
}

/// Verifies the checksum of a bech32 string.
fn verifyChecksum(hrp: []const u8, data: []const u8, allocator: Allocator) !Version {
    var combined = std.ArrayList(u8).init(allocator);
    defer combined.deinit();

    const expanded_hrp = try hrpExpand(hrp, allocator);
    defer allocator.free(expanded_hrp);

    try combined.appendSlice(expanded_hrp);
    try combined.appendSlice(data);

    const polymod = bech32Polymod(combined.items);

    return switch (polymod) {
        1 => .v0,
        0x2bc830a3 => .m,
        else => .unknown,
    };
}

/// Encodes data into a bech32 string.
pub fn encode(hrp: []const u8, data: []const u8, version: Version, allocator: Allocator) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    // Convert HRP to lowercase
    const lower_hrp = try std.ascii.allocLowerString(allocator, hrp);
    defer allocator.free(lower_hrp);

    try result.appendSlice(lower_hrp);
    try result.append('1');

    for (data) |b| {
        if (b >= charset.len) {
            return Bech32Error.InvalidDataByte;
        }
        try result.append(charset[b]);
    }

    const expanded_hrp = try hrpExpand(lower_hrp, allocator);
    defer allocator.free(expanded_hrp);

    var combined = std.ArrayList(u8).init(allocator);
    defer combined.deinit();

    try combined.appendSlice(expanded_hrp);
    try combined.appendSlice(data);

    const checksum = switch (version) {
        .v0 => bech32Polymod(combined.items) ^ 1,
        .m => bech32Polymod(combined.items) ^ 0x2bc830a3,
        .unknown => unreachable,
    };

    var i: usize = 0;
    while (i < 6) : (i += 1) {
        const b = @as(u8, @intCast((checksum >> @as(u5, @intCast(5 * (5 - i)))) & 31));
        try result.append(charset[b]);
    }

    return result.toOwnedSlice();
}

/// Decodes a bech32 encoded string.
pub fn decode(bech: []const u8, allocator: Allocator) !struct { hrp: []u8, data: []u8, version: Version } {
    if (bech.len < 8 or bech.len > 90) {
        return Bech32Error.InvalidLength;
    }

    var has_lower = false;
    var has_upper = false;

    for (bech) |c| {
        if (c < 33 or c > 126) {
            return Bech32Error.InvalidCharacter;
        }
        if (c >= 'a' and c <= 'z') {
            has_lower = true;
        }
        if (c >= 'A' and c <= 'Z') {
            has_upper = true;
        }
    }

    if (has_lower and has_upper) {
        return Bech32Error.MixedCase;
    }

    const lower_bech = try std.ascii.allocLowerString(allocator, bech);
    defer allocator.free(lower_bech);

    const one_index = std.mem.lastIndexOfScalar(u8, lower_bech, '1') orelse return Bech32Error.InvalidSeparatorIndex;
    if (one_index < 1 or one_index + 7 > lower_bech.len) {
        return Bech32Error.InvalidSeparatorIndex;
    }

    const hrp = try allocator.dupe(u8, lower_bech[0..one_index]);
    errdefer allocator.free(hrp);

    const data_part = lower_bech[one_index + 1 ..];
    const decoded = try toBytes(data_part);

    const version = try verifyChecksum(hrp, decoded, allocator);
    if (version == .unknown) {
        return Bech32Error.InvalidChecksum;
    }

    var data = try allocator.alloc(u8, decoded.len - 6);
    for (decoded[0 .. decoded.len - 6], 0..) |c, i| {
        data[i] = @as(u8, @intCast(std.mem.indexOfScalar(u8, charset, c) orelse return Bech32Error.NonCharsetChar));
    }

    return .{
        .hrp = hrp,
        .data = data,
        .version = version,
    };
}

/// Converts data from one bit size to another.
pub fn convertBits(data: []const u8, from_bits: u8, to_bits: u8, pad: bool, allocator: Allocator) ![]u8 {
    if (from_bits < 1 or from_bits > 8 or to_bits < 1 or to_bits > 8) {
        return Bech32Error.InvalidBitGroups;
    }

    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    var acc: u32 = 0;
    var bits: u32 = 0;
    const max_v: u32 = (@as(u32, 1) << @as(u5, @intCast(to_bits))) - 1;

    for (data) |v| {
        const max_input_value = (@as(u32, 1) << @as(u5, @intCast(from_bits))) - 1;
        if (v > max_input_value) {
            return Bech32Error.InvalidDataByte;
        }
        acc = (acc << @as(u5, @intCast(from_bits))) | v;
        bits += from_bits;
        while (bits >= to_bits) {
            bits -= to_bits;
            try result.append(@as(u8, @intCast((acc >> @as(u5, @intCast(bits))) & max_v)));
        }
    }

    if (pad) {
        if (bits > 0) {
            try result.append(@as(u8, @intCast((acc << @as(u5, @intCast(to_bits - bits))) & max_v)));
        }
    } else if (bits >= from_bits or ((acc << @as(u5, @intCast(to_bits - bits))) & max_v) != 0) {
        return Bech32Error.InvalidIncompleteGroup;
    }

    return result.toOwnedSlice();
}

/// Encodes a byte slice into a bech32 string, converting from base256 to base32 first.
pub fn encodeFromBase256(hrp: []const u8, data: []const u8, version: Version, allocator: Allocator) ![]u8 {
    const converted = try convertBits(data, 8, 5, true, allocator);
    defer allocator.free(converted);
    return encode(hrp, converted, version, allocator);
}

/// Decodes a bech32 string and converts the data from base32 to base256.
pub fn decodeToBase256(bech: []const u8, allocator: Allocator) !struct { hrp: []u8, data: []u8 } {
    const decoded = try decode(bech, allocator);
    defer allocator.free(decoded.hrp);
    defer allocator.free(decoded.data);

    const converted = try convertBits(decoded.data, 5, 8, false, allocator);
    errdefer allocator.free(converted);

    return .{
        .hrp = try allocator.dupe(u8, decoded.hrp),
        .data = converted,
    };
}

const testing = std.testing;

test "bech32 decode" {
    const allocator = testing.allocator;

    const TestVector = struct {
        input: []const u8,
        expected_hrp: []const u8,
        expected_data: []const u8,
        expected_version: Version,
    };

    const test_vectors = [_]TestVector{
        .{ .input = "A12UEL5L", .expected_hrp = "a", .expected_data = "", .expected_version = .v0 },
        .{ .input = "a12uel5l", .expected_hrp = "a", .expected_data = "", .expected_version = .v0 },
        .{ .input = "an83characterlonghumanreadablepartthatcontainsthenumber1andtheexcludedcharactersbio1tt5tgs", .expected_hrp = "an83characterlonghumanreadablepartthatcontainsthenumber1andtheexcludedcharactersbio", .expected_data = "", .expected_version = .v0 },
        .{ .input = "abcdef1qpzry9x8gf2tvdw0s3jn54khce6mua7lmqqqxw", .expected_hrp = "abcdef", .expected_data = "\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f", .expected_version = .v0 },
        .{ .input = "11qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqc8247j", .expected_hrp = "1", .expected_data = &[_]u8{0} ** 50, .expected_version = .v0 },
        .{ .input = "split1checkupstagehandshakeupstreamerranterredcaperred2y9e3w", .expected_hrp = "split", .expected_data = "\x18\x1c\x0e\x14\x08\x06\x16\x1c\x06\x1f\x17\x18\x02\x1d\x05\x1a\x14\x00\x1c\x1a\x16\x19\x02\x05\x1e\x18\x17\x1b\x19\x06\x02\x0e", .expected_version = .v0 },
        .{ .input = "?1v759aa", .expected_hrp = "?", .expected_data = "\x1f\x1d\x0e\x1a\x0b", .expected_version = .m },
    };

    for (test_vectors) |vector| {
        const result = try decode(vector.input, allocator);
        defer allocator.free(result.hrp);
        defer allocator.free(result.data);

        try testing.expectEqualStrings(vector.expected_hrp, result.hrp);
        try testing.expectEqualSlices(u8, vector.expected_data, result.data);
        try testing.expectEqual(vector.expected_version, result.version);
    }
}

test "bech32 decode errors" {
    const allocator = testing.allocator;

    const TestVector = struct {
        input: []const u8,
        expected_error: anyerror,
    };

    const test_vectors = [_]TestVector{
        .{ .input = "split1checkupstagehandshakeupstreamerranterredcaperred2y9e2w", .expected_error = Bech32Error.InvalidChecksum },
        .{ .input = "s lit1checkupstagehandshakeupstreamerranterredcaperredp8hs2p", .expected_error = Bech32Error.InvalidCharacter },
        .{ .input = "spl\x7ft1checkupstagehandshakeupstreamerranterredcaperred2y9e3w", .expected_error = Bech32Error.InvalidCharacter },
        .{ .input = "split1cheo2y9e2w", .expected_error = Bech32Error.NonCharsetChar },
        .{ .input = "split1a2y9w", .expected_error = Bech32Error.InvalidSeparatorIndex },
        .{ .input = "1checkupstagehandshakeupstreamerranterredcaperred2y9e3w", .expected_error = Bech32Error.InvalidSeparatorIndex },
        .{ .input = "11qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqc8247j", .expected_error = Bech32Error.InvalidLength },
        .{ .input = "mzl49c", .expected_error = Bech32Error.InvalidLength },
        .{ .input = "split1checkupstagehandshakeupstreamerranterredcaperred2y9e3w", .expected_error = Bech32Error.InvalidChecksum },
        .{ .input = "split1checkupstagehandshakeupstreamerranterredcaperred2y9e3w", .expected_error = Bech32Error.InvalidChecksum },
        .{ .input = "s lit1checkupstagehandshakeupstreamerranterredcaperredp8hs2p", .expected_error = Bech32Error.InvalidCharacter },
        .{ .input = "spl\x7ft1checkupstagehandshakeupstreamerranterredcaperred2y9e3w", .expected_error = Bech32Error.InvalidCharacter },
        .{ .input = "split1cheo2y9e2w", .expected_error = Bech32Error.NonCharsetChar },
        .{ .input = "split1a2y9w", .expected_error = Bech32Error.InvalidSeparatorIndex },
        .{ .input = "1checkupstagehandshakeupstreamerranterredcaperred2y9e3w", .expected_error = Bech32Error.InvalidSeparatorIndex },
        .{ .input = "11qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqc8247j", .expected_error = Bech32Error.InvalidLength },
        .{ .input = "li1dgmt3", .expected_error = Bech32Error.InvalidSeparatorIndex },
        .{ .input = "de1lg7wt\xff", .expected_error = Bech32Error.InvalidCharacter },
        .{ .input = "A1G7SGD8", .expected_error = Bech32Error.InvalidChecksum },
        .{ .input = "10a06t8", .expected_error = Bech32Error.InvalidLength },
        .{ .input = "1qzzfhee", .expected_error = Bech32Error.InvalidSeparatorIndex },
    };

    for (test_vectors) |vector| {
        const result = decode(vector.input, allocator);
        try testing.expectError(vector.expected_error, result);
    }
}

test "bech32 encode" {
    const allocator = testing.allocator;

    const TestVector = struct {
        hrp: []const u8,
        data: []const u8,
        version: Version,
        expected: []const u8,
    };

    const test_vectors = [_]TestVector{
        //.{ .hrp = "a", .data = "", .version = .v0, .expected = "a12uel5l" },
        .{ .hrp = "an83characterlonghumanreadablepartthatcontainsthenumber1andtheexcludedcharactersbio", .data = "", .version = .v0, .expected = "an83characterlonghumanreadablepartthatcontainsthenumber1andtheexcludedcharactersbio1tt5tgs" },
        .{ .hrp = "abcdef", .data = "\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0a\x0b\x0c\x0d\x0e\x0f\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f", .version = .v0, .expected = "abcdef1qpzry9x8gf2tvdw0s3jn54khce6mua7lmqqqxw" },
        .{ .hrp = "1", .data = &[_]u8{0} ** 50, .version = .v0, .expected = "11qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqc8247j" },
        .{ .hrp = "split", .data = "\x18\x1c\x0e\x14\x08\x06\x16\x1c\x06\x1f\x17\x18\x02\x1d\x05\x1a\x14\x00\x1c\x1a\x16\x19\x02\x05\x1e\x18\x17\x1b\x19\x06\x02\x0e", .version = .v0, .expected = "split1checkupstagehandshakeupstreamerranterredcaperred2y9e3w" },
        .{ .hrp = "?", .data = "\x1f\x1d\x0e\x1a\x0b", .version = .m, .expected = "?1v759aa" },
    };

    for (test_vectors) |vector| {
        const result = try encode(vector.hrp, vector.data, vector.version, allocator);
        defer allocator.free(result);

        try testing.expectEqualStrings(vector.expected, result);
    }
}

test "bech32 encode errors" {
    const allocator = testing.allocator;

    const TestVector = struct {
        hrp: []const u8,
        data: []const u8,
        version: Version,
        expected_error: anyerror,
    };

    const test_vectors = [_]TestVector{
        .{ .hrp = "a", .data = &[_]u8{32}, .version = .v0, .expected_error = Bech32Error.InvalidDataByte },
    };

    for (test_vectors) |vector| {
        const result = encode(vector.hrp, vector.data, vector.version, allocator);
        try testing.expectError(vector.expected_error, result);
    }
}

test "bech32 convert bits" {
    const allocator = testing.allocator;

    const TestVector = struct {
        input: []const u8,
        from_bits: u8,
        to_bits: u8,
        pad: bool,
        expected: []const u8,
    };

    const test_vectors = [_]TestVector{
        .{ .input = "", .from_bits = 8, .to_bits = 5, .pad = false, .expected = "" },
        .{ .input = "", .from_bits = 8, .to_bits = 5, .pad = true, .expected = "" },
        .{ .input = "", .from_bits = 5, .to_bits = 8, .pad = false, .expected = "" },
        .{ .input = "", .from_bits = 5, .to_bits = 8, .pad = true, .expected = "" },
        .{ .input = "\x00", .from_bits = 8, .to_bits = 5, .pad = false, .expected = "\x00" },
        .{ .input = "\x00", .from_bits = 8, .to_bits = 5, .pad = true, .expected = "\x00\x00" },
        .{ .input = "\x00\x00", .from_bits = 5, .to_bits = 8, .pad = false, .expected = "\x00" },
        .{ .input = "\x00\x00", .from_bits = 5, .to_bits = 8, .pad = true, .expected = "\x00\x00" },
        .{ .input = "\xff\xff\xff", .from_bits = 8, .to_bits = 5, .pad = true, .expected = "\x1f\x1f\x1f\x1f\x1e" },
        .{ .input = "\x1f\x1f\x1f\x1f\x1e", .from_bits = 5, .to_bits = 8, .pad = false, .expected = "\xff\xff\xff" },
        .{ .input = "\x1f\x1f\x1f\x1f\x1e", .from_bits = 5, .to_bits = 8, .pad = true, .expected = "\xff\xff\xff\x00" },
        .{ .input = "\xc9\xca", .from_bits = 8, .to_bits = 5, .pad = false, .expected = "\x19\x07\x05" },
        .{ .input = "\xc9\xca", .from_bits = 8, .to_bits = 5, .pad = true, .expected = "\x19\x07\x05\x00" },
        .{ .input = "\x19\x07\x05\x00", .from_bits = 5, .to_bits = 8, .pad = false, .expected = "\xc9\xca" },
        .{ .input = "\x19\x07\x05\x00", .from_bits = 5, .to_bits = 8, .pad = true, .expected = "\xc9\xca\x00" },
    };

    for (test_vectors) |vector| {
        const result = try convertBits(vector.input, vector.from_bits, vector.to_bits, vector.pad, allocator);
        defer allocator.free(result);

        try testing.expectEqualSlices(u8, vector.expected, result);
    }
}
