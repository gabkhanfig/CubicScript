const std = @import("std");
const Build = std.Build;
const LazyPath = Build.LazyPath;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cubic_script = b.addModule("cubic_script", .{ .root_source_file = .{ .path = "src/root.zig" } });
    cubic_script.link_libc = true;

    cubic_script.addCMacro("CUBS_USING_ZIG_ALLOCATOR", "1");
    cubic_script.addIncludePath(LazyPath.relative("src"));

    if (target.result.cpu.arch.isX86()) {
        cubic_script.addCMacro("CUBS_X86_64", "1");
    }

    const c_flags = [_][]const u8{};
    for (cubic_script_c_sources) |c_file| {
        cubic_script.addCSourceFile(.{ .file = LazyPath.relative(c_file), .flags = &c_flags });
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
        .root_source_file = .{ .path = "src/root.zig" },
        .target = target,
        .optimize = optimize,
    });
    lib_unit_tests.root_module.addImport("cubic_script", cubic_script);
    lib_unit_tests.addIncludePath(LazyPath.relative("src"));

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

pub const cubic_script_c_sources = [_][]const u8{
    "src/util/atomic_ref_count.c",
    //"src/util/global_allocator.c",
    "src/util/rwlock.c",
    "src/util/panic.c",
    "src/util/math.c",

    "src/primitives/string.c",
    "src/primitives/script_value.c",
};

pub const cubic_script_x86_sources = [_][]const u8{};
