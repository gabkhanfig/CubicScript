const std = @import("std");
const expect = std.testing.expect;
const c = @cImport({
    @cInclude("compiler/stack_variables.h");
});

const StackVariableInfo = c.StackVariableInfo;
const StackVariablesArray = c.StackVariablesArray;
const StackVariablesAssignment = c.StackVariablesAssignment;
const CubsString = c.CubsString;
const CubsStringSlice = c.CubsStringSlice;

test "stack variable info empty deinit" {
    var variable = StackVariableInfo{};
    defer c.cubs_stack_variable_info_deinit(&variable);
}

test "stack variables array empty deinit" {
    var variable = StackVariablesArray{};
    defer c.cubs_stack_variables_array_deinit(&variable);
}

test "stack assignment empty deinit" {
    var assignment = StackVariablesAssignment{};
    defer c.cubs_stack_assignment_deinit(&assignment);
}

test "stack assignment one variable one slot" {
    var assignment = StackVariablesAssignment{};
    defer c.cubs_stack_assignment_deinit(&assignment);

    try expect(assignment.len == 0);

    const variableName = CubsStringSlice{ .str = "hello".ptr, .len = 5 };
    // Use size of i64 because it only occupies one stack slot
    const size = @sizeOf(i64);
    try expect(c.cubs_stack_assignment_push(&assignment, variableName, size));

    try expect(assignment.len == 1);
    // should occupy slot 0
    try expect(c.cubs_stack_assignment_find(&assignment, variableName) == 0);

    try expect(assignment.requiredFrameSize == 1);
}

test "stack assignment two variables one slot each" {
    var assignment = StackVariablesAssignment{};
    defer c.cubs_stack_assignment_deinit(&assignment);

    try expect(assignment.len == 0);

    const v1 = CubsStringSlice{ .str = "hello".ptr, .len = 5 };
    const v2 = CubsStringSlice{ .str = "world".ptr, .len = 5 };
    // Use size of i64 because it only occupies one stack slot
    const size = @sizeOf(i64);

    { // variable 1
        try expect(c.cubs_stack_assignment_push(&assignment, v1, size));

        try expect(assignment.len == 1);
        // should occupy slot 0
        try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
        try expect(assignment.requiredFrameSize == 1);
    }
    { // variable 2
        try expect(c.cubs_stack_assignment_push(&assignment, v2, size));

        try expect(assignment.len == 2);
        // should occupy slot 0
        try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
        try expect(c.cubs_stack_assignment_find(&assignment, v2) == 1);
        try expect(assignment.requiredFrameSize == 2);
    }
}

test "stack assignment one variable multi slot" {
    var assignment = StackVariablesAssignment{};
    defer c.cubs_stack_assignment_deinit(&assignment);

    try expect(assignment.len == 0);

    const variableName = CubsStringSlice{ .str = "hello".ptr, .len = 5 };
    // Use size of i64 because it only occupies one stack slot
    const size = @sizeOf(CubsString);
    try expect(c.cubs_stack_assignment_push(&assignment, variableName, size));

    try expect(assignment.len == 1);
    // should occupy slot 0
    try expect(c.cubs_stack_assignment_find(&assignment, variableName) == 0);

    try expect(assignment.requiredFrameSize == 4);
}

test "stack assignment two variables multi slot each" {
    var assignment = StackVariablesAssignment{};
    defer c.cubs_stack_assignment_deinit(&assignment);

    try expect(assignment.len == 0);

    const v1 = CubsStringSlice{ .str = "hello".ptr, .len = 5 };
    const v2 = CubsStringSlice{ .str = "world".ptr, .len = 5 };
    // Use size of i64 because it only occupies one stack slot
    const size = @sizeOf(CubsString);

    { // variable 1
        try expect(c.cubs_stack_assignment_push(&assignment, v1, size));

        try expect(assignment.len == 1);
        // should occupy slot 0
        try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
        try expect(assignment.requiredFrameSize == 4);
    }
    { // variable 2
        try expect(c.cubs_stack_assignment_push(&assignment, v2, size));

        try expect(assignment.len == 2);
        // should occupy slot 0
        try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
        try expect(c.cubs_stack_assignment_find(&assignment, v2) == 4);
        try expect(assignment.requiredFrameSize == 8);
    }
}
