# Cubic Script Syntax

Here are examples of the syntax

## Variables

### Mutable Variable Declarations

```txt
// mutable variable. compiler figures out is type `int`
var example1 = 1

// since `example1` is mutable, it can be reassigned to another value of the same type. in this case, an int
example1 = 2
// but cannot be assigned a value of a different type
example1 = "hello" // <- compilation error cannot assign string to int
```

### Immutable Variable Declarations

```txt
// immutable variable. compiler figures out is type `int`
const example2 = 1

// since `example2` is immutable, it cannot be reassigned to another value of the same type (or any other type).
example2 = 2 // <- compilation error cannot assign to constant value
// and naturally cannot be assigned a value of a different type either
example2 = "hello" // <- compilation error cannot assign string to int
```
