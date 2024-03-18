const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const RawValue = root.RawValue;
const ValueTag = root.ValueTag;
const Int = root.Int;

/// This is the Array implementation for scripts.
/// Corresponds with the struct `CubsArray` in `cubic_script.h`.
pub const Array = extern struct {
    const Self = @This();
    const ELEMENT_ALIGN = 8;
    const PTR_BITMASK = 0xFFFFFFFFFFFF;
    const TAG_BITMASK: usize = ~@as(usize, PTR_BITMASK);

    inner: usize,

    pub fn init(inTag: ValueTag) Self {
        return Self{ .inner = @shlExact(@intFromEnum(inTag), 48) };
    }

    /// Clones the array, along with making clones of it's elements. Any elements that require an allocator to clone
    /// will use `allocator`, along with the copy of the array itself.
    pub fn clone(self: *const Self, allocator: Allocator) Allocator.Error!Self {
        var copy = Self.init(self.tag());
        const slice = self.asSlice();
        if (slice.len == 0) {
            return copy;
        }

        try copy.ensureTotalCapacity(@intCast(slice.len), allocator);

        switch (self.tag()) {
            .Bool => {
                for (slice) |value| {
                    var pushValue = RawValue{ .boolean = value.boolean };
                    copy.add(&pushValue, ValueTag.Bool, allocator) catch unreachable;
                }
            },
            .Int => {
                for (slice) |value| {
                    var pushValue = RawValue{ .int = value.int };
                    copy.add(&pushValue, ValueTag.Int, allocator) catch unreachable;
                }
            },
            .Float => {
                for (slice) |value| {
                    var pushValue = RawValue{ .float = value.float };
                    copy.add(&pushValue, ValueTag.Float, allocator) catch unreachable;
                }
            },
            .String => {
                for (slice) |value| {
                    var pushValue = RawValue{ .string = value.string.clone() };
                    copy.add(&pushValue, ValueTag.String, allocator) catch unreachable;
                }
            },
            .Array => {
                for (slice) |value| {
                    var pushValue = RawValue{ .array = try value.array.clone(allocator) };
                    copy.add(&pushValue, ValueTag.Array, allocator) catch unreachable;
                }
            },
            else => {
                @panic("Unsupported");
            },
        }

        return copy;
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        if ((self.inner & PTR_BITMASK) == 0) {
            return;
        }
        // Here, there are actually values.

        switch (self.tag()) {
            .Bool, .Int, .Float => {},
            .String => {
                const strings = self.asSliceMut();
                for (0..strings.len) |i| { // use indexing to get the mutable reference
                    strings[i].string.deinit(allocator);
                }
            },
            .Array => {
                const arrays = self.asSliceMut();
                for (0..arrays.len) |i| { // use indexing to get the mutable reference
                    arrays[i].array.deinit(allocator);
                }
            },
            else => {
                @panic("Unsupported");
            },
        }
        const allocation = self.getFullAllocation();
        allocator.free(allocation);
        self.inner = 0;
    }

    pub fn tag(self: *const Self) ValueTag {
        return @enumFromInt(@shrExact(self.inner & TAG_BITMASK, 48));
    }

    pub fn len(self: *const Self) Int {
        if (self.header()) |h| {
            return h.length;
        } else {
            return 0;
        }
    }

    /// Takes ownership of `ownedElement`, doing a memcpy of the data, and then memsetting the original to 0.
    /// It is undefined behaviour to access the `ownedElement` passed in.
    pub fn add(self: *Self, ownedElement: *RawValue, inTag: ValueTag, allocator: Allocator) Allocator.Error!void {
        assert(inTag == self.tag());
        const copyDest = try self.addOne(allocator);

        copyDest.* = ownedElement.*;
        const src: *usize = @ptrCast(ownedElement);
        src.* = 0;
    }

    /// operator[]. If `index` is out of bounds, returns `Array.Error.OutOfBounds`.
    /// Otherwise, an immutable reference to the value at the index is returned.
    pub fn at(self: *const Self, index: Int) Error!*const RawValue {
        if (index < 0) {
            return Error.OutOfBounds;
        }
        const arrData = self.asSlice();
        const indexAsUsize: usize = @intCast(index);
        if (indexAsUsize >= arrData.len) {
            return Error.OutOfBounds;
        }

        return &arrData[indexAsUsize];
    }

    /// operator[]. If `index` is out of bounds, returns `Array.Error.OutOfBounds`.
    /// Otherwise, a mutable reference to the value at the index is returned.
    pub fn atMut(self: *Self, index: Int) Error!*RawValue {
        if (index < 0) {
            return Error.OutOfBounds;
        }
        const arrData = self.asSliceMut();
        const indexAsUsize: usize = @intCast(index);
        if (indexAsUsize >= arrData.len) {
            return Error.OutOfBounds;
        }

        return &arrData[indexAsUsize];
    }

    pub fn asSlice(self: *const Self) []const RawValue {
        const headerData = self.header();
        if (headerData) |h| {
            const asMultiplePtr: [*]const Header = @ptrCast(h);
            const asValueMultiPtr: [*]const RawValue = @ptrCast(&asMultiplePtr[1]);
            const length: usize = @intCast(headerData.?.length);
            return asValueMultiPtr[0..length];
        } else {
            var outSlice: []const RawValue = undefined;
            outSlice.len = 0;
            return outSlice;
        }
    }

    pub fn asSliceMut(self: *Self) []RawValue {
        const headerData = self.headerMut();
        if (headerData) |h| {
            const asMultiplePtr: [*]Header = @ptrCast(h);
            const asValueMultiPtr: [*]RawValue = @ptrCast(&asMultiplePtr[1]);
            const length: usize = @intCast(headerData.?.length);
            return asValueMultiPtr[0..length];
        } else {
            var outSlice: []RawValue = undefined;
            outSlice.len = 0;
            return outSlice;
        }
    }

    pub fn eql(self: *const Self, other: Self) bool {
        const selfTag = self.tag();
        if (selfTag != other.tag()) {
            return false;
        }

        const selfSlice = self.asSlice();
        const otherSlice = other.asSlice();

        if (selfSlice.len != otherSlice.len) {
            return false;
        }
        if (selfSlice.len == 0 and otherSlice.len == 0) {
            return true;
        }

        // At this point, both are guaranteed to have elements, and are the same length.

        switch (self.tag()) {
            .Bool => {
                for (0..selfSlice.len) |i| {
                    if (selfSlice[i].boolean != otherSlice[i].boolean) {
                        return false;
                    }
                }
                return true;
            },
            .Int => {
                for (0..selfSlice.len) |i| {
                    if (selfSlice[i].int != otherSlice[i].int) {
                        return false;
                    }
                }
                return true;
            },
            .Float => {
                for (0..selfSlice.len) |i| {
                    if (selfSlice[i].float != otherSlice[i].float) {
                        return false;
                    }
                }
                return true;
            },
            .String => {
                for (0..selfSlice.len) |i| {
                    if (!selfSlice[i].string.eql(otherSlice[i].string)) {
                        return false;
                    }
                }
                return true;
            },
            .Array => {
                for (0..selfSlice.len) |i| {
                    if (!selfSlice[i].array.eql(otherSlice[i].array)) {
                        return false;
                    }
                }
                return true;
            },
            else => {
                @panic("Unsupported");
            },
        }
    }

    fn header(self: *const Self) ?*const Header {
        return @ptrFromInt(self.inner & PTR_BITMASK);
    }

    fn headerMut(self: *Self) ?*Header {
        return @ptrFromInt(self.inner & PTR_BITMASK);
    }

    fn ensureTotalCapacity(self: *Self, minCapacity: Int, allocator: Allocator) Allocator.Error!void {
        const h = self.headerMut();
        if (h) |headerData| {
            if (headerData.capacity >= minCapacity) {
                return;
            }

            const grownCapacity = growCapacity(headerData.capacity, minCapacity);
            const newData = try Header.init(grownCapacity, allocator);

            const newHeader: *Header = @ptrCast(newData);
            newHeader.length = headerData.length;

            const newArrayStart: [*]RawValue = @ptrCast(&@as([*]Header, @ptrCast(newHeader))[1]);
            const oldArrayStart: [*]RawValue = @ptrCast(self.asSliceMut().ptr);

            const oldLength: usize = @intCast(headerData.length);
            const oldCapacity: usize = @intCast(headerData.capacity);
            const oldArraySlice: []RawValue = oldArrayStart[0..oldLength];
            @memcpy(newArrayStart, oldArraySlice);

            var oldAllocation: []usize = undefined;
            oldAllocation.ptr = @ptrFromInt(self.inner & PTR_BITMASK);
            oldAllocation.len = (oldCapacity) + @sizeOf(Header);

            allocator.free(oldAllocation); // dont need to call drop, cause its just memcpy and instantly free the other.

            self.inner = (self.inner & TAG_BITMASK) | @intFromPtr(newData);
        } else {
            // here, it means the array has no data;
            const newData = try Header.init(minCapacity, allocator);
            self.inner = (self.inner & TAG_BITMASK) | @intFromPtr(newData);
        }
    }

    /// Potentially reallocates. Increases the array length by one, returning a buffer to memcpy the element to.
    fn addOne(self: *Self, allocator: Allocator) Allocator.Error!*RawValue {
        {
            const h = self.header();
            if (h) |headerData| {
                try self.ensureTotalCapacity(headerData.length + 1, allocator);
            } else {
                try self.ensureTotalCapacity(1, allocator);
            }
        }
        {
            const h = self.headerMut();
            h.?.length += 1;
            const arrData = self.asSliceMut();
            const length: usize = @intCast(h.?.length);
            return &arrData[length - 1];
        }
    }

    fn growCapacity(current: Int, minimum: Int) Int {
        var new = current;
        while (true) {
            new +|= @divTrunc(new, 2) + 8;
            if (new >= minimum)
                return new;
        }
    }

    fn getFullAllocation(self: *Self) []usize {
        const h = self.headerMut();
        if (h) |headerData| {
            const capacity: usize = @intCast(headerData.capacity);

            var outSlice: []usize = undefined;
            outSlice.ptr = @ptrCast(headerData);
            outSlice.len = capacity + @sizeOf(Header);
            return outSlice;
        } else {
            unreachable;
        }
    }

    const Header = extern struct {
        length: Int,
        capacity: Int,

        /// Creates a 0 initialized array with the correctly set header data.
        pub fn init(minCapacity: Int, allocator: Allocator) Allocator.Error!*align(ELEMENT_ALIGN) anyopaque {
            const minCapacityUsize: usize = @intCast(minCapacity);
            const newData = try allocator.alloc(
                usize,
                minCapacityUsize + @sizeOf(Header), // allocate space for the header
            );
            @memset(newData, 0);
            const headerPtr: *Header = @ptrCast(newData.ptr);
            headerPtr.capacity = minCapacity;
            return @ptrCast(newData.ptr);
        }
    };

    const Error = error{
        OutOfBounds,
    };
};

