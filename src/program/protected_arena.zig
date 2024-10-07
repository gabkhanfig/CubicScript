const std = @import("std");
const expect = std.testing.expect;
const c = @cImport({
    @cInclude("program/protected_arena.h");
});

test "init deinit" {
    var arena = c.cubs_protected_arena_init();
    defer c.cubs_protected_arena_deinit(&arena);
}

test "malloc" {
    var arena = c.cubs_protected_arena_init();
    defer c.cubs_protected_arena_deinit(&arena);

    _ = c.cubs_protected_arena_malloc(&arena, 1, 1);
}

test "free" {
    var arena = c.cubs_protected_arena_init();
    defer c.cubs_protected_arena_deinit(&arena);

    const mem = c.cubs_protected_arena_malloc(&arena, 1, 1);
    c.cubs_protected_arena_free(&arena, mem);
}

test "many malloc" {
    var arena = c.cubs_protected_arena_init();
    defer c.cubs_protected_arena_deinit(&arena);

    for (1..100) |i| {
        _ = c.cubs_protected_arena_malloc(&arena, 100 - i, i);
    }
}

test "many malloc and free" {
    var arena = c.cubs_protected_arena_init();
    defer c.cubs_protected_arena_deinit(&arena);

    var allocations: [99]?*anyopaque = undefined;

    for (1..100) |i| {
        allocations[i - 1] = c.cubs_protected_arena_malloc(&arena, i, 100 - i);
    }

    for (0..80) |i| {
        c.cubs_protected_arena_free(&arena, allocations[i]);
    }
}
