const std = @import("std");
const modlib = @import("modlib");

const testing = std.testing;
const allocator = testing.allocator;
const io = testing.io;

test "inject zip mod" {
    var handle = try modlib.ModLib.init("test/static/sandbox", allocator);
    defer handle.deinit();

    var mod = try modlib.Mod.load("test/static/mods/zip-injection-test.zip", allocator);
    defer mod.deinit();

    try handle.queueMod(mod);
    
    try handle.installMods(io);
}

test "inject hazemod" {
    var handle = try modlib.ModLib.init("test/static/sandbox", allocator);
    defer handle.deinit();

    var mod = try modlib.Mod.load("test/static/mods/property-test.hazemod", allocator);
    defer mod.deinit();

    try handle.queueMod(mod);
    
    try handle.installMods(io);
}