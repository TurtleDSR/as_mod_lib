const lexertree = @import("lexertree.zig");

pub const tree = lexertree.tree;

pub const LexerError = error{
    UnknownKeyword,
};
