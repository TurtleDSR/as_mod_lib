const std = @import("std");

//tests
const treetests = @import("lexer/treetests.zig");

const injectortests = @import("injector/injectortests.zig");
const loadertests = @import("injector/loadertests.zig");

comptime {
    std.testing.refAllDecls(treetests);

    std.testing.refAllDecls(injectortests);
    std.testing.refAllDecls(loadertests);
}
