pub const zip = @import("zip");
pub const lexer = @import("lexer/lexer.zig");
pub const modlib = @import("handle/modlib.zig");
pub const mod = @import("handle/mod.zig");

//structs
pub const ModLib = modlib.ModLib;
pub const Mod = mod.Mod;

pub const Keyword = enum {
    //operations
    open,
    import,
    patch,
    add,
    end,
    comment,

    //scope
    GLOBAL,
    CLASS,
    FUNCTION,
    PROPERTY,
    ENUM,

    //misc
    _text, //can either be angelscript or plain text, implied by context.
    _newline, //used to maintain code readability and as compile-ability
    _null, //no-op, used as a default value for the token struct.
};

pub const InjectorError = error{
    FileNotFound,
    FileOpenFailure,
    FileReadError,
    FileWriteError,
    UnknownError,
    OutOfMemory,
    MissingDependency,
    ThreadingError,
    SyntaxError,
};

pub const ModHandleError = error{
    FileNotFound,
    FileOpenFailure,
    FileReadError,
    FileWriteError,
    PropertiesOpenError,
    PropertiesReadError,
    PropertiesParseError,
    UnknownError,
    OutOfMemoryError,
};

pub const ModFormat = enum {
    HAZEMOD,
    ZIP,
};
