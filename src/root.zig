const std = @import("std");

pub const lexer = @import("lexer");

pub const keyword = enum {
    open,
    import,
    patch,
    add,
    end,
    comment,
};