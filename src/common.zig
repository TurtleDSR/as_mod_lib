pub const lexer = @import("lexer");
pub const zip = @import("zip");

pub const keyword = enum {
    open,
    import,
    patch,
    add,
    end,
    comment,
    text,
};