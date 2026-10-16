const std = @import("std");
const modlib = @import("modlib");

const testing = std.testing;
const allocator = testing.allocator;
const io = testing.io;

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

test "load hazemod with properties" {
    var mod = try modlib.Mod.load("test/static/mods/property-test.hazemod", allocator);
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

test "queue hazemod" {
    var handle = try modlib.ModLib.init("test/static/sandbox", allocator);
    defer handle.deinit();

    var mod = try modlib.Mod.load("test/static/mods/property-test.hazemod", allocator);
    defer mod.deinit();

    try handle.queueMod(mod);

    const mod_index = try handle._hazemod_mod_pool.findMod(mod.properties.id);
    const properties = handle._hazemod_mod_pool.nodes.items[mod_index].mod.?.properties;

    try testing.expect(std.mem.eql(u8, properties.author, "TurtleDSR"));
    try testing.expect(std.mem.eql(u8, properties.name, "PreloadFix"));
    try testing.expect(std.mem.eql(u8, properties.id, "com.turtledsr.preloadfix"));
    try testing.expect(std.mem.eql(u8, properties.version, "1.0.0"));
    try testing.expect(std.mem.eql(u8, properties.source, ""));
    try testing.expect(properties.soft_dependencies == null);
    try testing.expect(properties.dependencies == null);
}