const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const root = @import("../root.zig");
const RawValue = root.RawValue;
const ValueTag = root.ValueTag;
const hash = @import("hash.zig");
const HashGroupBitmask = hash.HashGroupBitmask;
const HashPairBitmask = hash.HashPairBitmask;
const computeHash = hash.computeHash;
const TaggedValue = root.TaggedValue;
const CubicScriptState = @import("../state/CubicScriptState.zig");
const allocator = @import("../state/global_allocator.zig").allocator;

/// This is the hashmap implementation for scripts.
/// Corresponds with the struct `CubsMap` in `cubic_script.h`.
pub const Map = extern struct {
    const Self = @This();
    const PTR_BITMASK = 0xFFFFFFFFFFFF;
    const KEY_TAG_BITMASK: usize = @shlExact(@as(usize, 0xFF), 48);
    const VALUE_TAG_BITMASK: usize = @shlExact(@as(usize, 0xFF), 56);
    const VALUE_SHIFT = 8;

    inner: ?*anyopaque,

    /// Initialize a new Map instance.
    pub fn init(inKeyTag: ValueTag, inValueTag: ValueTag) Self {
        const keyTagInt: usize = @intCast(@intFromEnum(inKeyTag));
        const valueTagInt: usize = @intCast(@intFromEnum(inValueTag));
        return Self{ .inner = @ptrFromInt(@shlExact(keyTagInt, 48) | @shlExact(valueTagInt, 56)) };
    }

    /// Free the memory allocated for this map, as well as deinit'ing the values it owns.
    pub fn deinit(self: *Self) void {
        if (self.asInnerMut()) |inner| {
            for (inner.groups) |*group| {
                group.deinit(self.keyTag(), self.valueTag());
            }
            allocator().free(inner.groups);
            allocator().destroy(inner);
            self.inner = null;
        }
    }

    pub fn keyTag(self: *const Self) ValueTag {
        const mask = @intFromPtr(self.inner) & KEY_TAG_BITMASK;
        return @enumFromInt(@shrExact(mask, 48));
    }

    pub fn valueTag(self: *const Self) ValueTag {
        const mask = @intFromPtr(self.inner) & VALUE_TAG_BITMASK;
        return @enumFromInt(@shrExact(mask, 56));
    }

    /// Get the number of entries in the hashmap.
    pub fn size(self: *const Self) usize {
        if (self.asInner()) |inner| {
            return inner.count;
        } else {
            return 0;
        }
    }

    /// The returned reference may become invalidated when this `Map` is mutated.
    pub fn find(self: *const Self, key: TaggedValue) root.ValueConstRef {
        assert(key.tag == self.keyTag());

        if (self.asInner()) |inner| {
            const hashCode = computeHash(&key.value, key.tag, hash.TEST_SEED_VALUE);
            const groupBitmask = HashGroupBitmask.init(hashCode);
            const groupIndex = @mod(groupBitmask.value, inner.groups.len);

            const found = inner.groups[groupIndex].find(key.value, key.tag, hashCode);
            if (found == null) {
                return .{};
            }

            return root.ValueConstRef.init(self.valueTag(), &inner.groups[groupIndex].pairs[found.?].value);
        } else {
            return .{};
        }
    }

    /// The returned reference may become invalidated when this `Map` is mutated.
    pub fn findMut(self: *Self, key: TaggedValue) root.ValueMutRef {
        assert(key.tag == self.keyTag());

        if (self.asInner()) |inner| {
            const hashCode = computeHash(&key.value, key.tag, hash.TEST_SEED_VALUE);
            const groupBitmask = HashGroupBitmask.init(hashCode);
            const groupIndex = @mod(groupBitmask.value, inner.groups.len);

            const found = inner.groups[groupIndex].find(key.value, key.tag, hashCode);
            if (found == null) {
                return .{};
            }

            return root.ValueMutRef.init(self.valueTag(), &inner.groups[groupIndex].pairs[found.?].value);
        } else {
            return .{};
        }
    }

    /// If the entry already exists, will replace the existing held value with `value`.
    /// Takes ownership of `key` and `value`, setting the original references to 0.
    /// Expects that `allocator` was also used for `key` and `value`.
    pub fn insert(self: *Self, key: *TaggedValue, value: *TaggedValue) void {
        assert(key.tag == self.keyTag());
        assert(value.tag == self.valueTag());

        const elemSize = self.size();
        self.ensureTotalCapacity(@as(usize, @intCast(elemSize)) + 1);

        if (self.asInnerMut()) |inner| {
            const hashCode = computeHash(&key.value, key.tag, hash.TEST_SEED_VALUE);
            const groupBitmask = HashGroupBitmask.init(hashCode);
            const groupIndex = @mod(groupBitmask.value, inner.groups.len);

            inner.groups[groupIndex].insert(key, value, hashCode);
            inner.count += 1;
        } else {
            unreachable;
        }
    }

    /// Returns true if the entry `key` exists, and thus was successfully deleted and cleaned up,
    /// and returns false if the entry doesn't exist.
    pub fn erase(self: *Self, key: TaggedValue) bool {
        assert(key.tag == self.keyTag());

        const elemSize = self.size();
        if (elemSize == 0) {
            return false;
        }

        if (self.asInnerMut()) |inner| {
            const hashCode = computeHash(&key.value, key.tag, hash.TEST_SEED_VALUE);
            const groupBitmask = HashGroupBitmask.init(hashCode);
            const groupIndex = @mod(groupBitmask.value, inner.groups.len);

            inner.count -= 1;

            return inner.groups[groupIndex].erase(key.value, key.tag, self.valueTag(), hashCode);
        } else {
            unreachable;
        }
    }

    fn asInner(self: *const Self) ?*const Inner {
        return @ptrFromInt(@intFromPtr(self.inner) & @as(usize, PTR_BITMASK));
    }

    fn asInnerMut(self: *Self) ?*Inner {
        return @ptrFromInt(@intFromPtr(self.inner) & @as(usize, PTR_BITMASK));
    }

    fn ensureTotalCapacity(self: *Self, minCapacity: usize) void {
        if (!self.shouldReallocate(minCapacity)) {
            return;
        }

        const newGroupCount = calculateNewGroupCount(minCapacity);
        if (self.asInner()) |inner| {
            if (newGroupCount <= inner.groups.len) {
                return;
            }
        }

        const newGroups = allocator().alloc(Group, newGroupCount) catch {
            @panic("Script out of memory");
        };
        for (0..newGroups.len) |i| {
            newGroups[i] = Group.init();
        }

        if (self.asInnerMut()) |inner| {
            for (inner.groups) |oldGroup| {
                var i: usize = 0;
                for (oldGroup.hashMasksSlice()) |hashMask| {
                    if (hashMask == 0) {
                        i += 1;
                        continue;
                    }

                    const pair = oldGroup.pairs[i];
                    const groupBitmask = HashGroupBitmask.init(pair.hash);
                    const groupIndex = @mod(groupBitmask.value, inner.groups.len);

                    const newGroup = &newGroups[groupIndex];

                    newGroup.ensureTotalCapacity(newGroup.pairCount + 1);

                    const newHashMasksAsBytePtr: [*]u8 = @ptrCast(newGroup.hashMasks);

                    newHashMasksAsBytePtr[newGroup.pairCount] = hashMask;
                    newGroup.pairs[newGroup.pairCount] = pair; // move pair allocation
                    newGroup.pairCount += 1;
                    i += 1;
                }

                const oldGroupAllocation = oldGroup.getFullAllocation();
                allocator().free(oldGroupAllocation);
            }

            if (inner.groups.len > 0) {
                allocator().free(inner.groups);
            }

            inner.groups = newGroups;
        } else {
            const newInner = allocator().create(Inner) catch {
                @panic("Script out of memory");
            };
            newInner.groups = newGroups;
            newInner.count = 0;

            self.inner = @ptrFromInt((@intFromPtr(self.inner) & (KEY_TAG_BITMASK | VALUE_TAG_BITMASK)) | @intFromPtr(newInner));
        }
    }

    fn shouldReallocate(self: *const Self, requiredCapacity: usize) bool {
        if (self.asInner()) |inner| {
            const loadFactorScaledPairCount = @shrExact(inner.count & ~@as(usize, 0b11), 2) * 3; // multiply by 0.75
            return requiredCapacity > loadFactorScaledPairCount;
        } else {
            return true;
        }
    }

    fn calculateNewGroupCount(requiredCapacity: usize) usize {
        if (requiredCapacity < Group.GROUP_ALLOC_SIZE) {
            return 1;
        } else {
            const out = requiredCapacity / (Group.GROUP_ALLOC_SIZE / 16);
            return out;
        }
    }
};

