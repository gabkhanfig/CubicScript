# Structs

Structs in CubicScript use the C layout.

## Structs Definitions

There are two possible types of structs, being `struct` and `extern struct`. Both types of structs are allowed to have methods and trait definitions.

```txt
struct Example {
    someMember: string
}
```

Normal script structs are allowed to override builtins. More info on that down below.

### Extern Structs

There are situations where structs that are compatible with the programming language the scripts are embedded in are needed within the scripts themselves.

```txt
extern struct Example {
    someMember: string
}
```

The equivalent C struct would look like the following:

```c
typedef struct ScriptExample {
    CubsString someMember;
} ScriptExample;
```

Since it would be difficult to draw the line at what can be overridden for the struct's context, `extern struct`'s cannot have any overridden builtins.

## Builtins

Sometimes, certain "base" behaviour needs to be overridden. For example, custom behaviour on a destructor, or cloning, etc. In Rust for example, this is achieved through simple builtin traits such as [std::ops::Drop](https://doc.rust-lang.org/std/ops/trait.Drop.html). In C++ the compiler can recognize certain function definitions on a given type including operators. Unlike Rust, this is not done through traits, as it's part of the type itself more similar to an interface conceptually. Unlike C++, this is not done through specific function definitions or operator overloading. These builtins match up with the C OR script function pointers found in a type's context.

```txt
struct Example {
    a: string
    b: int 

    @destructor (self: &mut Self) {
        // Do some work
    }

    @clone (self: &Self) Self {
        return Self{.a = self.a, .b = 0}
    }

    @eql (self: &Self, other: &Self) bool {
        return self.b == other.b
    }  
}
```

The following builtins are available:

- @destructor
- @clone
- @eql

While using Rust style traits for these behaviours would be great, this is a necessary compromise because of the fact that scripts aren't in an isolated environment. They are "owned" by a process, in another language such as C, C++, Zig, or Rust. These processes, will have their own defined behaviour.

### Extern

Extern structs are not allowed to implement any builtins, as they have that behaviour defined by the host-language at script compile time.
