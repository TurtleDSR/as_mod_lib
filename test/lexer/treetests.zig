const std = @import("std");

const modlib = @import("modlib");
const lexertree = modlib.lexer.tree;

test "keyword search" {
    const kw = try lexertree.tree.getKeyword("@patch");
    try std.testing.expect(kw == modlib.keyword.patch);
}
