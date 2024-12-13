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

fn sliceFromLiteral(s: []const u8) CubsStringSlice {
    return .{ .str = s.ptr, .len = s.len };
}

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

test "stack assignment many variables one slot each" {
    var assignment = StackVariablesAssignment{};
    defer c.cubs_stack_assignment_deinit(&assignment);

    try expect(assignment.len == 0);

    const v1 = sliceFromLiteral("asdpiyahpsdiuhapsiduhapsiudhp");
    const v2 = sliceFromLiteral("hello world!");
    const v3 = sliceFromLiteral("v3");
    const v4 = sliceFromLiteral("temp");
    const v5 = sliceFromLiteral("buffer");
    const v6 = sliceFromLiteral("hello to this glorious world");
    const v7 = sliceFromLiteral("hi");

    // Use size of i64 because it only occupies one stack slot
    const size = @sizeOf(i64);

    { // variable 1
        try expect(c.cubs_stack_assignment_push(&assignment, v1, size));
        try expect(assignment.len == 1);
        try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
        try expect(assignment.requiredFrameSize == 1);
    }
    { // variable 2
        try expect(c.cubs_stack_assignment_push(&assignment, v2, size));
        try expect(assignment.len == 2);
        try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
        try expect(c.cubs_stack_assignment_find(&assignment, v2) == 1);
        try expect(assignment.requiredFrameSize == 2);
    }
    { // variable 3
        try expect(c.cubs_stack_assignment_push(&assignment, v3, size));
        try expect(assignment.len == 3);
        try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
        try expect(c.cubs_stack_assignment_find(&assignment, v2) == 1);
        try expect(c.cubs_stack_assignment_find(&assignment, v3) == 2);
        try expect(assignment.requiredFrameSize == 3);
    }
    { // variable 4
        try expect(c.cubs_stack_assignment_push(&assignment, v4, size));
        try expect(assignment.len == 4);
        try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
        try expect(c.cubs_stack_assignment_find(&assignment, v2) == 1);
        try expect(c.cubs_stack_assignment_find(&assignment, v3) == 2);
        try expect(c.cubs_stack_assignment_find(&assignment, v4) == 3);
        try expect(assignment.requiredFrameSize == 4);
    }
    { // variable 5
        try expect(c.cubs_stack_assignment_push(&assignment, v5, size));
        try expect(assignment.len == 5);
        try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
        try expect(c.cubs_stack_assignment_find(&assignment, v2) == 1);
        try expect(c.cubs_stack_assignment_find(&assignment, v3) == 2);
        try expect(c.cubs_stack_assignment_find(&assignment, v4) == 3);
        try expect(c.cubs_stack_assignment_find(&assignment, v5) == 4);
        try expect(assignment.requiredFrameSize == 5);
    }
    { // variable 6
        try expect(c.cubs_stack_assignment_push(&assignment, v6, size));
        try expect(assignment.len == 6);
        try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
        try expect(c.cubs_stack_assignment_find(&assignment, v2) == 1);
        try expect(c.cubs_stack_assignment_find(&assignment, v3) == 2);
        try expect(c.cubs_stack_assignment_find(&assignment, v4) == 3);
        try expect(c.cubs_stack_assignment_find(&assignment, v5) == 4);
        try expect(c.cubs_stack_assignment_find(&assignment, v6) == 5);
        try expect(assignment.requiredFrameSize == 6);
    }
    { // variable 7
        try expect(c.cubs_stack_assignment_push(&assignment, v7, size));
        try expect(assignment.len == 7);
        try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
        try expect(c.cubs_stack_assignment_find(&assignment, v2) == 1);
        try expect(c.cubs_stack_assignment_find(&assignment, v3) == 2);
        try expect(c.cubs_stack_assignment_find(&assignment, v4) == 3);
        try expect(c.cubs_stack_assignment_find(&assignment, v5) == 4);
        try expect(c.cubs_stack_assignment_find(&assignment, v6) == 5);
        try expect(c.cubs_stack_assignment_find(&assignment, v7) == 6);
        try expect(assignment.requiredFrameSize == 7);
    }
}

