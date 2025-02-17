const std = @import("std");
const expect = std.testing.expect;
const c = @cImport({
    @cInclude("compiler/graph/function_dependency_graph.h");
});

fn toSlice(s: []const u8) c.CubsStringSlice {
    return c.CubsStringSlice{ .str = s.ptr, .len = s.len };
}

fn entryNameIs(entry: *const FunctionEntry, name: []const u8) bool {
    return std.mem.eql(u8, entry.name.str[0..entry.name.len], name);
}

const FunctionDependencies = c.FunctionDependencies;

fn function_dependencies_init(name: []const u8) FunctionDependencies {
    return FunctionDependencies{ .name = toSlice(name) };
}

const function_dependencies_deinit = c.function_dependencies_deinit;

fn function_dependencies_push(self: *FunctionDependencies, dependencyName: []const u8) void {
    c.function_dependencies_push(self, toSlice(dependencyName));
}

const FunctionEntry = c.FunctionEntry;

const FunctionDependencyGraph = c.FunctionDependencyGraph;
const function_dependency_graph_deinit = c.function_dependency_graph_deinit;

const FunctionDependencyGraphIter = c.FunctionDependencyGraphIter;

const function_dependency_graph_iter_init = c.function_dependency_graph_iter_init;

fn function_dependency_graph_iter_next(self: *FunctionDependencyGraphIter) ?*const FunctionEntry {
    return @ptrCast(c.function_dependency_graph_iter_next(self));
}

const FunctionDependencyGraphBuilder = c.FunctionDependencyGraphBuilder;
const function_dependency_graph_builder_deinit = c.function_dependency_graph_builder_deinit;
const function_dependency_graph_builder_push = c.function_dependency_graph_builder_push;
const function_dependency_graph_builder_build = c.function_dependency_graph_builder_build;

test "Function with no dependencies" {
    const function = function_dependencies_init("testFunc");

    var builder = FunctionDependencyGraphBuilder{};
    function_dependency_graph_builder_push(&builder, function);

    var graph = function_dependency_graph_builder_build(&builder);
    defer function_dependency_graph_deinit(&graph);

    var iter = function_dependency_graph_iter_init(&graph);

    var i: usize = 0;
    while (function_dependency_graph_iter_next(&iter)) |entry| {
        try expect(entry.dependenciesLen == 0);
        try expect(entryNameIs(entry, "testFunc"));
        i += 1;
    }
    try expect(i == 1);
}