const Inner = struct {
    groups: []Group,
    count: usize = 0,
};

const Group = struct {
    const Self = @This();

    const GROUP_ALLOC_SIZE = 32;
    const INITIAL_ALLOCATION_SIZE = calculateChunksHashGroupAllocationSize(GROUP_ALLOC_SIZE);
    const ALIGNMENT = 32;

    hashMasks: [*]@Vector(32, u8),
    pairs: [*]*Pair,
    pairCount: usize = 0,
    capacity: usize = GROUP_ALLOC_SIZE,

    fn init() Self {
        const memory = allocator().alignedAlloc(u8, ALIGNMENT, INITIAL_ALLOCATION_SIZE) catch {
            @panic("Script out of memory");
        };
        @memset(memory, 0);

        const hashMasks: [*]@Vector(32, u8) = @ptrCast(@alignCast(memory.ptr));
        const pairs: [*]*Pair = @ptrCast(@alignCast(&memory.ptr[GROUP_ALLOC_SIZE]));

        return Group{
            .hashMasks = hashMasks,
            .pairs = pairs,
        };
    }

    fn deinit(self: *Self, keyTag: ValueTag, valueTag: ValueTag) void {
        var i: usize = 0;
        if (self.pairCount > 0) {
            for (self.hashMasksSlice()) |mask| {
                if (mask == 0) {
                    i += 1;
                    continue;
                }

                self.pairs[i].key.deinit(keyTag);
                self.pairs[i].value.deinit(valueTag);
                allocator().destroy(self.pairs[i]);
                i += 1;
            }
        }

        allocator().free(self.getFullAllocation());
        // Ensure that any use after free will be caught.
        self.hashMasks = undefined;
        self.pairs = undefined;
        self.pairCount = undefined;
        self.capacity = undefined;
    }

    fn find(self: *const Self, key: RawValue, tag: ValueTag, hashCode: usize) ?usize {
        const mask = HashPairBitmask.init(hashCode);
        const maskVec: @Vector(32, u8) = @splat(mask.value);

        var i: usize = 0;
        var maskIter: usize = 0;
        while (i < self.capacity) {
            var matches: @Vector(32, bool) = self.hashMasks[maskIter] == maskVec;
            var index = std.simd.firstTrue(matches);
            while (index != null) {
                const foundKey = self.pairs[i + index.?].key;
                switch (tag) {
                    .Bool => {
                        if (foundKey.boolean == key.boolean) {
                            return i + index.?;
                        }
                    },
                    .Int => {
                        if (foundKey.int == key.int) {
                            return i + index.?;
                        }
                    },
                    .Float => {
                        if (foundKey.float == key.float) {
                            return i + index.?;
                        }
                    },
                    .String => {
                        if (foundKey.string.eql(key.string)) {
                            return i + index.?;
                        }
                    },
                    .Array => {
                        if (foundKey.array.eql(key.array)) {
                            return i + index.?;
                        }
                    },
                    else => {
                        @panic("Unsupported");
                    },
                }
                matches[index.?] = false;
                index = std.simd.firstTrue(matches);
            }

            i += 32;
            maskIter += 1;
        }
        return null;
    }

    /// If the entry already exists, will replace the existing held value with `value`.
    /// Takes ownership of `key` and `value`, setting the original references to 0.
    /// Expects that `allocator` was also used for `key` and `value`.
    fn insert(self: *Group, key: *TaggedValue, value: *TaggedValue, hashCode: usize) void {
        const existingIndex = self.find(key.value, key.tag, hashCode);
        const alreadyExists = existingIndex != null;
        if (alreadyExists) {
            self.pairs[existingIndex.?].value.deinit(value.tag);
            self.pairs[existingIndex.?].value = value.value;

            key.deinit(); // don't need duplicate.
            value.value.int = 0; // force existing reference to 0 / null, taking ownership
            return;
        }

        self.ensureTotalCapacity(self.pairCount + 1);

        // SIMD find first 0

        const mask = HashPairBitmask.init(hashCode);
        const zeroVec: @Vector(32, u8) = @splat(0);
        const selfHashMasksAsBytePtr: [*]u8 = @ptrCast(self.hashMasks);

        var i: usize = 0;
        var maskIter: usize = 0;
        while (i < self.capacity) {
            const matches: @Vector(32, bool) = self.hashMasks[maskIter] == zeroVec;
            const index = std.simd.firstTrue(matches);
            if (index == null) {
                i += 32;
                maskIter += 1;
                continue;
            } else {
                const newPair = allocator().create(Pair) catch {
                    @panic("Script out of memory");
                };
                newPair.key = key.value;
                newPair.value = value.value;
                newPair.hash = hashCode;

                key.value.int = 0; // force existing reference to 0 / null, taking ownership
                value.value.int = 0; // force existing reference to 0 / null, taking ownership

                selfHashMasksAsBytePtr[index.?] = mask.value;
                self.pairs[index.?] = newPair;
                self.pairCount += 1;

                return;
            }
        }

        unreachable;
    }

    /// Returns false if the entry doesn't exist, and true if the entry does exist and was successfully erased.
    fn erase(self: *Group, key: RawValue, keyTag: ValueTag, valueTag: ValueTag, hashCode: usize) bool {
        const found = self.find(key, keyTag, hashCode);

        if (found == null) {
            return false;
        }

        const selfHashMasksAsBytePtr: [*]u8 = @ptrCast(self.hashMasks);
        selfHashMasksAsBytePtr[found.?] = 0;
        self.pairs[found.?].key.deinit(keyTag);
        self.pairs[found.?].value.deinit(valueTag);
        allocator().destroy(self.pairs[found.?]);
        self.pairCount -= 1;

        return true;
    }

    fn ensureTotalCapacity(self: *Self, minCapacity: usize) void {
        if (minCapacity <= self.capacity) {
            return;
        }

        var mallocCapacity: usize = minCapacity;
        const rem = @mod(mallocCapacity, 32);
        if (rem != 0) {
            mallocCapacity += (32 - rem);
        }
        const allocSize = calculateChunksHashGroupAllocationSize(mallocCapacity);
        const memory = allocator().alignedAlloc(u8, ALIGNMENT, allocSize) catch {
            @panic("Script out of memory");
        };
        @memset(memory, 0);

        const hashMasks: [*]@Vector(32, u8) = @ptrCast(@alignCast(memory.ptr));
        const pairs: [*]*Pair = @ptrCast(@alignCast(&memory.ptr[mallocCapacity]));

        var movedIter: usize = 0;
        var i: usize = 0;
        for (self.hashMasksSlice()) |mask| {
            if (mask == 0) {
                i += 1;
                continue;
            }

            memory.ptr[movedIter] = mask; // use the hash masks as u8 header
            pairs[movedIter] = self.pairs[i];
            i += 1;
            movedIter += 1;
        }

        {
            const oldSlice = self.getFullAllocation();
            allocator().free(oldSlice);
        }

        self.hashMasks = hashMasks;
        self.pairs = pairs;
        self.capacity = mallocCapacity;
    }

    fn hashMasksSlice(self: Self) []u8 {
        const asBytePtr: [*]u8 = @ptrCast(self.hashMasks);
        return asBytePtr[0..self.capacity];
    }

    fn getFullAllocation(self: Self) []align(ALIGNMENT) u8 {
        const asBytePtr: [*]u8 = @ptrCast(self.hashMasks);
        const currentAllocationSize = calculateChunksHashGroupAllocationSize(self.capacity);
        return @alignCast(asBytePtr[0..currentAllocationSize]);
    }

    fn calculateChunksHashGroupAllocationSize(requiredCapacity: usize) usize {
        assert(requiredCapacity % 32 == 0);

        // number of hash masks + size of pointer * required capacity;
        return requiredCapacity + (@sizeOf(*Pair) * requiredCapacity);
    }
};