test "stack assignment many variables many slot each" {
    var assignment = StackVariablesAssignment{};
    defer c.cubs_stack_assignment_deinit(&assignment);

    try expect(assignment.len == 0);

    const v1 = sliceFromLiteral("asdpiyahpsdiuhapsiduhapsiudhp");
    const v2 = sliceFromLiteral("hello world!");
    const v3 = sliceFromLiteral("v3");
    const v4 = sliceFromLiteral("temp");
    const v5 = sliceFromLiteral("buffer");
    const v6 = sliceFromLiteral("hello to this glorious world");
    const v7 = sliceFromLiteral("hi");

    // Use size of i64 because it only occupies one stack slot
    const size = @sizeOf(CubsString);

    { // variable 1
        try expect(c.cubs_stack_assignment_push(&assignment, v1, size));
        try expect(assignment.len == 1);
        try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
        try expect(assignment.requiredFrameSize == 4);
    }
    { // variable 2
        try expect(c.cubs_stack_assignment_push(&assignment, v2, size));
        try expect(assignment.len == 2);
        try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
        try expect(c.cubs_stack_assignment_find(&assignment, v2) == 4);
        try expect(assignment.requiredFrameSize == 8);
    }
    { // variable 3
        try expect(c.cubs_stack_assignment_push(&assignment, v3, size));
        try expect(assignment.len == 3);
        try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
        try expect(c.cubs_stack_assignment_find(&assignment, v2) == 4);
        try expect(c.cubs_stack_assignment_find(&assignment, v3) == 8);
        try expect(assignment.requiredFrameSize == 12);
    }
    { // variable 4
        try expect(c.cubs_stack_assignment_push(&assignment, v4, size));
        try expect(assignment.len == 4);
        try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
        try expect(c.cubs_stack_assignment_find(&assignment, v2) == 4);
        try expect(c.cubs_stack_assignment_find(&assignment, v3) == 8);
        try expect(c.cubs_stack_assignment_find(&assignment, v4) == 12);
        try expect(assignment.requiredFrameSize == 16);
    }
    { // variable 5
        try expect(c.cubs_stack_assignment_push(&assignment, v5, size));
        try expect(assignment.len == 5);
        try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
        try expect(c.cubs_stack_assignment_find(&assignment, v2) == 4);
        try expect(c.cubs_stack_assignment_find(&assignment, v3) == 8);
        try expect(c.cubs_stack_assignment_find(&assignment, v4) == 12);
        try expect(c.cubs_stack_assignment_find(&assignment, v5) == 16);
        try expect(assignment.requiredFrameSize == 20);
    }
    { // variable 6
        try expect(c.cubs_stack_assignment_push(&assignment, v6, size));
        try expect(assignment.len == 6);
        try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
        try expect(c.cubs_stack_assignment_find(&assignment, v2) == 4);
        try expect(c.cubs_stack_assignment_find(&assignment, v3) == 8);
        try expect(c.cubs_stack_assignment_find(&assignment, v4) == 12);
        try expect(c.cubs_stack_assignment_find(&assignment, v5) == 16);
        try expect(c.cubs_stack_assignment_find(&assignment, v6) == 20);
        try expect(assignment.requiredFrameSize == 24);
    }
    { // variable 7
        try expect(c.cubs_stack_assignment_push(&assignment, v7, size));
        try expect(assignment.len == 7);
        try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
        try expect(c.cubs_stack_assignment_find(&assignment, v2) == 4);
        try expect(c.cubs_stack_assignment_find(&assignment, v3) == 8);
        try expect(c.cubs_stack_assignment_find(&assignment, v4) == 12);
        try expect(c.cubs_stack_assignment_find(&assignment, v5) == 16);
        try expect(c.cubs_stack_assignment_find(&assignment, v6) == 20);
        try expect(c.cubs_stack_assignment_find(&assignment, v7) == 24);
        try expect(assignment.requiredFrameSize == 28);
    }
}

test "stack assignment two variables mixed sizes" {
    { // one slot type first
        var assignment = StackVariablesAssignment{};
        defer c.cubs_stack_assignment_deinit(&assignment);

        try expect(assignment.len == 0);

        const v1 = sliceFromLiteral("hello");
        const v2 = sliceFromLiteral("world");

        { // variable 1
            try expect(c.cubs_stack_assignment_push(&assignment, v1, @sizeOf(i64)));

            try expect(assignment.len == 1);
            // should occupy slot 0
            try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
            try expect(assignment.requiredFrameSize == 1);
        }
        { // variable 2
            try expect(c.cubs_stack_assignment_push(&assignment, v2, @sizeOf(CubsString)));

            try expect(assignment.len == 2);
            // should occupy slot 0
            try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
            try expect(c.cubs_stack_assignment_find(&assignment, v2) == 1);
            try expect(assignment.requiredFrameSize == 5);
        }
    }
    { // many slot type first
        var assignment = StackVariablesAssignment{};
        defer c.cubs_stack_assignment_deinit(&assignment);

        try expect(assignment.len == 0);

        const v1 = sliceFromLiteral("hello");
        const v2 = sliceFromLiteral("world");

        { // variable 1
            try expect(c.cubs_stack_assignment_push(&assignment, v1, @sizeOf(CubsString)));

            try expect(assignment.len == 1);
            // should occupy slot 0
            try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
            try expect(assignment.requiredFrameSize == 4);
        }
        { // variable 2
            try expect(c.cubs_stack_assignment_push(&assignment, v2, @sizeOf(i64)));

            try expect(assignment.len == 2);
            // should occupy slot 0
            try expect(c.cubs_stack_assignment_find(&assignment, v1) == 0);
            try expect(c.cubs_stack_assignment_find(&assignment, v2) == 4);
            try expect(assignment.requiredFrameSize == 5);
        }
    }
}
