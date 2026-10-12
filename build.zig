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

    var common_module = b.createModule(.{
        .root_source_file = b.path("src/common.zig"),
        .target = target,
        .optimize = optimise,
    });

    const lexer_tree_module = b.createModule(.{
        .root_source_file = b.path("src/lexer/lexertree.zig"),
        .target = target,
        .optimize = optimise,
    });
    lexer_tree_module.addImport("common", common_module);

    const lexer_module = b.createModule(.{
        .root_source_file = b.path("src/lexer/lexer.zig"),
        .target = target,
        .optimize = optimise,
    });
    lexer_module.addImport("tree", lexer_tree_module);

    lexer_tree_module.addImport("lexer", lexer_module); //do this now that lexerTreeModule is made

    common_module.addImport("zip", zip.module("zip"));
    common_module.addImport("lexer", lexer_module);

    root_module.addImport("common", common_module);

    //test step
    const test_module = b.createModule(.{
        .root_source_file = b.path("test/tests.zig"),
        .target = target,
        .optimize = optimise,
    });
    test_module.addImport("modlib", root_module);
    test_module.addImport("common", common_module);

    const tests = b.addTest(.{
        .root_module = test_module,
    });

    const test_artifact = b.addRunArtifact(tests);

    const test_step = b.step("test", "Run Tests");
    test_step.dependOn(&test_artifact.step);

    //lib build
    const root_lib = b.addLibrary(.{
        .name = "modlib",
        .linkage = .static,
        .root_module = root_module,
    });

    b.installArtifact(root_lib);

    //docs step
    const docs_step = b.step("docs", "Generate Docs");
    const docs_install = b.addInstallDirectory(.{
        .install_dir = .{ .custom = "../" },
        .source_dir = root_lib.getEmittedDocs(),
        .install_subdir = "docs",
    });

    docs_step.dependOn(&docs_install.step);
}