const Pair = struct {
    key: RawValue,
    value: RawValue,
    hash: usize,
};

// Tests

test "map init" {
    {
        var map = Map.init(ValueTag.Bool, ValueTag.Bool);
        defer map.deinit();
    }
    {
        var map = Map.init(ValueTag.Int, ValueTag.Bool);
        defer map.deinit();
    }
    {
        var map = Map.init(ValueTag.Bool, ValueTag.Int);
        defer map.deinit();
    }
    {
        var map = Map.init(ValueTag.String, ValueTag.Int);
        defer map.deinit();
    }
    {
        var map = Map.init(ValueTag.Int, ValueTag.String);
        defer map.deinit();
    }
    {
        var map = Map.init(ValueTag.String, ValueTag.Array);
        defer map.deinit();
    }
    {
        var map = Map.init(ValueTag.Map, ValueTag.Int);
        defer map.deinit();
    }
}

test "map find empty" {
    {
        var map = Map.init(ValueTag.String, ValueTag.Int);
        defer map.deinit();

        var findValue = TaggedValue.initString(root.String.initSliceUnchecked("hello world!"));
        defer findValue.deinit();

        try expect(map.size() == 0);
        try expect(map.find(findValue).tag() == .None);
    }
}

test "map insert one element" {
    {
        var map = Map.init(ValueTag.String, ValueTag.Int);
        defer map.deinit();

        var addKey = TaggedValue.initString(root.String.initSliceUnchecked("hello world!"));
        var addValue = TaggedValue.initInt(1);
        map.insert(&addKey, &addValue);

        var findValue = TaggedValue.initString(root.String.initSliceUnchecked("hello world!"));
        defer findValue.deinit();

        try expect(map.size() == 1);
        try expect(map.find(findValue).tag() != .None);
        const found = map.find(findValue);
        try expect(found.tag() != .None);
        switch (found.tag()) {
            .Int => {
                try expect(found.value().int == 1);
            },
            else => {
                try expect(false);
            },
        }
    }
}

