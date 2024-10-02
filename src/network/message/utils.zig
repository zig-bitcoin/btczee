const std = @import("std");

pub fn convertIPv4ToIPv6(address: std.net.Address) std.net.Address {
    // Convert IPv4 to IPv6-mapped IPv4 address
    const ipv4_address = address.in;

    var ipv6_mapped: [16]u8 = [_]u8{0} ** 16;

    // Set bytes 10 and 11 to 0xff
    ipv6_mapped[10] = 0xff;
    ipv6_mapped[11] = 0xff;

    // Copy the IPv4 address into the last 4 bytes of the IPv6-mapped address
    const ipv4_bytes = std.mem.asBytes(&ipv4_address.sa.addr);
    @memcpy(ipv6_mapped[12..16], ipv4_bytes[0..4]);

    return std.net.Address.initIp6(ipv6_mapped, ipv4_address.getPort(), 0, 0);
}
