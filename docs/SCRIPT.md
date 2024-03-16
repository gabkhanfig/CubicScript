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
- Vector (3 floats, Trivially copyable)

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

## Multithreading

Sync primitives, async, and threads are not provided by default, but the underlying virutal machine is thread safe (the scripts themselves may or may not be). The program that the scripts are embedded in will handle concurrency. Having a concurrency model, however, is still important for a modern programming language, running on modern highly threaded hardware. As such, there exists a way to force readonly access at the compiler level in certain contexts. These are the following.

- Const
- Mutable

In a const context, which is defined by the top level function being `const fn`, any class that implements the `Const` interface may not be mutated through the call stack. More info about this can be found down below. For example, in a game engine, this allows having a `tick()` and `mutableTick()` implementations. `tick()` can have a message collector, which will collect any future operations that need to happen, while `mutableTick()` can immediately modify data, having the concurrency properly handled by the owning program. The values referenced by references, even mutable references, may not be mutated in a const context.

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
    pub fn changeName(self: *mut Self, newName: String) {
        self.name = newName;
    }
};
```

### const fn

Const functions are a contract ensuring read-only access to classes that implement the `Const` interface. The entire callstack beginning at a `const fn` is validated to not mutate any classes that implement `Const`, as well as no mutable references to it's members. This ensures that full multithreading can be used.

Example: (using Person class from above):

```text
pub class Person { ... };

impl Const for Person;

fn getSomePerson() *mut Person { ... }

pub const fn calculateSomeStuff() {
    const person = getSomePerson(); // Example of a function that returns a mutable reference
    person.height = 15.0; // Fails to compile here, even if a valid mutable reference was returned.
}
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
    pub const fn getAge(self: *Self) Int;
};

impl Aging for Example {
    pub const fn getAge(self: *Self) Int {
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

class members will **never** be moved, only copied.

## References

Reference (pointers) are always either immutable `*` or mutable `*mut`, but in a const context, will be forced to be immutable for classes that implement the `Const` interface, even if a mutable reference is alive. Unlike rust, there are no restrictions to how many references can be alive. This is done for the sake of ease of use. Since there are no concerns with data races due to `const fn`, this is reasonable.

References have their held data be assigned, or have the actual pointer address be assigned. To assign the actual held value, the point must be dereferenced using the `variable.* =` syntax.

```text
mut value = 1; // Int
mut otherValue = 2;
    
const ptr1 = &value; // Since `value` is mut, getting a reference to it gets a mutable reference `*mut Int`
assert(ptr1 == 1); // equality will dereference the pointer

ptr1.* = otherValue; // This is ok, because it's dereferencing the pointer and modifying the held value
assert(value == otherValue);

ptr1 = &otherValue; // FAILS TO COMPILE. ptr1 is qualified as const, and thus the pointer cannot be changed.

mut ptr2 = &value;
assert(ptr2 == 2);

ptr2.* = 3; // This is ok, because it's dereferencing the pointer and modifying the held value
assert(value == 3);
assert(ptr2 == 3);

ptr2 = &otherValue; // This is ok, because ptr2 is qualified as mutable, and thus the variable can point somewhere else.
assert(ptr2 == 2);
```

Pointer arithmetic is not allowed.

References, or primitive types (Array, Map, Set) containing references, may **never** be stored in classes, with the one exception being shared references.

### Shared References

There are situations where references need to be stored, but the lifetimes of them cannot be reasonably validated on their own, especially given frame boundaries. As such, the compromise is using shared, atomic reference counted objects. Creating a new one is as simple as `Shared.new(...)`, passing in ownership (move or copy) of some value. The type of the value may not be a reference (`*` or `*mut`) type.

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
