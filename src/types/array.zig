const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const primitives = @import("primitives.zig");
const Value = primitives.Value;
const Tag = primitives.Tag;
const Int = primitives.Int;

pub const Array = extern struct {
    const Self = @This();
    const ELEMENT_ALIGN = 8;
    const PTR_BITMASK = 0xFFFFFFFFFFFF;

    inner: usize,

    pub fn init(inTag: Tag) Self {
        return Self{ .inner = @intFromEnum(inTag) };
    }

    pub fn deinit(self: *Self, allocator: Allocator) void {
        if ((self.inner & Tag.TAG_BITMASK) == 0) {
            return;
        }

        switch (self.tag()) {
            .Bool, .Int, .Float => {
                const allocation = self.getFullAllocation();
                allocator.free(allocation);
            },
            else => {
                @panic("Unsupported");
            },
        }
        self.inner = 0;
    }

    pub fn tag(self: *const Self) Tag {
        return @enumFromInt(self.inner & Tag.TAG_BITMASK);
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
    pub fn add(self: *Self, ownedElement: *Value, inTag: Tag, allocator: Allocator) Allocator.Error!void {
        assert(inTag == self.tag());
        const copyDest = try self.addOne(allocator);

        copyDest.* = ownedElement.*;
        const src: *usize = @ptrCast(ownedElement);
        src.* = 0;
    }

    /// operator[], but returns an error instead of crashing if the value is out of bounds.
    pub fn at(self: *const Self, index: Int) Error.IndexOutOfBounds!*const Value {
        const h = self.header();
        if (h == null) {
            return Error.IndexOutOfBounds;
        }

        const arrData = self.asSlice().?;
        const headerData = h.?;

        if (index >= headerData.length) {
            return Error.IndexOutOfBounds;
        }

        return &arrData[index];
    }

    /// operator[], but returns an error instead of crashing if the value is out of bounds.
    pub fn atMut(self: *Self, index: Int) Error.IndexOutOfBounds!*Value {
        const h = self.header();
        if (h == null) {
            return Error.IndexOutOfBounds;
        }

        const arrData = self.asSliceMut().?;
        const headerData = h.?;

        if (index >= headerData.length) {
            return Error.IndexOutOfBounds;
        }

        return &arrData[index];
    }

    fn header(self: *const Self) ?*const Header {
        return @ptrFromInt(self.inner & PTR_BITMASK);
    }

    fn headerMut(self: *Self) ?*Header {
        return @ptrFromInt(self.inner & PTR_BITMASK);
    }

    fn asSlice(self: *const Self) ?[]const Value {
        const headerData = self.header();
        if (headerData) |h| {
            const asMultiplePtr: [*]const Header = @ptrCast(h);
            const asValueMultiPtr: [*]const Value = @ptrCast(&asMultiplePtr[1]);
            return asValueMultiPtr[0..headerData.?.length];
        } else {
            return null;
        }
    }

    fn asSliceMut(self: *Self) ?[]Value {
        const headerData = self.headerMut();
        if (headerData) |h| {
            const asMultiplePtr: [*]Header = @ptrCast(h);
            const asValueMultiPtr: [*]Value = @ptrCast(&asMultiplePtr[1]);
            const length: usize = @intCast(headerData.?.length);
            return asValueMultiPtr[0..length];
        } else {
            return null;
        }
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

            const newArrayStart: [*]Value = @ptrCast(&@as([*]Header, @ptrCast(newHeader))[1]);
            const oldArrayStart: [*]Value = @ptrCast(self.asSliceMut().?.ptr);

            const oldLength: usize = @intCast(headerData.length);
            const oldCapacity: usize = @intCast(headerData.capacity);
            const oldArraySlice: []Value = oldArrayStart[0..oldLength];
            @memcpy(newArrayStart, oldArraySlice);

            var oldAllocation: []usize = undefined;
            oldAllocation.ptr = @ptrFromInt(self.inner & PTR_BITMASK);
            oldAllocation.len = (oldCapacity) + @sizeOf(Header);

            allocator.free(oldAllocation); // dont need to call drop, cause its just memcpy and instantly free the other.

            self.inner = (self.inner & Tag.TAG_BITMASK) | @intFromPtr(newData);
        } else {
            // here, it means the array has no data;
            const newData = try Header.init(minCapacity, allocator);
            self.inner = (self.inner & Tag.TAG_BITMASK) | @intFromPtr(newData);
        }
    }

    /// Potentially reallocates. Increases the array length by one, returning a buffer to memcpy the element to.
    fn addOne(self: *Self, allocator: Allocator) Allocator.Error!*Value {
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
            const a = self.asSliceMut();
            if (a) |arrData| {
                const length: usize = @intCast(h.?.length);
                return &arrData[length - 1];
            } else {
                unreachable;
            }
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
        IndexOutOfBounds,
    };
};

// Tests

test "Header size align" {
    try expect(@sizeOf(Array.Header) == 16);
    try expect(@alignOf(Array.Header) == 8);
}

test "Array default" {
    inline for (@typeInfo(Tag).Enum.fields) |f| {
        const arr = Array.init(@enumFromInt(f.value));
        try expect(arr.len() == 0);
    }
}

test "Array add int" {
    const allocator = std.testing.allocator;
    var arr = Array.init(Tag.Int);
    defer arr.deinit(allocator);

    var pushValue = Value{ .int = 5 };
    try arr.push(&pushValue, Tag.Int, allocator);
}