// Tests

test "Header size align" {
    try expect(@sizeOf(Array.Header) == 16);
    try expect(@alignOf(Array.Header) == 8);
}

test "Array default" {
    inline for (@typeInfo(ValueTag).Enum.fields) |f| {
        const arr = Array.init(@enumFromInt(f.value));
        try expect(arr.len() == 0);
    }
}

test "Array add int" {
    const allocator = std.testing.allocator;
    var arr = Array.init(ValueTag.Int);
    defer arr.deinit(allocator);

    var pushValue = RawValue{ .int = 5 };
    try arr.add(&pushValue, ValueTag.Int, allocator);
}

test "Array at int" {
    const allocator = std.testing.allocator;
    var arr = Array.init(ValueTag.Int);
    defer arr.deinit(allocator);

    if (arr.at(0)) |_| {
        try expect(false);
    } else |_| {}

    var pushValue = RawValue{ .int = 5 };
    try arr.add(&pushValue, ValueTag.Int, allocator);

    if (arr.at(0)) |value| {
        try expect(value.int == 5);
    } else |_| {
        try expect(false);
    }

    if (arr.at(1)) |_| {
        try expect(false);
    } else |_| {}
}

test "Array bool sanity" {
    const allocator = std.testing.allocator;
    var arr = Array.init(ValueTag.Bool);
    defer arr.deinit(allocator);

    if (arr.at(0)) |_| {
        try expect(false);
    } else |_| {}

    var pushValue = RawValue{ .boolean = root.TRUE };
    try arr.add(&pushValue, ValueTag.Bool, allocator);

    if (arr.at(0)) |value| {
        try expect(value.boolean == root.TRUE);
    } else |_| {
        try expect(false);
    }

    if (arr.at(1)) |_| {
        try expect(false);
    } else |_| {}
}

