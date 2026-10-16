const std = @import("std");
const common = @import("../common.zig");
const scriptedit = @import("../parser/scriptedit.zig");
const lexer = common.lexer;

const InjectorError = common.InjectorError;
const ScriptEdit = scriptedit.ScriptEdit;

var i: usize = 0;

pub fn streamEdits(data: []const u8, queue: *std.Io.Queue(ScriptEdit), allocator: std.mem.Allocator) InjectorError!void {
    _ = queue;
    var tokens = lexer.getTokens(data, allocator) catch |err| {
        return switch (err) {
            lexer.Error.OutOfMemory => InjectorError.OutOfMemory,
            lexer.Error.UnknownKeyword => InjectorError.SyntaxError,
        };
    };

    defer { //free tokens
        for (tokens.items) |t| {
            allocator.free(t.data);
        }
        tokens.clearAndFree(allocator);
    }
}
