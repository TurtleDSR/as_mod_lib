const std = @import("std");

//tests
const treetests = @import("lexer/treetests.zig");
const injectortests = @import("injectortests.zig");

comptime {
    std.testing.refAllDecls(treetests);
    std.testing.refAllDecls(injectortests);
}