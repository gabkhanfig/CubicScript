const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const expect = std.testing.expect;
const primitives = @import("primitives.zig");
const PrimitiveValue = primitives.Value;
const ValueTag = primitives.ValueTag;
const Int = primitives.Int;
const hash = @import("hash.zig");
const HashGroupBitmask = hash.HashGroupBitmask;
const HashPairBitmask = hash.HashPairBitmask;
const computeHash = hash.computeHash;
const TaggedValue = primitives.TaggedValue;

pub const Map = extern struct {
    const Self = @This();
    const PTR_BITMASK = 0xFFFFFFFFFFFF;
    const KEY_TAG_BITMASK: usize = @shlExact(@as(usize, 0xFF), 48);
    const VALUE_TAG_BITMASK: usize = @shlExact(@as(usize, 0xFF), 56);
    const VALUE_SHIFT = 8;

    inner: usize,

    /// Initialize a new Map instance.
    pub fn init(inKeyTag: ValueTag, inValueTag: ValueTag) Self {
        const keyTagInt: usize = @intFromEnum(inKeyTag);
        const valueTagInt: usize = @intFromEnum(inValueTag);
        return Self{ .inner = @shlExact(keyTagInt, 48) | @shlExact(valueTagInt, 56) };
    }

    /// Free the memory allocated for this map, as well as deinit'ing the values it owns.
    pub fn deinit(self: *Self, allocator: Allocator) void {
        if (self.asInnerMut()) |inner| {
            for (inner.groups) |*group| {
                group.deinit(allocator, self.keyTag(), self.valueTag());
            }
            allocator.free(inner.groups);
            allocator.destroy(inner);
            self.inner = 0;
        }
    }

    pub fn keyTag(self: *const Self) ValueTag {
        const mask = self.inner & KEY_TAG_BITMASK;
        return @enumFromInt(@shrExact(mask, 48));
    }

    pub fn valueTag(self: *const Self) ValueTag {
        const mask = self.inner & VALUE_TAG_BITMASK;
        return @enumFromInt(@shrExact(mask, 56));
    }

    /// Get the number of entries in the hashmap.
    pub fn size(self: *const Self) Int {
        if (self.asInner()) |inner| {
            return @intCast(inner.count);
        } else {
            return 0;
        }
    }

    /// The returned reference may become invalidated when this `Map` is mutated.
    pub fn find(self: *const Self, key: TaggedValue) ?primitives.TaggedValueConstRef {
        assert(key.tag == self.keyTag());

        if (self.asInner()) |inner| {
            const hashCode = computeHash(&key.value, key.tag, hash.TEST_SEED_VALUE);
            const groupBitmask = HashGroupBitmask.init(hashCode);
            const groupIndex = @mod(groupBitmask.value, inner.groups.len);

            const found = inner.groups[groupIndex].find(key.value, key.tag, hashCode);
            if (found == null) {
                return null;
            }

            return .{ .tag = self.valueTag(), .value = &inner.groups[groupIndex].pairs[found.?].value };
        } else {
            return null;
        }
    }

    /// The returned reference may become invalidated when this `Map` is mutated.
    pub fn findMut(self: *Self, key: TaggedValue) ?primitives.TaggedValueMutRef {
        assert(key.tag == self.keyTag());

        if (self.asInner()) |inner| {
            const hashCode = computeHash(&key.value, key.tag, hash.TEST_SEED_VALUE);
            const groupBitmask = HashGroupBitmask.init(hashCode);
            const groupIndex = @mod(groupBitmask.value, inner.groups.len);

            const found = inner.groups[groupIndex].find(key.value, key.tag, hashCode);
            if (found == null) {
                return null;
            }

            return .{ .tag = self.valueTag(), .value = &inner.groups[groupIndex].pairs[found.?].value };
        } else {
            return null;
        }
    }

    /// If the entry already exists, will replace the existing held value with `value`.
    /// Takes ownership of `key` and `value`, setting the original references to 0.
    /// Expects that `allocator` was also used for `key` and `value`.
    pub fn insert(self: *Self, key: *TaggedValue, value: *TaggedValue, allocator: Allocator) Allocator.Error!void {
        assert(key.tag == self.keyTag());
        assert(value.tag == self.valueTag());

        const elemSize = self.size();
        try self.ensureTotalCapacity(@as(usize, @intCast(elemSize)) + 1, allocator);

        if (self.asInnerMut()) |inner| {
            const hashCode = computeHash(&key.value, key.tag, hash.TEST_SEED_VALUE);
            const groupBitmask = HashGroupBitmask.init(hashCode);
            const groupIndex = @mod(groupBitmask.value, inner.groups.len);

            try inner.groups[groupIndex].insert(key, value, hashCode, allocator);
            inner.count += 1;
        } else {
            unreachable;
        }
    }

    /// Returns true if the entry `key` exists, and thus was successfully deleted and cleaned up,
    /// and returns false if the entry doesn't exist.
    pub fn erase(self: *Self, key: TaggedValue, allocator: Allocator) bool {
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

            return inner.groups[groupIndex].erase(key.value, key.tag, allocator);
        } else {
            unreachable;
        }
    }

    fn asInner(self: *const Self) ?*const Inner {
        return @ptrFromInt(self.inner & PTR_BITMASK);
    }

    fn asInnerMut(self: *Self) ?*Inner {
        return @ptrFromInt(self.inner & PTR_BITMASK);
    }

    fn ensureTotalCapacity(self: *Self, minCapacity: usize, allocator: Allocator) Allocator.Error!void {
        if (!self.shouldReallocate(minCapacity)) {
            return;
        }

        const newGroupCount = calculateNewGroupCount(minCapacity);
        if (self.asInner()) |inner| {
            if (newGroupCount <= inner.groups.len) {
                return;
            }
        }

        const newGroups = try allocator.alloc(Group, newGroupCount);
        for (0..newGroups.len) |i| {
            newGroups[i] = try Group.init(allocator);
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

                    try newGroup.ensureTotalCapacity(newGroup.pairCount + 1, allocator);

                    const newHashMasksAsBytePtr: [*]u8 = @ptrCast(newGroup.hashMasks);

                    newHashMasksAsBytePtr[newGroup.pairCount] = hashMask;
                    newGroup.pairs[newGroup.pairCount] = pair; // move pair allocation
                    newGroup.pairCount += 1;
                }

                const oldGroupAllocation = oldGroup.getFullAllocation();
                allocator.free(oldGroupAllocation);
            }

            if (inner.groups.len > 0) {
                allocator.free(inner.groups);
            }

            inner.groups = newGroups;
        } else {
            const newInner = try allocator.create(Inner);
            newInner.groups = newGroups;
            newInner.count = 0;

            self.inner = (self.inner & (KEY_TAG_BITMASK | VALUE_TAG_BITMASK)) | @intFromPtr(newInner);
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

    fn init(allocator: Allocator) Allocator.Error!Self {
        const memory = try allocator.alignedAlloc(u8, ALIGNMENT, INITIAL_ALLOCATION_SIZE);
        @memset(memory, 0);

        const hashMasks: [*]@Vector(32, u8) = @ptrCast(@alignCast(memory.ptr));
        const pairs: [*]*Pair = @ptrCast(@alignCast(&memory.ptr[GROUP_ALLOC_SIZE]));

        return Group{
            .hashMasks = hashMasks,
            .pairs = pairs,
        };
    }

    fn deinit(self: *Self, allocator: Allocator, keyTag: ValueTag, valueTag: ValueTag) void {
        var i: usize = 0;
        for (self.hashMasksSlice()) |mask| {
            if (mask == 0) {
                i += 1;
                continue;
            }

            self.pairs[i].key.deinit(keyTag, allocator);
            self.pairs[i].value.deinit(valueTag, allocator);
            allocator.destroy(self.pairs[i]);
            i += 1;
        }
        allocator.free(self.getFullAllocation());
        // Ensure that any use after free will be caught.
        self.hashMasks = undefined;
        self.pairs = undefined;
        self.pairCount = undefined;
        self.capacity = undefined;
    }

    fn find(self: *const Self, key: PrimitiveValue, tag: ValueTag, hashCode: usize) ?usize {
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
    fn insert(self: *Group, key: *TaggedValue, value: *TaggedValue, hashCode: usize, allocator: Allocator) Allocator.Error!void {
        const existingIndex = self.find(key.value, key.tag, hashCode);
        const alreadyExists = existingIndex != null;
        if (alreadyExists) {
            self.pairs[existingIndex.?].value.deinit(value.tag, allocator);
            self.pairs[existingIndex.?].value = value.value;

            key.deinit(allocator); // don't need duplicate.
            value.value.int = 0; // force existing reference to 0 / null, taking ownership
            return;
        }

        try self.ensureTotalCapacity(self.pairCount + 1, allocator);

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
                const newPair = try allocator.create(Pair);
                newPair.key = key.value;
                newPair.value = value.value;
                newPair.hash = hashCode;

                key.value.int = 0; // force existing reference to 0 / null, taking ownership
                value.value.int = 0; // force existing reference to 0 / null, taking ownership

                selfHashMasksAsBytePtr[i] = mask.value;
                self.pairs[i] = newPair;
                self.pairCount += 1;

                return;
            }
        }

        unreachable;
    }

    /// Returns false if the entry doesn't exist, and true if the entry does exist and was successfully erased.
    fn erase(self: *Group, key: PrimitiveValue, tag: ValueTag, hashCode: usize, allocator: Allocator) bool {
        const found = self.find(key, tag, hashCode);

        if (found == null) {
            return false;
        }

        const selfHashMasksAsBytePtr: [*]u8 = @ptrCast(self.hashMasks);
        selfHashMasksAsBytePtr[found.?] = 0;
        allocator.destroy(self.pairs[found.?]);
        self.pairCount -= 1;

        if (self.pairCount == 0) {
            const currentAllocationSize = calculateChunksHashGroupAllocationSize(self.capacity);

            var allocSlice: []align(ALIGNMENT) u8 = undefined;
            allocSlice.ptr = @ptrCast(self.hashMasks);
            allocSlice.len = currentAllocationSize;

            allocator.free(allocSlice);
            allocator.destroy(self);
        }

        return true;
    }

    fn ensureTotalCapacity(self: *Self, minCapacity: usize, allocator: Allocator) Allocator.Error!void {
        if (minCapacity <= self.capacity) {
            return;
        }

        var mallocCapacity: usize = minCapacity;
        const rem = @mod(mallocCapacity, 32);
        if (rem != 0) {
            mallocCapacity += (32 - rem);
        }
        const allocSize = calculateChunksHashGroupAllocationSize(mallocCapacity);
        const memory = try allocator.alignedAlloc(u8, ALIGNMENT, allocSize);
        @memset(memory, 0);

        const hashMasks: [*]@Vector(32, u8) = @ptrCast(@alignCast(memory.ptr));
        const pairs: [*]*Pair = @ptrCast(memory.ptr + GROUP_ALLOC_SIZE);

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
            allocator.free(oldSlice);
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
    key: PrimitiveValue,
    value: PrimitiveValue,
    hash: usize,
};

