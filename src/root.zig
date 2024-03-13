const std = @import("std");
const testing = std.testing;

pub fn buildLink(c: *std.Build.Step.Compile, cubicScriptModule: *std.Build.Dependency, cFlags: []const []const u8) void {
    if (c.rootModuleTarget().cpu.arch.isX86()) {
        c.defineCMacro("X86_64", "1");
    }

    c.addCSourceFiles(.{
        .dependency = cubicScriptModule,
        .files = &cubic_script_c_sources,
        .flags = cFlags,
    });
    c.linkLibC();
    c.linkLibCpp();
}

pub const primitives = @import("types/primitives.zig");

pub fn cubicScriptTest() void {
    std.debug.print("cubic script!!!\n", .{});
}

pub const cubic_script_c_sources = [_][]const u8{
    "src/runtime/cpu_features.c",
    "src/types/string_simd.cpp",
};
