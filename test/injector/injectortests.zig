const std = @import("std");
const modlib = @import("modlib");

const testing = std.testing;
const allocator = testing.allocator;

test "load zip mod with properties" {
    var mod = try modlib.Mod.load("test/static/mods/zip-injection-test.zip", allocator);
    defer mod.deinit();

    const properties = mod.properties;

    //all properties should be default 
    try testing.expect(std.mem.eql(u8, properties.author, "Unknown"));
    try testing.expect(std.mem.eql(u8, properties.name, "zip-injection-test"));
    try testing.expect(std.mem.eql(u8, properties.id, "com.unknown.zip-injection-test"));
    try testing.expect(std.mem.eql(u8, properties.version, "0.0.0"));
    try testing.expect(std.mem.eql(u8, properties.source, ""));
    try testing.expect(properties.soft_dependencies == null);
    try testing.expect(properties.dependencies == null);
}

test "load asmod with properties" {
    var mod = try modlib.Mod.load("test/static/mods/property-test.asmod", allocator);
    defer mod.deinit();

    const properties = mod.properties;

    try testing.expect(std.mem.eql(u8, properties.author, "TurtleDSR"));
    try testing.expect(std.mem.eql(u8, properties.name, "PreloadFix"));
    try testing.expect(std.mem.eql(u8, properties.id, "com.turtledsr.preloadfix"));
    try testing.expect(std.mem.eql(u8, properties.version, "1.0.0"));
    try testing.expect(std.mem.eql(u8, properties.source, ""));
    try testing.expect(properties.soft_dependencies == null);
    try testing.expect(properties.dependencies == null);
}

test "inject zip mod" {
    var handle = modlib.ModLib.init("test/static/sandbox", allocator);
    defer handle.deinit();

    var mod = try modlib.Mod.load("test/static/mods/zip-injection-test.zip", allocator);
    defer mod.deinit();

    try handle.installMod(&mod);
}