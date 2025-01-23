const std = @import("std");
const expect = std.testing.expect;
const c = @cImport({
    @cInclude("compiler/script_types/struct_memory_layout.h");
});

const StructMemoryLayout = c.StructMemoryLayout;
const CubsTypeContext = c.CubsTypeContext;
const struct_memory_layout_next = c.struct_memory_layout_next;

test "one bool layout" {
    var layout = StructMemoryLayout{};
    try expect(0 == struct_memory_layout_next(&layout, &c.CUBS_BOOL_CONTEXT));
    try expect(1 == layout.structSize);
    try expect(1 == layout.structAlign);
}

test "one 64 bit int layout" {
    var layout = StructMemoryLayout{};
    try expect(0 == struct_memory_layout_next(&layout, &c.CUBS_INT_CONTEXT));
    try expect(8 == layout.structSize);
    try expect(8 == layout.structAlign);
}

test "one string" {
    var layout = StructMemoryLayout{};
    try expect(0 == struct_memory_layout_next(&layout, &c.CUBS_STRING_CONTEXT));
    try expect(32 == layout.structSize);
    try expect(8 == layout.structAlign);
}

test "two bool" {
    var layout = StructMemoryLayout{};
    try expect(0 == struct_memory_layout_next(&layout, &c.CUBS_BOOL_CONTEXT));
    try expect(1 == struct_memory_layout_next(&layout, &c.CUBS_BOOL_CONTEXT));
    try expect(2 == layout.structSize);
    try expect(1 == layout.structAlign);
}

// Special case for 1 byte alignment of bools
test "8 bool" {
    var layout = StructMemoryLayout{};
    for (0..8) |i| {
        try expect(i == struct_memory_layout_next(&layout, &c.CUBS_BOOL_CONTEXT));
    }
    try expect(8 == layout.structSize);
    try expect(1 == layout.structAlign);
}

test "many bool" {
    var layout = StructMemoryLayout{};
    for (0..10) |i| {
        try expect(i == struct_memory_layout_next(&layout, &c.CUBS_BOOL_CONTEXT));
    }
    try expect(10 == layout.structSize);
    try expect(1 == layout.structAlign);
}

test "two 64 bit int" {
    var layout = StructMemoryLayout{};
    try expect(0 == struct_memory_layout_next(&layout, &c.CUBS_INT_CONTEXT));
    try expect(8 == struct_memory_layout_next(&layout, &c.CUBS_INT_CONTEXT));
    try expect(16 == layout.structSize);
    try expect(8 == layout.structAlign);
}

test "many 64 bit int" {
    var layout = StructMemoryLayout{};
    for (0..10) |i| {
        try expect((i * 8) == struct_memory_layout_next(&layout, &c.CUBS_INT_CONTEXT));
    }
    try expect(80 == layout.structSize);
    try expect(8 == layout.structAlign);
}

test "two string" {
    var layout = StructMemoryLayout{};
    try expect(0 == struct_memory_layout_next(&layout, &c.CUBS_STRING_CONTEXT));
    try expect(32 == struct_memory_layout_next(&layout, &c.CUBS_STRING_CONTEXT));
    try expect(64 == layout.structSize);
    try expect(8 == layout.structAlign);
}

test "many string" {
    var layout = StructMemoryLayout{};
    for (0..10) |i| {
        try expect((i * 32) == struct_memory_layout_next(&layout, &c.CUBS_STRING_CONTEXT));
    }
    try expect(320 == layout.structSize);
    try expect(8 == layout.structAlign);
}

test "mixed types" {
    { // bool first
        var layout = StructMemoryLayout{};
        try expect(0 == struct_memory_layout_next(&layout, &c.CUBS_BOOL_CONTEXT));
        try expect(8 == struct_memory_layout_next(&layout, &c.CUBS_STRING_CONTEXT));
        try expect(40 == struct_memory_layout_next(&layout, &c.CUBS_INT_CONTEXT));
        std.debug.print("{}\n", .{layout.structSize});
        try expect(48 == layout.structSize);
        try expect(8 == layout.structAlign);
    }
    { // bool middle
        var layout = StructMemoryLayout{};
        try expect(0 == struct_memory_layout_next(&layout, &c.CUBS_INT_CONTEXT));
        try expect(8 == struct_memory_layout_next(&layout, &c.CUBS_BOOL_CONTEXT));
        try expect(16 == struct_memory_layout_next(&layout, &c.CUBS_STRING_CONTEXT));
        try expect(48 == layout.structSize);
        try expect(8 == layout.structAlign);
    }
    { // bool last
        var layout = StructMemoryLayout{};
        try expect(0 == struct_memory_layout_next(&layout, &c.CUBS_STRING_CONTEXT));
        try expect(32 == struct_memory_layout_next(&layout, &c.CUBS_INT_CONTEXT));
        try expect(40 == struct_memory_layout_next(&layout, &c.CUBS_BOOL_CONTEXT));
        try expect(48 == layout.structSize);
        try expect(8 == layout.structAlign);
    }
}