test "Array float sanity" {
    const allocator = std.testing.allocator;
    var arr = Array.init(ValueTag.Float);
    defer arr.deinit(allocator);

    if (arr.at(0)) |_| {
        try expect(false);
    } else |_| {}

    var pushValue = RawValue{ .float = 5 };
    try arr.add(&pushValue, ValueTag.Float, allocator);

    if (arr.at(0)) |value| {
        try expect(value.float == 5);
    } else |_| {
        try expect(false);
    }

    if (arr.at(1)) |_| {
        try expect(false);
    } else |_| {}
}

test "Array string sanity" {
    const allocator = std.testing.allocator;
    var arr = Array.init(ValueTag.String);
    defer arr.deinit(allocator);

    if (arr.at(0)) |_| {
        try expect(false);
    } else |_| {}

    var pushValue = RawValue{ .string = try root.String.initSlice("hello world!", allocator) };
    try arr.add(&pushValue, ValueTag.String, allocator);

    if (arr.at(0)) |value| {
        try expect(value.string.eqlSlice("hello world!"));
    } else |_| {
        try expect(false);
    }

    if (arr.at(1)) |_| {
        try expect(false);
    } else |_| {}
}

test "Array nested array sanity" {
    const allocator = std.testing.allocator;
    var arr = Array.init(ValueTag.Array);
    defer arr.deinit(allocator);

    if (arr.at(0)) |_| {
        try expect(false);
    } else |_| {}

    var pushValue: RawValue = undefined;
    {
        var nestedArr = Array.init(ValueTag.Bool);
        defer arr.deinit(allocator);

        var nestedValue = RawValue{ .boolean = root.TRUE };
        try nestedArr.add(&nestedValue, ValueTag.Bool, allocator);

        pushValue = RawValue{ .array = nestedArr };
    }
    try arr.add(&pushValue, ValueTag.Array, allocator);

    if (arr.at(0)) |value| {
        try expect(value.array.len() == 1);
        if (value.array.at(0)) |nestedValue| {
            try expect(nestedValue.boolean == root.TRUE);
        } else |_| {
            try expect(false);
        }
    } else |_| {
        try expect(false);
    }

    if (arr.at(1)) |_| {
        try expect(false);
    } else |_| {}
}

