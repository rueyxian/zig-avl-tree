const std = @import("std");
const fmt = std.fmt;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod_avl_tree = b.addModule("avl_tree", .{ .source_file = .{ .path = "src/avl_tree.zig" } });

    const step_tests = b.step("test", "Run unit tests");

    {
        const compile = b.addTest(.{
            .root_source_file = .{ .path = "src/avl_tree.zig" },
            .target = target,
            .optimize = optimize,
        });
        const run = b.addRunArtifact(compile);
        step_tests.dependOn(&run.step);
    }

    for ([_]struct {
        name: []const u8,
        path: []const u8,
    }{
        .{ .name = "basic", .path = "examples/basic.zig" },
        .{ .name = "memory_pool", .path = "examples/memory_pool.zig" },
    }) |opt| {
        const step_run = blk: {
            const name = try fmt.allocPrint(b.allocator, "run_{s}", .{opt.name});
            const desciption = try fmt.allocPrint(b.allocator, "Run `{s}`", .{opt.path});
            break :blk b.step(name, desciption);
        };

        const compile = b.addExecutable(.{
            .name = opt.name,
            .root_source_file = .{ .path = opt.path },
            .target = target,
            .optimize = optimize,
        });
        compile.addModule("avl_tree", mod_avl_tree);

        const run_artifact = b.addRunArtifact(compile);
        step_run.dependOn(&run_artifact.step);
    }
}
