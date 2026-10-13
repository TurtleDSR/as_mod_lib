const std = @import("std");

pub const zip = @import("zip");
pub const lexer = @import("lexer/lexer.zig");
pub const modlib = @import("handle/modlib.zig");
pub const mod = @import("handle/mod.zig");

//structs
pub const ModLib = modlib.ModLib;
pub const Mod = mod.Mod;

pub const keyword = enum {
    open,
    import,
    patch,
    add,
    end,
    comment,
    text,
};

pub const InjectionError = error{
    FileNotFound,
    FileOpenFailure,
    FileReadError,
    FileWriteError,
    UnknownError,
    ThreadingUnavailable,
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
    ASMOD,
    ZIP,
};