const TestCreateArray = struct {
    fn makeArray(comptime tag: ValueTag, n: usize, a: Allocator) RawValue {
        var arr = Array.init(tag);
        switch (tag) {
            .Bool => {
                for (0..n) |i| {
                    var pushValue = RawValue{
                        .boolean = if (@mod(i, 2) == 0) root.TRUE else root.FALSE,
                    };
                    arr.add(&pushValue, tag, a) catch unreachable;
                }
            },
            .Int => {
                for (0..n) |i| {
                    var pushValue = RawValue{ .int = @intCast(i) };
                    arr.add(&pushValue, tag, a) catch unreachable;
                }
            },
            .Float => {
                for (0..n) |i| {
                    var pushValue = RawValue{ .float = @floatFromInt(i) };
                    arr.add(&pushValue, tag, a) catch unreachable;
                }
            },
            .String => {
                for (0..n) |i| {
                    const slice = std.fmt.allocPrint(a, "{}", .{i}) catch unreachable;
                    defer a.free(slice);
                    var pushValue = RawValue{
                        .string = root.String.initSlice(slice, a) catch unreachable,
                    };
                    arr.add(&pushValue, tag, a) catch unreachable;
                }
            },
            .Array => {
                for (0..n) |_| {
                    var pushValue = makeArray(ValueTag.Int, 10, a);
                    arr.add(&pushValue, tag, a) catch unreachable;
                }
            },
            else => {
                @compileError("Unsupported array tag type");
            },
        }
        return RawValue{ .array = arr };
    }
};

