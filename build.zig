const std = @import("std");
const Build = std.Build;

const CUBS_USING_ZIG_ALLOCATOR = "CUBS_USING_ZIG_ALLOCATOR";

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cubic_script = b.addModule("cubic_script", .{ .root_source_file = .{ .cwd_relative = "src/root.zig" } });
    cubic_script.link_libc = true;

    cubic_script.addCMacro(CUBS_USING_ZIG_ALLOCATOR, "1");
    cubic_script.addIncludePath(b.path("src"));

    if (target.result.cpu.arch.isX86()) {
        cubic_script.addCMacro("CUBS_X86_64", "1");
    }

    const c_flags = [_][]const u8{};
    for (cubic_script_c_sources) |c_file| {
        cubic_script.addCSourceFile(.{ .file = b.path(c_file), .flags = &c_flags });
    }

    { //* static/shared library
        const lib = b.addStaticLibrary(.{
            .name = "CubicScript",
            .root_source_file = .{ .cwd_relative = "src/lib.zig" },
            .target = target,
            .optimize = optimize,
        });
        lib.root_module.addImport("cubic_script", cubic_script);

        b.installArtifact(lib);
    }

    { //* tests
        const lib_unit_tests = b.addTest(.{
            .root_source_file = .{ .cwd_relative = "src/tests.zig" },
            .target = target,
            .optimize = optimize,
        });
        // Explicitly DON'T import the cubic script module for the tests, as including the same file twice in two different modules leads to a compilations error
        //lib_unit_tests.root_module.addImport("cubic_script", cubic_script);
        lib_unit_tests.addIncludePath(b.path("src"));
        lib_unit_tests.linkLibC();
        lib_unit_tests.defineCMacro(CUBS_USING_ZIG_ALLOCATOR, "1");

        const cpp_unit_tests = b.addExecutable(.{ .name = "cpp unit tests", .target = target, .optimize = optimize });
        cpp_unit_tests.addIncludePath(b.path("src"));
        cpp_unit_tests.linkLibC();
        cpp_unit_tests.linkLibCpp();

        for (cubic_script_c_sources) |c_file| {
            lib_unit_tests.addCSourceFile(.{ .file = b.path(c_file), .flags = &c_flags });
            cpp_unit_tests.addCSourceFile(.{ .file = b.path(c_file), .flags = &c_flags });
        }

        for (cubic_script_cpp_test_sources) |c_file| {
            cpp_unit_tests.addCSourceFile(.{ .file = b.path(c_file), .flags = &c_flags });
        }

        // On running "zig build test" on the command line, it will build both the zig tests, and c++ tests
        const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
        const run_cpp_unit_tests = b.addRunArtifact(cpp_unit_tests);
        const test_step = b.step("test", "Run unit tests");
        test_step.dependOn(&run_lib_unit_tests.step);
        test_step.dependOn(&run_cpp_unit_tests.step);
    }

    { //* executable for debug purposes
        const exe = b.addExecutable(.{
            .name = "CubicScript",
            .root_source_file = .{ .cwd_relative = "src/main.zig" },
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
}

pub const cubic_script_c_sources = [_][]const u8{
    "src/validate_compilation_target.c",

    "src/platform/mem.c",

    "src/program/program.c",
    "src/program/protected_arena.c",
    "src/program/function_map.c",
    "src/program/function_call_args.c",

    "src/interpreter/bytecode.c",
    "src/interpreter/interpreter.c",
    "src/interpreter/function_definition.c",
    "src/interpreter/operations.c",
    "src/interpreter/stack.c",

    "src/compiler/build_options.c",
    "src/compiler/compiler.c",
    "src/compiler/ast.c",

    "src/sync/atomic.c",
    "src/sync/locks.c",
    "src/sync/sync_queue.c",
    "src/sync/thread.c",

    "src/util/panic.c",
    "src/util/math.c",
    "src/util/hash.c",
    "src/util/simd.c",

    "src/primitives/context.c",
    "src/primitives/string/string.c",
    "src/primitives/array/array.c",
    "src/primitives/map/map.c",
    "src/primitives/set/set.c",
    "src/primitives/option/option.c",
    "src/primitives/error/error.c",
    "src/primitives/result/result.c",
    "src/primitives/sync_ptr/sync_ptr.c",
    "src/primitives/reference/reference.c",
    "src/primitives/vector/vector.c",
    "src/primitives/function/function.c",
};

pub const cubic_script_cpp_test_sources = [_][]const u8{
    "src/cpp_tests.cpp",
    "src/primitives/string/string_tests.cpp",
    "src/primitives/array/array_tests.cpp",
};