// Tests

test "map init" {
    const allocator = std.testing.allocator;
    {
        var map = Map.init(ValueTag.Bool, ValueTag.Bool);
        defer map.deinit(allocator);
    }
    {
        var map = Map.init(ValueTag.Int, ValueTag.Bool);
        defer map.deinit(allocator);
    }
    {
        var map = Map.init(ValueTag.Bool, ValueTag.Int);
        defer map.deinit(allocator);
    }
    {
        var map = Map.init(ValueTag.String, ValueTag.Int);
        defer map.deinit(allocator);
    }
    {
        var map = Map.init(ValueTag.Int, ValueTag.String);
        defer map.deinit(allocator);
    }
    {
        var map = Map.init(ValueTag.String, ValueTag.Array);
        defer map.deinit(allocator);
    }
    {
        var map = Map.init(ValueTag.Map, ValueTag.Int);
        defer map.deinit(allocator);
    }
}

test "map find empty" {
    const allocator = std.testing.allocator;
    {
        var map = Map.init(ValueTag.String, ValueTag.Int);
        defer map.deinit(allocator);

        var findValue = TaggedValue.initString(try primitives.String.initSlice("hello world!", allocator));
        defer findValue.deinit(allocator);

        try expect(map.find(findValue) == null);
    }
}

test "map insert one element" {
    const allocator = std.testing.allocator;
    {
        var map = Map.init(ValueTag.String, ValueTag.Int);
        defer map.deinit(allocator);

        var addKey = TaggedValue.initString(try primitives.String.initSlice("hello world!", allocator));
        var addValue = TaggedValue.initInt(1);
        try map.insert(&addKey, &addValue, allocator);

        var findValue = TaggedValue.initString(try primitives.String.initSlice("hello world!", allocator));
        defer findValue.deinit(allocator);

        try expect(map.find(findValue) != null);
    }
}