test "Array equal" {
    const allocator = std.testing.allocator;

    var arrEmpty1 = RawValue{ .array = Array.init(ValueTag.Int) };
    defer arrEmpty1.array.deinit(allocator);
    var arrEmpty2 = RawValue{ .array = Array.init(ValueTag.Int) };
    defer arrEmpty2.array.deinit(allocator);

    var arrContains1 = TestCreateArray.makeArray(ValueTag.Int, 10, allocator);
    defer arrContains1.array.deinit(allocator);
    var arrContains2 = TestCreateArray.makeArray(ValueTag.Int, 10, allocator);
    defer arrContains2.array.deinit(allocator);

    var arrContains3 = TestCreateArray.makeArray(ValueTag.Int, 20, allocator);
    defer arrContains3.array.deinit(allocator);
    var arrContains4 = TestCreateArray.makeArray(ValueTag.Int, 20, allocator);
    defer arrContains4.array.deinit(allocator);

    var arrOtherType1 = TestCreateArray.makeArray(ValueTag.Float, 10, allocator);
    defer arrOtherType1.array.deinit(allocator);
    var arrOtherType2 = TestCreateArray.makeArray(ValueTag.Float, 10, allocator);
    defer arrOtherType2.array.deinit(allocator);

    try expect(arrEmpty1.array.eql(arrEmpty2.array));
    try expect(arrContains1.array.eql(arrContains2.array));
    try expect(arrContains3.array.eql(arrContains4.array));
    try expect(arrOtherType1.array.eql(arrOtherType2.array));

    try expect(!arrEmpty1.array.eql(arrContains1.array));
    try expect(!arrContains1.array.eql(arrContains3.array));
    try expect(!arrContains3.array.eql(arrEmpty1.array));
    try expect(!arrOtherType1.array.eql(arrContains1.array));
}

test "Array clone" {
    const allocator = std.testing.allocator;
    {
        var arr1 = TestCreateArray.makeArray(ValueTag.Bool, 4, allocator);
        defer arr1.array.deinit(allocator);

        var arr2 = try arr1.array.clone(allocator);
        defer arr2.deinit(allocator);

        try expect(arr1.array.eql(arr2));
    }
    {
        var arr1 = TestCreateArray.makeArray(ValueTag.Int, 4, allocator);
        defer arr1.array.deinit(allocator);

        var arr2 = try arr1.array.clone(allocator);
        defer arr2.deinit(allocator);

        try expect(arr1.array.eql(arr2));
    }
    {
        var arr1 = TestCreateArray.makeArray(ValueTag.Float, 4, allocator);
        defer arr1.array.deinit(allocator);

        var arr2 = try arr1.array.clone(allocator);
        defer arr2.deinit(allocator);

        try expect(arr1.array.eql(arr2));
    }

    {
        var arr1 = TestCreateArray.makeArray(ValueTag.String, 4, allocator);
        defer arr1.array.deinit(allocator);

        var arr2 = try arr1.array.clone(allocator);
        defer arr2.deinit(allocator);

        try expect(arr1.array.eql(arr2));
    }
    {
        var arr1 = TestCreateArray.makeArray(ValueTag.Array, 4, allocator);
        defer arr1.array.deinit(allocator);

        var arr2 = try arr1.array.clone(allocator);
        defer arr2.deinit(allocator);

        try expect(arr1.array.eql(arr2));
    }
}
