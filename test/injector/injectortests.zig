const std = @import("std");
const modlib = @import("modlib");

test "inject zip mod" {
    var handle = modlib.ModLib.init("test/sandbox");
    var mod = try modlib.Mod.load("test/mods/test1.zip");
    try handle.installMod(&mod);
}