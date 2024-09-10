/// Copied from: https://github.com/Hejsil/aniz/blob/master/src/ArgParser.zig
/// TODO: Move to using zig-clap as dependency
/// https://github.com/Hejsil/zig-clap
args: []const []const u8,
index: usize = 0,

consumed: bool = false,

pub fn next(parser: *ArgParser) bool {
    parser.consumed = parser.index >= parser.args.len;
    return !parser.consumed;
}

pub fn flag(parser: *ArgParser, names: []const []const u8) bool {
    if (parser.consumed)
        return false;

    for (names) |name| {
        if (!std.mem.eql(u8, parser.args[parser.index], name))
            continue;

        parser.consumed = true;
        parser.index += 1;
        return true;
    }

    return false;
}

pub fn option(parser: *ArgParser, names: []const []const u8) ?[]const u8 {
    if (parser.consumed)
        return null;

    const arg = parser.args[parser.index];
    for (names) |name| {
        if (!std.mem.startsWith(u8, arg, name))
            continue;
        if (!std.mem.startsWith(u8, arg[name.len..], "="))
            continue;

        parser.consumed = true;
        parser.index += 1;
        return arg[name.len + 1 ..];
    }

    if (parser.index + 1 < parser.args.len) {
        if (parser.flag(names))
            return parser.eat();
    }

    return null;
}

pub fn positional(parser: *ArgParser) ?[]const u8 {
    if (parser.consumed)
        return null;

    return parser.eat();
}

fn eat(parser: *ArgParser) []const u8 {
    defer parser.index += 1;
    return parser.args[parser.index];
}

test flag {
    var parser = ArgParser{ .args = &.{
        "-a", "--beta", "command",
    } };

    try std.testing.expect(parser.flag(&.{ "-a", "--alpha" }));
    try std.testing.expect(!parser.flag(&.{ "-b", "--beta" }));
    try std.testing.expect(!parser.flag(&.{"command"}));

    try std.testing.expect(parser.next());
    try std.testing.expect(!parser.flag(&.{ "-a", "--alpha" }));
    try std.testing.expect(parser.flag(&.{ "-b", "--beta" }));
    try std.testing.expect(!parser.flag(&.{"command"}));

    try std.testing.expect(parser.next());
    try std.testing.expect(!parser.flag(&.{ "-a", "--alpha" }));
    try std.testing.expect(!parser.flag(&.{ "-b", "--beta" }));
    try std.testing.expect(parser.flag(&.{"command"}));

    try std.testing.expect(!parser.next());
    try std.testing.expect(!parser.flag(&.{ "-a", "--alpha" }));
    try std.testing.expect(!parser.flag(&.{ "-b", "--beta" }));
    try std.testing.expect(!parser.flag(&.{"command"}));
}

fn expectEqualOptionalString(m_expect: ?[]const u8, m_actual: ?[]const u8) !void {
    if (m_expect) |expect| {
        try std.testing.expect(m_actual != null);
        try std.testing.expectEqualStrings(expect, m_actual.?);
    } else {
        try std.testing.expect(m_actual == null);
    }
}

test option {
    var parser = ArgParser{ .args = &.{
        "-a",
        "a_value",
        "--beta=b_value",
        "command",
        "command_value",
    } };

    try expectEqualOptionalString("a_value", parser.option(&.{ "-a", "--alpha" }));
    try expectEqualOptionalString(null, parser.option(&.{ "-b", "--beta" }));
    try expectEqualOptionalString(null, parser.option(&.{"command"}));

    try std.testing.expect(parser.next());
    try expectEqualOptionalString(null, parser.option(&.{ "-a", "--alpha" }));
    try expectEqualOptionalString("b_value", parser.option(&.{ "-b", "--beta" }));
    try expectEqualOptionalString(null, parser.option(&.{"command"}));

    try std.testing.expect(parser.next());
    try expectEqualOptionalString(null, parser.option(&.{ "-a", "--alpha" }));
    try expectEqualOptionalString(null, parser.option(&.{ "-b", "--beta" }));
    try expectEqualOptionalString("command_value", parser.option(&.{"command"}));

    try std.testing.expect(!parser.next());
    try expectEqualOptionalString(null, parser.option(&.{ "-a", "--alpha" }));
    try expectEqualOptionalString(null, parser.option(&.{ "-b", "--beta" }));
    try expectEqualOptionalString(null, parser.option(&.{"command"}));
}

test positional {
    var parser = ArgParser{ .args = &.{
        "-a",
        "--beta",
        "command",
    } };

    try expectEqualOptionalString("-a", parser.positional());
    try std.testing.expect(parser.next());
    try expectEqualOptionalString("--beta", parser.positional());
    try std.testing.expect(parser.next());
    try expectEqualOptionalString("command", parser.positional());
    try std.testing.expect(!parser.next());
    try expectEqualOptionalString(null, parser.positional());
}

test "all" {
    var parser = ArgParser{ .args = &.{
        "-a",
        "--beta",
        "b_value",
        "-c=c_value",
        "command",
    } };

    try std.testing.expect(parser.flag(&.{ "-a", "--alpha" }));
    try expectEqualOptionalString(null, parser.option(&.{ "-b", "--beta" }));
    try expectEqualOptionalString(null, parser.option(&.{ "-c", "--center" }));
    try expectEqualOptionalString(null, parser.positional());

    try std.testing.expect(parser.next());
    try std.testing.expect(!parser.flag(&.{ "-a", "--alpha" }));
    try expectEqualOptionalString("b_value", parser.option(&.{ "-b", "--beta" }));
    try expectEqualOptionalString(null, parser.option(&.{ "-c", "--center" }));
    try expectEqualOptionalString(null, parser.positional());

    try std.testing.expect(parser.next());
    try std.testing.expect(!parser.flag(&.{ "-a", "--alpha" }));
    try expectEqualOptionalString(null, parser.option(&.{ "-b", "--beta" }));
    try expectEqualOptionalString("c_value", parser.option(&.{ "-c", "--center" }));
    try expectEqualOptionalString(null, parser.positional());

    try std.testing.expect(parser.next());
    try std.testing.expect(!parser.flag(&.{ "-a", "--alpha" }));
    try expectEqualOptionalString(null, parser.option(&.{ "-b", "--beta" }));
    try expectEqualOptionalString(null, parser.option(&.{ "-c", "--center" }));
    try expectEqualOptionalString("command", parser.positional());

    try std.testing.expect(!parser.next());
    try std.testing.expect(!parser.flag(&.{ "-a", "--alpha" }));
    try expectEqualOptionalString(null, parser.option(&.{ "-b", "--beta" }));
    try expectEqualOptionalString(null, parser.option(&.{ "-c", "--center" }));
    try expectEqualOptionalString(null, parser.positional());
}

const ArgParser = @This();

const std = @import("std");
