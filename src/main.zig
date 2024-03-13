const std = @import("std");
const cubic_script = @import("cubic_script");
const String = cubic_script.primitives.String;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var s = try String.initSlice("hello to this glorious world!", allocator);
    defer s.deinit(allocator);

    std.debug.assert(s.eqlSlice("hello to this glorious world!"));
}
