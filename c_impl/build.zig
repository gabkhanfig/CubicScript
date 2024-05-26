const std = @import("std");
const Build = std.Build;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cubic_script = b.addModule("cubic_script", .{ .root_source_file = .{ .path = "src/root.zig" } });
    cubic_script.link_libc = true;

    cubic_script.addCMacro("CUBS_USING_ZIG_ALLOCATOR", "1");
    cubic_script.addIncludePath(b.path("src"));

    if (target.result.cpu.arch.isX86()) {
        cubic_script.addCMacro("CUBS_X86_64", "1");
    }

    const c_flags = [_][]const u8{};
    for (cubic_script_c_sources) |c_file| {
        cubic_script.addCSourceFile(.{ .file = b.path(c_file), .flags = &c_flags });
    }

    const lib = b.addSharedLibrary(.{
        .name = "CubicScript",
        .root_source_file = .{ .path = "src/lib.zig" },
        .target = target,
        .optimize = optimize,
    });
    lib.root_module.addImport("cubic_script", cubic_script);

    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/tests.zig" },
        .target = target,
        .optimize = optimize,
    });
    // Explicitly DON'T import the cubic script module for the tests, as including the same file twice in two different modules leads to a compilations error
    //lib_unit_tests.root_module.addImport("cubic_script", cubic_script);
    lib_unit_tests.addIncludePath(b.path("src"));
    lib_unit_tests.linkLibC();
    lib_unit_tests.defineCMacro("CUBS_USING_ZIG_ALLOCATOR", "1");

    for (cubic_script_c_sources) |c_file| {
        lib_unit_tests.addCSourceFile(.{ .file = b.path(c_file), .flags = &c_flags });
    }

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);

    const exe = b.addExecutable(.{
        .name = "CubicScript",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("cubic_script", cubic_script);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

pub const cubic_script_c_sources = [_][]const u8{
    "src/util/atomic_ref_count.c",
    //"src/util/global_allocator.c",
    "src/util/rwlock.c",
    "src/util/panic.c",
    "src/util/math.c",
    "src/util/script_thread.c",
    "src/util/hash.c",

    "src/primitives/script_value.c",
    "src/primitives/string.c",
    "src/primitives/array.c",
    "src/primitives/map.c",
    "src/primitives/set/set.c",
};

pub const cubic_script_x86_sources = [_][]const u8{};
