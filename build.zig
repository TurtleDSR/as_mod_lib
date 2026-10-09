const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimise = b.standardOptimizeOption(.{});

    //dependencies
    const zip = b.dependency("zip", .{});

    //root
    var root_module = b.addModule("modlib", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimise,
    });

    const lexer_tree_module = b.createModule(.{
        .root_source_file = b.path("src/lexer/lexertree.zig"),
        .target = target,
        .optimize = optimise,
    });
    lexer_tree_module.addImport("modlib", root_module);

    const lexer_module = b.createModule(.{
        .root_source_file = b.path("src/lexer/lexer.zig"),
        .target = target,
        .optimize = optimise,
    });
    lexer_module.addImport("tree", lexer_tree_module);

    lexer_tree_module.addImport("lexer", lexer_module); //do this now that lexerTreeModule is made

    root_module.addImport("zip", zip.module("zip"));
    root_module.addImport("lexer", lexer_module);

    //test step
    const tree_test_module = b.addModule("treetest", .{
        .root_source_file = b.path("test/lexer/treetests.zig"),
        .target = target,
        .optimize = optimise,
    });
    tree_test_module.addImport("modlib", root_module);

    const tree_test = b.addTest(.{
        .root_module = tree_test_module,
    });

    const test_artifact = b.addRunArtifact(tree_test);

    const test_step = b.step("test", "Run Tests");
    test_step.dependOn(&test_artifact.step);
}