test "map erase one element" {
    {
        var map = Map.init(ValueTag.String, ValueTag.Int);
        defer map.deinit();

        var addKey = TaggedValue.initString(root.String.initSliceUnchecked("hello world!"));
        var addValue = TaggedValue.initInt(1);
        map.insert(&addKey, &addValue);

        var eraseValue = TaggedValue.initString(root.String.initSliceUnchecked("hello world!"));
        defer eraseValue.deinit();

        try expect(map.erase(eraseValue));

        var findValue = TaggedValue.initString(eraseValue.value.string.clone());
        defer findValue.deinit();

        try expect(map.find(findValue).tag() == .None);
    }
}

test "Map add more than 32 elements" {
    {
        var map = Map.init(ValueTag.String, ValueTag.Int);
        defer map.deinit();

        for (0..36) |i| {
            var addKey = TaggedValue.initString(root.String.fromInt(@as(i64, @intCast(i))));
            var addValue = TaggedValue.initInt(@as(i64, @intCast(i)));

            map.insert(&addKey, &addValue);
        }
    }
    {
        var map = Map.init(ValueTag.Int, ValueTag.Float);
        defer map.deinit();

        for (0..36) |i| {
            var addKey = TaggedValue.initInt(@as(i64, @intCast(i)));
            var addValue = TaggedValue.initFloat(@floatFromInt(i));

            map.insert(&addKey, &addValue);
        }
    }
}
