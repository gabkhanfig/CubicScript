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

test "one function with no dependencies" {
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

test "two functions with no dependencies" {
    const names = [2][]const u8{ "testFunc1", "testFunc2" };

    const f1 = function_dependencies_init(names[0]);
    const f2 = function_dependencies_init(names[1]);

    var builder = FunctionDependencyGraphBuilder{};
    function_dependency_graph_builder_push(&builder, f1);
    function_dependency_graph_builder_push(&builder, f2);

    var graph = function_dependency_graph_builder_build(&builder);
    defer function_dependency_graph_deinit(&graph);

    var iter = function_dependency_graph_iter_init(&graph);

    var i: usize = 0;
    while (function_dependency_graph_iter_next(&iter)) |entry| {
        try expect(entry.dependenciesLen == 0);
        try expect(entryNameIs(entry, names[i]));
        i += 1;
    }
    try expect(i == 2);
}

test "two functions one depend on the other" {
    const names = [2][]const u8{ "primary", "secondary" };

    const OrderIndependent = struct {
        fn validate(builder: *FunctionDependencyGraphBuilder) !void {
            var graph = function_dependency_graph_builder_build(builder);
            defer function_dependency_graph_deinit(&graph);

            var iter = function_dependency_graph_iter_init(&graph);

            { // first function should have no dependencies
                const entry = function_dependency_graph_iter_next(&iter).?;
                try expect(entry.dependenciesLen == 0);
                try expect(entryNameIs(entry, names[0]));
            }
            { // second function should have dependencies
                const entry = function_dependency_graph_iter_next(&iter).?;
                try expect(entry.dependenciesLen == 1);
                try expect(entryNameIs(entry, names[1]));
                try expect(entryNameIs(entry.dependencies[0], names[0]));
            }

            try expect(function_dependency_graph_iter_next(&iter) == null);
        }
    };

    { // no dependencies pushed first
        var builder = FunctionDependencyGraphBuilder{};
        const f1 = function_dependencies_init(names[0]);
        function_dependency_graph_builder_push(&builder, f1);

        var f2 = function_dependencies_init(names[1]);
        function_dependencies_push(&f2, names[0]);
        function_dependency_graph_builder_push(&builder, f2);

        try OrderIndependent.validate(&builder);
    }
    { // no dependencies pushed after
        var builder = FunctionDependencyGraphBuilder{};
        var f1 = function_dependencies_init(names[1]);
        function_dependencies_push(&f1, names[0]);
        function_dependency_graph_builder_push(&builder, f1);

        const f2 = function_dependencies_init(names[0]);
        function_dependency_graph_builder_push(&builder, f2);

        try OrderIndependent.validate(&builder);
    }
}

test "long dependency chain" {
    const names = [3][]const u8{ "primary", "secondary", "tertiary" };

    var builder = FunctionDependencyGraphBuilder{};
    var f1 = function_dependencies_init(names[1]);
    function_dependencies_push(&f1, names[0]);
    function_dependency_graph_builder_push(&builder, f1);

    var f2 = function_dependencies_init(names[2]);
    function_dependencies_push(&f2, names[1]);
    function_dependency_graph_builder_push(&builder, f2);

    const f3 = function_dependencies_init(names[0]);
    function_dependency_graph_builder_push(&builder, f3);

    var graph = function_dependency_graph_builder_build(&builder);
    defer function_dependency_graph_deinit(&graph);

    var iter = function_dependency_graph_iter_init(&graph);

    { // first function should have no dependencies
        const entry = function_dependency_graph_iter_next(&iter).?;
        try expect(entry.dependenciesLen == 0);
        try expect(entryNameIs(entry, names[0]));
    }
    { // second function should depend on the first
        const entry = function_dependency_graph_iter_next(&iter).?;
        try expect(entry.dependenciesLen == 1);
        try expect(entryNameIs(entry, names[1]));
        try expect(entryNameIs(entry.dependencies[0], names[0]));
    }
    { // third function should depend on the second
        const entry = function_dependency_graph_iter_next(&iter).?;
        try expect(entry.dependenciesLen == 1);
        try expect(entryNameIs(entry, names[2]));
        try expect(entryNameIs(entry.dependencies[0], names[1]));
    }

    try expect(function_dependency_graph_iter_next(&iter) == null);
}
