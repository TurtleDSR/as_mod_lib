const std = @import("std");

const common = @import("common");
const lexertree = common.lexer.tree;

test "keyword search" {
    const kw = try lexertree.getKeyword("@patch");
    try std.testing.expect(kw == common.keyword.patch);
}