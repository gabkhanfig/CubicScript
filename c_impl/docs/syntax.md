# Cubic Script Syntax

Here are examples of the syntax

## Variables

### Mutable Variables

```txt
// mutable variable. compiler figures out is type `int`
mut example1 = 1

// since `example1` is mutable, it can be reassigned to another value of the same type. in this case, an int
example1 = 2
// but cannot be assigned a value of a different type
example1 = "hello" // <- compilation error cannot assign string to int
```

### Immutable Variables

```txt
// immutable variable. compiler figures out is type `int`
const example2 = 1

// since `example2` is immutable, it cannot be reassigned to another value of the same type (or any other type)
example2 = 2 // <- compilation error cannot assign to constant value
// and naturally cannot be assigned a value of a different type either
example2 = "hello" // <- compilation error cannot assign string to int
```

### Manual Type Declaration

```txt
// Types can be explicitly set to variables
mut example3: int = 1

// If no value is specified, uses the type's zero/null value if it has one
mut example3: int
assert(example3 == 0)
// string's zero value is just ""
mut example4: string
assert(example4 == "")
```

## References

References `&` are mutable by default, requiring an explicit `mut` keyword to make them mutable, similar to Rust (`&mut`). This is done because in `sync` situations, having immutable by default means the compiler will be guaranteed to use shared locking by default.

References act as if you are handling their underlying data, rather than handling the pointer itself.

### Mutable References

```txt
mut example = 1

// Take a mutable reference and assign it to `refExample`
const refExample = &mut example
// The same as `const refExample :&mut int = &mut example

refExample = 2 // Assign the referenced memory to something else
assert(example == 2)
```

### Immutable References

```txt
const example = 1

// Take an immutable reference and assign it to `refExample`
const refExample = &example
// The same as `const refExample :&int = &example

// Since it's an immutable reference, cannot assign to it
refExample = 2 // <- compilation error cannot assign to immutable reference
```
