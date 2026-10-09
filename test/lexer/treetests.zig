const std = @import("std");

const modlib = @import("modlib");
const lexertree = @import("lexertree");

test "keyword search" {
    const kw = try lexertree.tree.getKeyword("@patch");
    try std.testing.expect(kw == modlib.keyword.patch);
}
