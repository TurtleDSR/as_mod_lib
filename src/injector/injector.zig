const std = @import("std");
const common = @import("../common.zig");
const scriptedit = @import("../parser/scriptedit.zig");

const InjectorError = common.InjectorError;
const ScriptEdit = scriptedit.ScriptEdit;

pub fn executeEdit(step: ScriptEdit, io: std.Io) InjectorError!void {
    _ = step;
    _ = io;
}