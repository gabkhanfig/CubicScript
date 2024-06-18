const std = @import("std");
const expect = std.testing.expect;

const c = @cImport({
    @cInclude("interpreter/bytecode.h");
});
