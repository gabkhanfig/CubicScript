# CubicScript

Files end in the `.cubs` extension.

## Primitive Types

All primitives are 8 bytes in size, and are 0 initialized by default.

- Bool (Trivially copyable)
- Int (64 bit signed, Trivially copyable)
- Float (64 bit, IEEE 754, Trivially copyable)
- String (Shared pointer to immutable data, Trivially copyable)
- Array (Unique pointer to data)
- Map (Unique pointer to data)
- Set (Unique pointer to data)
- Vec2i (Unique pointer to 2 ints {x, y})
- Vec3i (Unique pointer to 3 ints {x, y, z})
- Vec4i (Unique pointer to 4 ints {x, y, z, w})
- Vec2i (Unique pointer to 2 floats {x, y})
- Vec3i (Unique pointer to 3 floats {x, y, z})
- Vec4i (Unique pointer to 4 floats {x, y, z, w})
- Mat4f (Unique pointer to 4x4 matrix of floats)

Use rust style ownership and borrowing. If a reference exists, the value cannot be dropped.

## Keywords

const
mut
fn
return
if
else
switch
for
while
and
or
in
continue
break
import
impl
pub
enum
class
true
false
null
type
requires
extern
sync

## Multithreading

Multithreading, and thus thread safety is the number 1 priority for CubicScript. Async and threads are not provided by default (for now), but the scripts themselves are thread safe where appropriate.

### Sync Blocks

Any `Unique`, `Shared`, or `Weak` owned objects will require explicit synchronization through `sync` blocks. The compiler will validate the callstack for what classes require syncing.

```text
class Example {
    someValue: Int,
}

impl ThreadSync for Person {}

fn doSomeLogic(obj Unique(Example)) {
    obj.someValue = 1; // Compiler won't allow this because Example implements ThreadSync, UNLESS this function is ONLY called in a sync block in another function

    sync {
        obj.someValue = 1; // This is ok.
    }
}
```

*From a technical standpoint, sync blocks use RWLocks, and the compiler determines if a read or write lock should be acquired for the given class instance.*

Objects within a sync block may not be acquired due to the potential for deadlocks. A sync block must be escaped in order for new objects to be sync'd. Since since blocks are just expression blocks, values can be "returned" from them.

```text
fn getAnotherObj() Example {
    ...
}

fn doLogicOnAnotherObject(obj Shared(Example)) {
    mut otherObj = sync {
        obj.someValue = 1;
        getAnotherObj()
    }

    sync {
        otherObj.someValue = 1;
    }
}
```

Sync blocks are **not** reentrant, and compilation will fail if it's done.

```text
fn doubleSync() {
    sync {
        sync { // compilation error here
            ...
        }
    }
}

fn doubleSyncThroughFunctionCallA() {
    sync {
        doubleSyncThroughFunctionCallB(); // compilation error here due to a sync block further in the call stack
    }
}

fn doubleSyncThroughFunctionCallB() {
    sync {
        ...
    }
}
```

For calling extern functions, classes and shared references will track if they have been locked or not, so upon fetching their data, they can assert that they have been locked.

## Classes

Classes are the way data is contained. They are also just classes. Classes can implement interfaces, which will use dynamic dispatch where appropriate. Classes allocate on the heap always.

Example:

```text
// Use pub specifier to allow this class to be used by other files
pub class Person {
    // Same applies with members. pub(const) means this member is read-only outside of this file.
    pub(const) name: String,
    age: Int,
    height: Float,
};
```

## Functions

Functions can be free functions, or as a member of a class (which is technically still a free function but with some nice syntax).

Example: (using Person class from above):

```text
pub class Person { ... };

impl Person {
    // Use pub specifier to allow this function to be called by other files.
    pub fn changeName(self: &mut Self, newName: String) {
        self.name = newName;
    }
};
```

## Interfaces

Interfaces specify functions that implementing classes support. Default implementations can be specified, as well as specifying them as non-overridable. A function without an implementation must be implemented by the implementing class.
Interfaces MAYBE can also have class members. TODO decide if this is best.
Interfaces can force classes to also implement other interfaces.

Example (using Person class from above):

```text
pub class Person { ... };

// Use pub specifier to allow this interface to be used by other files.
pub interface Aging {
    // Use pub specifier to allow this interface function to be called by non-implementing classes/functions.
    pub fn getAge(self: *Self) Int;
};

impl Aging for Example {
    pub fn getAge(self: *Self) Int {
        return self.age;
    }
};
```

## Ownership

Cube Universe Script uses an ownership model, similar to rust. Variables "own" their data, and references to that data can be passed around, or copies of that data can be made.

### Copying

A type or class is considered trivially copyable if it is a trivially clonable primitive type, or a class whose members is made up of only trivially copyable primitive types. Function calling, or class member assignment follows this logic.

> Is type trivially copyable?
> Yes: copy without programmer typing `.copy()`
> No: move and invalidate existing variables

