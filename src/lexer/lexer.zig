const lexertree = @import("tree");

pub const tree = lexertree.tree;

pub const LexerError = error{
    UnknownKeyword,
};