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

/// This is the hashset implementation for scripts.
/// Corresponds with the struct `CubsSet` in `cubic_script.h`.
pub const Set = extern struct {
    const Self = @This();
    const PTR_BITMASK = 0xFFFFFFFFFFFF;
    const KEY_TAG_BITMASK: usize = @shlExact(@as(usize, 0xFF), 48);

    inner: ?*anyopaque,

    /// Initialize a new Set instance.
    pub fn init(inKeyTag: ValueTag) Self {
        const keyTagInt: usize = @intCast(@intFromEnum(inKeyTag));
        return Self{ .inner = @ptrFromInt(@shlExact(keyTagInt, 48)) };
    }

    /// Free the memory allocated for this set, as well as deinit'ing the values it owns.
    pub fn deinit(self: *Self) void {
        if (self.asInnerMut()) |inner| {
            for (inner.groups) |*group| {
                group.deinit(self.keyTag());
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

    /// Get the number of entries in the hashset.
    pub fn size(self: *const Self) usize {
        if (self.asInner()) |inner| {
            return inner.count;
        } else {
            return 0;
        }
    }

    /// Check if the set contains `key`.
    pub fn contains(self: *const Self, key: TaggedValue) bool {
        assert(key.tag == self.keyTag());

        if (self.asInner()) |inner| {
            const hashCode = computeHash(&key.value, key.tag, hash.TEST_SEED_VALUE);
            const groupBitmask = HashGroupBitmask.init(hashCode);
            const groupIndex = @mod(groupBitmask.value, inner.groups.len);

            const found = inner.groups[groupIndex].find(key.value, key.tag, hashCode);
            if (found == null) {
                return false;
            }

            return true;
        } else {
            return false;
        }
    }

    /// If the entry already exists, will deinit `key`.
    /// Takes ownership of `key`, setting the original references to 0.
    pub fn insert(self: *Self, key: *TaggedValue) void {
        assert(key.tag == self.keyTag());

        const elemSize = self.size();
        self.ensureTotalCapacity(@as(usize, @intCast(elemSize)) + 1);

        if (self.asInnerMut()) |inner| {
            const hashCode = computeHash(&key.value, key.tag, hash.TEST_SEED_VALUE);
            const groupBitmask = HashGroupBitmask.init(hashCode);
            const groupIndex = @mod(groupBitmask.value, inner.groups.len);

            inner.groups[groupIndex].insert(key, hashCode);
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

            return inner.groups[groupIndex].erase(key.value, key.tag, hashCode);
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

                    const key = oldGroup.keys[i];
                    const groupBitmask = HashGroupBitmask.init(key.hash);
                    const groupIndex = @mod(groupBitmask.value, inner.groups.len);

                    const newGroup = &newGroups[groupIndex];

                    newGroup.ensureTotalCapacity(newGroup.count + 1);

                    const newHashMasksAsBytePtr: [*]u8 = @ptrCast(newGroup.hashMasks);

                    newHashMasksAsBytePtr[newGroup.count] = hashMask;
                    newGroup.keys[newGroup.count] = key; // move pair allocation
                    newGroup.count += 1;
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

            self.inner = @ptrFromInt((@intFromPtr(self.inner) & KEY_TAG_BITMASK) | @intFromPtr(newInner));
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
    const INITIAL_ALLOCATION_SIZE = calculateHashGroupAllocationSize(GROUP_ALLOC_SIZE);
    const ALIGNMENT = 32;

    hashMasks: [*]@Vector(32, u8),
    keys: [*]*KeyAndHash,
    count: usize = 0,
    capacity: usize = GROUP_ALLOC_SIZE,

    fn init() Self {
        const memory = allocator().alignedAlloc(u8, ALIGNMENT, INITIAL_ALLOCATION_SIZE) catch {
            @panic("Script out of memory");
        };
        @memset(memory, 0);

        const hashMasks: [*]@Vector(32, u8) = @ptrCast(@alignCast(memory.ptr));
        const keys: [*]*KeyAndHash = @ptrCast(@alignCast(&memory.ptr[GROUP_ALLOC_SIZE]));

        return Group{
            .hashMasks = hashMasks,
            .keys = keys,
        };
    }

    fn deinit(self: *Self, keyTag: ValueTag) void {
        var i: usize = 0;
        if (self.count > 0) {
            for (self.hashMasksSlice()) |mask| {
                if (mask == 0) {
                    i += 1;
                    continue;
                }

                self.keys[i].key.deinit(keyTag);
                allocator().destroy(self.keys[i]);
                i += 1;
            }
        }
        allocator().free(self.getFullAllocation());
        // Ensure that any use after free will be caught.
        self.hashMasks = undefined;
        self.keys = undefined;
        self.count = undefined;
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
                const foundKey = self.keys[i + index.?].key;
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
    fn insert(self: *Group, key: *TaggedValue, hashCode: usize) void {
        const existingIndex = self.find(key.value, key.tag, hashCode);
        const alreadyExists = existingIndex != null;
        if (alreadyExists) {
            key.deinit(); // don't need duplicate.
            return;
        }

        self.ensureTotalCapacity(self.count + 1);

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
                const newKeyEntry = allocator().create(KeyAndHash) catch {
                    @panic("Script out of memory");
                };
                newKeyEntry.key = key.value;
                newKeyEntry.hash = hashCode;

                key.value.int = 0; // force existing reference to 0 / null, taking ownership

                selfHashMasksAsBytePtr[index.?] = mask.value;
                self.keys[index.?] = newKeyEntry;
                self.count += 1;

                return;
            }
        }

        unreachable;
    }

    /// Returns false if the entry doesn't exist, and true if the entry does exist and was successfully erased.
    fn erase(self: *Group, key: RawValue, keyTag: ValueTag, hashCode: usize) bool {
        const found = self.find(key, keyTag, hashCode);

        if (found == null) {
            return false;
        }

        const selfHashMasksAsBytePtr: [*]u8 = @ptrCast(self.hashMasks);
        selfHashMasksAsBytePtr[found.?] = 0;
        self.keys[found.?].key.deinit(keyTag);
        allocator().destroy(self.keys[found.?]);
        self.count -= 1;

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
        const allocSize = calculateHashGroupAllocationSize(mallocCapacity);
        const memory = allocator().alignedAlloc(u8, ALIGNMENT, allocSize) catch {
            @panic("Script out of memory");
        };
        @memset(memory, 0);

        const hashMasks: [*]@Vector(32, u8) = @ptrCast(@alignCast(memory.ptr));
        const keys: [*]*KeyAndHash = @ptrCast(@alignCast(&memory.ptr[mallocCapacity]));

        var movedIter: usize = 0;
        var i: usize = 0;
        for (self.hashMasksSlice()) |mask| {
            if (mask == 0) {
                i += 1;
                continue;
            }

            memory.ptr[movedIter] = mask; // use the hash masks as u8 header
            keys[movedIter] = self.keys[i];
            i += 1;
            movedIter += 1;
        }

        {
            const oldSlice = self.getFullAllocation();
            allocator().free(oldSlice);
        }

        self.hashMasks = hashMasks;
        self.keys = keys;
        self.capacity = mallocCapacity;
    }

    fn hashMasksSlice(self: Self) []u8 {
        const asBytePtr: [*]u8 = @ptrCast(self.hashMasks);
        return asBytePtr[0..self.capacity];
    }

    fn getFullAllocation(self: Self) []align(ALIGNMENT) u8 {
        const asBytePtr: [*]u8 = @ptrCast(self.hashMasks);
        const currentAllocationSize = calculateHashGroupAllocationSize(self.capacity);
        return @alignCast(asBytePtr[0..currentAllocationSize]);
    }

    fn calculateHashGroupAllocationSize(requiredCapacity: usize) usize {
        assert(requiredCapacity % 32 == 0);

        // number of hash masks + size of pointer * required capacity;
        return requiredCapacity + (@sizeOf(*KeyAndHash) * requiredCapacity);
    }
};

const KeyAndHash = struct {
    key: RawValue,
    hash: usize,
};

// Tests

test "set init" {
    inline for (@typeInfo(ValueTag).Enum.fields) |f| {
        var set = Set.init(@enumFromInt(f.value));
        defer set.deinit();
    }
}

test "set contains empty" {
    var set = Set.init(ValueTag.String);
    defer set.deinit();

    var findValue = TaggedValue.initString(root.String.initSliceUnchecked("hello world!"));
    defer findValue.deinit();

    try expect(set.size() == 0);
    try expect(set.contains(findValue) == false);
}

test "set insert one element" {
    var set = Set.init(ValueTag.String);
    defer set.deinit();

    var addKey = TaggedValue.initString(root.String.initSliceUnchecked("hello world!"));
    set.insert(&addKey);

    var findValue = TaggedValue.initString(root.String.initSliceUnchecked("hello world!"));
    defer findValue.deinit();

    try expect(set.size() == 1);
    try expect(set.contains(findValue));
}

test "set erase one element" {
    var set = Set.init(ValueTag.String);
    defer set.deinit();

    var addKey = TaggedValue.initString(root.String.initSliceUnchecked("hello world!"));
    set.insert(&addKey);

    var eraseValue = TaggedValue.initString(root.String.initSliceUnchecked("hello world!"));
    defer eraseValue.deinit();

    try expect(set.erase(eraseValue));

    var findValue = TaggedValue.initString(root.String.initSliceUnchecked("hello world!"));
    defer findValue.deinit();

    try expect(set.size() == 0);
    try expect(set.contains(findValue) == false);
}

test "set add more than 32 elements" {
    {
        var set = Set.init(ValueTag.String);
        defer set.deinit();

        for (0..36) |i| {
            var addKey = TaggedValue.initString(root.String.fromInt(@as(i64, @intCast(i))));
            set.insert(&addKey);
        }
    }
    {
        var set = Set.init(ValueTag.Int);
        defer set.deinit();

        for (0..36) |i| {
            var addKey = TaggedValue.initInt(@as(i64, @intCast(i)));
            set.insert(&addKey);
        }
    }
}
