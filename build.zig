const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimise = b.standardOptimizeOption(.{});

    var zipDependency = b.dependency("zip", .{});
    const zipModule = b.addModule("zip", .{
        .root_source_file = zipDependency.path("src/root.zig"),
        .target = target,
        .optimize = optimise,
    });
    zipModule.link_libc = true;

    const lexertreeModule = b.addModule("lexertree", .{
        .root_source_file = b.path("src/lexer/lexertree.zig"),
        .target = target,
        .optimize = optimise,
    });

    const lexerModule = b.addModule("lexer", .{
        .root_source_file = b.path("src/lexer/lexer.zig"),
        .target = target,
        .optimize = optimise,
    });

    var rootModule = b.addModule("modlib", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimise,
    });

    rootModule.addImport("zip", zipModule);
    rootModule.addImport("lexer", lexerModule);
    rootModule.addImport("lexertree", lexertreeModule);

    lexertreeModule.addImport("modlib", rootModule);
    lexertreeModule.addImport("lexer", lexerModule);

    //test step
    const treeTestModule = b.addModule("treetest", .{
        .root_source_file = b.path("test/lexer/treetests.zig"),
        .target = target,
        .optimize = optimise,
    });
    treeTestModule.addImport("modlib", rootModule);
    treeTestModule.addImport("lexertree", lexertreeModule);

    const treeTest = b.addTest(.{
        .root_module = treeTestModule,
    });

    const testArtifact = b.addRunArtifact(treeTest);

    const testStep = b.step("test", "Run Tests");
    testStep.dependOn(&testArtifact.step);
}
