const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const RawValue = root.RawValue;
const ValueTag = root.ValueTag;
const Int = i64;
const CubicScriptState = @import("../state/CubicScriptState.zig");
const allocator = @import("../state/global_allocator.zig").allocator;

/// This is the Array implementation for scripts.
/// Corresponds with the struct `CubsArray` in `cubic_script.h`.
pub const Array = extern struct {
    const Self = @This();
    const ELEMENT_ALIGN = 8;
    const PTR_BITMASK = 0xFFFFFFFFFFFF;
    const TAG_BITMASK: usize = ~@as(usize, PTR_BITMASK);

    inner: usize,

    pub fn init(inTag: ValueTag) Self {
        return Self{ .inner = @shlExact(@as(usize, @intFromEnum(inTag)), 48) };
    }

    /// Clones the array, along with making clones of it's elements. Any elements that require an allocator to clone
    /// will use `allocator`, along with the copy of the array itself.
    pub fn clone(self: *const Self) Self {
        var copy = Self.init(self.tag());
        const slice = self.asSlice();
        if (slice.len == 0) {
            return copy;
        }

        copy.ensureTotalCapacity(@intCast(slice.len));

        switch (self.tag()) {
            .Bool => {
                for (slice) |value| {
                    var pushValue = RawValue{ .boolean = value.boolean };
                    copy.add(&pushValue, ValueTag.Bool);
                }
            },
            .Int => {
                for (slice) |value| {
                    var pushValue = RawValue{ .int = value.int };
                    copy.add(&pushValue, ValueTag.Int);
                }
            },
            .Float => {
                for (slice) |value| {
                    var pushValue = RawValue{ .float = value.float };
                    copy.add(&pushValue, ValueTag.Float);
                }
            },
            .String => {
                for (slice) |value| {
                    var pushValue = RawValue{ .string = value.string.clone() };
                    copy.add(&pushValue, ValueTag.String);
                }
            },
            .Array => {
                for (slice) |value| {
                    var pushValue = RawValue{ .array = value.array.clone() };
                    copy.add(&pushValue, ValueTag.Array);
                }
            },
            else => {
                @panic("Unsupported");
            },
        }

        return copy;
    }

    pub fn deinit(self: *Self) void {
        if ((self.inner & PTR_BITMASK) == 0) {
            return;
        }
        // Here, there are actually values.

        switch (self.tag()) {
            .Bool, .Int, .Float => {},
            .String => {
                const strings = self.asSliceMut();
                for (0..strings.len) |i| { // use indexing to get the mutable reference
                    strings[i].string.deinit();
                }
            },
            .Array => {
                const arrays = self.asSliceMut();
                for (0..arrays.len) |i| { // use indexing to get the mutable reference
                    arrays[i].array.deinit();
                }
            },
            else => {
                @panic("Unsupported");
            },
        }
        const allocation = self.getFullAllocation();
        allocator().free(allocation);
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
    pub fn add(self: *Self, ownedElement: *RawValue, inTag: ValueTag) void {
        assert(inTag == self.tag());
        const copyDest = self.addOne();

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

    fn ensureTotalCapacity(self: *Self, minCapacity: Int) void {
        const h = self.headerMut();
        if (h) |headerData| {
            if (headerData.capacity >= minCapacity) {
                return;
            }

            const grownCapacity = growCapacity(headerData.capacity, minCapacity);
            const newData = Header.init(grownCapacity);

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

            allocator().free(oldAllocation); // dont need to call drop, cause its just memcpy and instantly free the other.

            self.inner = (self.inner & TAG_BITMASK) | @intFromPtr(newData);
        } else {
            // here, it means the array has no data;
            const newData = Header.init(minCapacity);
            self.inner = (self.inner & TAG_BITMASK) | @intFromPtr(newData);
        }
    }

    /// Potentially reallocates. Increases the array length by one, returning a buffer to memcpy the element to.
    fn addOne(self: *Self) *RawValue {
        {
            const h = self.header();
            if (h) |headerData| {
                self.ensureTotalCapacity(headerData.length + 1);
            } else {
                self.ensureTotalCapacity(1);
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
        pub fn init(minCapacity: Int) *align(ELEMENT_ALIGN) anyopaque {
            const minCapacityUsize: usize = @intCast(minCapacity);
            const newData = allocator().alloc(
                usize,
                minCapacityUsize + @sizeOf(Header), // allocate space for the header
            ) catch {
                @panic("Script out of memory");
            };
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
    var arr = Array.init(ValueTag.Int);
    defer arr.deinit();

    var pushValue = RawValue{ .int = 5 };
    arr.add(&pushValue, ValueTag.Int);
}

test "Array at int" {
    var arr = Array.init(ValueTag.Int);
    defer arr.deinit();

    if (arr.at(0)) |_| {
        try expect(false);
    } else |_| {}

    var pushValue = RawValue{ .int = 5 };
    arr.add(&pushValue, ValueTag.Int);

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
    var arr = Array.init(ValueTag.Bool);
    defer arr.deinit();

    if (arr.at(0)) |_| {
        try expect(false);
    } else |_| {}

    var pushValue = RawValue{ .boolean = true };
    arr.add(&pushValue, ValueTag.Bool);

    if (arr.at(0)) |value| {
        try expect(value.boolean == true);
    } else |_| {
        try expect(false);
    }

    if (arr.at(1)) |_| {
        try expect(false);
    } else |_| {}
}

test "Array float sanity" {
    var arr = Array.init(ValueTag.Float);
    defer arr.deinit();

    if (arr.at(0)) |_| {
        try expect(false);
    } else |_| {}

    var pushValue = RawValue{ .float = 5 };
    arr.add(&pushValue, ValueTag.Float);

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
    var arr = Array.init(ValueTag.String);
    defer arr.deinit();

    if (arr.at(0)) |_| {
        try expect(false);
    } else |_| {}

    var pushValue = RawValue{ .string = root.String.initSlice("hello world!") };
    arr.add(&pushValue, ValueTag.String);

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
    var arr = Array.init(ValueTag.Array);
    defer arr.deinit();

    if (arr.at(0)) |_| {
        try expect(false);
    } else |_| {}

    var pushValue: RawValue = undefined;
    {
        var nestedArr = Array.init(ValueTag.Bool);
        defer arr.deinit();

        var nestedValue = RawValue{ .boolean = true };
        nestedArr.add(&nestedValue, ValueTag.Bool);

        pushValue = RawValue{ .array = nestedArr };
    }
    arr.add(&pushValue, ValueTag.Array);

    if (arr.at(0)) |value| {
        try expect(value.array.len() == 1);
        if (value.array.at(0)) |nestedValue| {
            try expect(nestedValue.boolean == true);
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
    fn makeArray(comptime tag: ValueTag, n: usize) RawValue {
        var arr = Array.init(tag);
        switch (tag) {
            .Bool => {
                for (0..n) |i| {
                    var pushValue = RawValue{
                        .boolean = if (@mod(i, 2) == 0) true else false,
                    };
                    arr.add(&pushValue, tag);
                }
            },
            .Int => {
                for (0..n) |i| {
                    var pushValue = RawValue{ .int = @intCast(i) };
                    arr.add(&pushValue, tag);
                }
            },
            .Float => {
                for (0..n) |i| {
                    var pushValue = RawValue{ .float = @floatFromInt(i) };
                    arr.add(&pushValue, tag);
                }
            },
            .String => {
                for (0..n) |i| {
                    const slice = std.fmt.allocPrint(std.testing.allocator, "{}", .{i}) catch unreachable;
                    defer std.testing.allocator.free(slice);
                    var pushValue = RawValue{
                        .string = root.String.initSlice(slice),
                    };
                    arr.add(&pushValue, tag);
                }
            },
            .Array => {
                for (0..n) |_| {
                    var pushValue = makeArray(ValueTag.Int, 10);
                    arr.add(&pushValue, tag);
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
    var arrEmpty1 = RawValue{ .array = Array.init(ValueTag.Int) };
    defer arrEmpty1.array.deinit();
    var arrEmpty2 = RawValue{ .array = Array.init(ValueTag.Int) };
    defer arrEmpty2.array.deinit();

    var arrContains1 = TestCreateArray.makeArray(ValueTag.Int, 10);
    defer arrContains1.array.deinit();
    var arrContains2 = TestCreateArray.makeArray(ValueTag.Int, 10);
    defer arrContains2.array.deinit();

    var arrContains3 = TestCreateArray.makeArray(ValueTag.Int, 20);
    defer arrContains3.array.deinit();
    var arrContains4 = TestCreateArray.makeArray(ValueTag.Int, 20);
    defer arrContains4.array.deinit();

    var arrOtherType1 = TestCreateArray.makeArray(ValueTag.Float, 10);
    defer arrOtherType1.array.deinit();
    var arrOtherType2 = TestCreateArray.makeArray(ValueTag.Float, 10);
    defer arrOtherType2.array.deinit();

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
    {
        var arr1 = TestCreateArray.makeArray(ValueTag.Bool, 4);
        defer arr1.array.deinit();

        var arr2 = arr1.array.clone();
        defer arr2.deinit();

        try expect(arr1.array.eql(arr2));
    }
    {
        var arr1 = TestCreateArray.makeArray(ValueTag.Int, 4);
        defer arr1.array.deinit();

        var arr2 = arr1.array.clone();
        defer arr2.deinit();

        try expect(arr1.array.eql(arr2));
    }
    {
        var arr1 = TestCreateArray.makeArray(ValueTag.Float, 4);
        defer arr1.array.deinit();

        var arr2 = arr1.array.clone();
        defer arr2.deinit();

        try expect(arr1.array.eql(arr2));
    }

    {
        var arr1 = TestCreateArray.makeArray(ValueTag.String, 4);
        defer arr1.array.deinit();

        var arr2 = arr1.array.clone();
        defer arr2.deinit();

        try expect(arr1.array.eql(arr2));
    }
    {
        var arr1 = TestCreateArray.makeArray(ValueTag.Array, 4);
        defer arr1.array.deinit();

        var arr2 = arr1.array.clone();
        defer arr2.deinit();

        try expect(arr1.array.eql(arr2));
    }
}