For non-trivially copyable types, they must implement the `Copy` interface, (this is done by default for trivially copyable types). This is done to make copies explicit to the programmer in situations where they can have meaningful performance implications.

Class members will **never** be moved, only copied.

## References

Reference (pointers) are always either immutable `&` or mutable `&mut`. Unlike rust, there are no restrictions to how many references can be alive. This is done for the sake of ease of use. Since classes cannot store references (excluding shared references), and lifetimes are validated in a callstack, there are no concerns with the references exceeding their lifetime.

References may not have the address they point to be reassigned ever. This is to simplify the logic for lifetime validation. References are syntactically treated as the underying object, and are thus implicitly dereferenced where appropriate.

```text
mut value = 1; // Int
mut otherValue = 2;
    
const ptr1 = &value; // Since `value` is mut, getting a reference to it gets a mutable reference `*mut Int`
assert(ptr1 == 1);

ptr1 = otherValue; // This is ok, because it's dereferencing the pointer and modifying the held value
assert(value == otherValue);

ptr1 = &otherValue; // FAILS TO COMPILE. Cannot modify the address of a pointer

mut ptr2 = &value; // Compiler warning. Reference should be marked const.
assert(ptr2 == 2);

ptr2 = 3; // This is ok, because it's dereferencing the pointer and modifying the held value
assert(value == 3);
assert(ptr2 == 3);

ptr2 = &otherValue; // FAILS TO COMPILE despite ptr2 being a mutable variable. Cannot modify the address of a pointer.
```

References, or primitive types (Array, Map, Set) containing references, may **never** be stored in classes, with the one exception being shared references.

### Unique References

Unique references own some data, and enforce thread synchronization on it. Furthermore, weak references can be created from a Unique instance, which will invalidate themselves in a thread safe way when the owning Unique instance is freed. Calling `Unique.new(...)`, passing in ownership (move or copy) of some value, will make a unique instance. The type of the value may not be a reference (`&` or `&mut`) type.

Unique references are not trivially copyable.

### Shared References

Shared references use atomic reference counting to share ownership of some data, and enforce thread synchronization on it. There can be multiple owners of the same Shared data, destroying the actual data when there are no more alive Shared references. Furthermore, weak references can be created from a Shared instance, which will invalidate themselves in a thread safe way when the owning Shared instance is freed. Calling `Shared.new(...)`, passing in ownership (move or copy) of some value, will make a unique instance. The type of the value may not be a reference (`&` or `&mut`) type. Trying to acquire the same Shared object in the same `sync` block is fine, as the second acquisition will be ignored.

Shared references are trivially copyable.

Example:

```text
class SharedRefExample {
    someData: Shared(Int)
};

fn doSomeStuff() {
    const value = 1;

    mut sharedValue1 = Shared.new(value);
    assert(sharedValue1 == 1);

    const sharedValue2 = sharedValue1; // Trivially copy sharedValue1
    assert(sharedValue2 == 1);

    const sharedValue3 = SharedRefExample{.someData = sharedValue1};
    assert(sharedValue3.someData == 1);

    sharedValue1 = 2;
    assert(sharedValue1 == 2);
    assert(sharedValue2 == 2);
    assert(sharedValue3.someData == 2);

    const otherValue = 3;

    // This will fail to compile, since shared references must have ownership of the data.
    const willNotCompile = Shared.new(&otherValue);
}
```

### Weak References

Weak references can be created from both Unique and Shared references, being opaque as to the origin for simplicity. Weak references use atomic reference counting similar to a Shared instance, but uses a distinct reference counter for the weak reference. If the owning Unique or Shared data is destroyed, the weak reference becomes invalid. Accessing the weak reference data requires checking if it's valid, along with using `sync` blocks. Syncing a weak reference and a Unique/Shared that own the same data is fine, and the second acquisition will be ignored.

## Enums

Normal enums (not tagged unions) are 8 bytes in size.

```text
enum Happiness {
    Happy,
    Neutral,
    Sad,
}
```

### Tagged Unions

Enums can also be tagged unions, in which they carry additional data. The size of these enums is 8 + the size of the largest type.

```text
enum IpAddress {
    V4(String),
    V6(String),
}

const examplev4 = IpAddress.V4("127.0.0.1");
const examplev6 = IpAddress.V6("::1");

// Tagged unions don't have to have additional data for a field

class Flight {
    speed: Float,
    airResistance: Float,
}

enum Movement {
    Stationary,
    Running(Float),
    Flying(Flight),
}
```

## Null

All types are not nullable. Nullability is only present in the case of option types. It is an error to get the optional value when it is `null`.

Calling the operator `.?` will get a mutable reference to the held option data. To explicitly take ownership of the optional, call `.take()`.

### Null Primitives

Optional primitives will have their "some" data allocated to the heap, so if the optional is null, it's holding a null pointer.

### Null Classes

Optional classes just means the pointer to the class may be null.
