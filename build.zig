const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimise = b.standardOptimizeOption(.{});

    //dependencies
    const zip = b.dependency("zip", .{});

    //common
    const common_module = b.createModule(.{
        .root_source_file = b.path("src/common.zig"),
        .target = target,
        .optimize = optimise,
    });
    common_module.addImport("zip", zip.module("zip"));

    //root
    const root_module = b.addModule("modlib", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimise,
    });
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
}
