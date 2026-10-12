const std = @import("std");
const modlib = @import("modlib");

test "inject zip mod" {
    var handle = modlib.ModLib.init("test/sandbox");
    try handle.installZipMod("test/mods/test1.zip");
}