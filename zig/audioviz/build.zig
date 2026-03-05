const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = optimize,
        .raudio = false,
    });
    const raylib = raylib_dep.module("raylib");
    const raylib_artifact = raylib_dep.artifact("raylib");

    const zaudio_dep = b.dependency("zaudio", .{});
    const zaudio = zaudio_dep.module("root");
    const zaudio_artifact = zaudio_dep.artifact("miniaudio");

    const exe = b.addExecutable(.{
        .name = "audioviz",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "raylib", .module = raylib },
                .{ .name = "zaudio", .module = zaudio },
            },
        }),
    });

    exe.linkLibrary(raylib_artifact);
    exe.linkLibrary(zaudio_artifact);

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the visualizer");
    const run_cmd = b.addRunArtifact(exe);

    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
}
