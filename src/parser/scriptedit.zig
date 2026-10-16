pub const ScriptEdit = struct {
    operation: Operation = .NONE,
    scope: Scope = .GLOBAL,
    file: []const u8 = "",
    target: []const u8 = "",
    data: []const u8 = "",
};

pub const Operation = enum {
    REPLACE,
    ADD,
    NONE,
};

pub const Scope = enum {
    GLOBAL,
    CLASS,
    FUNCTION,
    PROPERTY,
    ENUM,
};
