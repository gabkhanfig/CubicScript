# Structs

Structs in CubicScript use the C layout. There are two possible types of structs, being `struct` and `extern struct`.

## Script Structs

Normal script `struct`'s are allowed to define methods, and inherit interfaces.

## Extern Structs

There are situations where structs that are compatible with the programming language the scripts are embedded in are needed within the scripts themselves. Since it would be difficult to draw the line at what can be overridden for the struct's context, `extern struct`'s cannot have any overridden behaviour. They cannot implement any interfaces, and can only use `extern fn` methods, which have no declaration, only the definition. Upon compiling the scripts, these extern structs must have their type information passed in.

## Builtins

A struct can implement some custom builtin behaviour, overridding the default one. Unlike Rust, this is not done through traits, as it's part of the type itself more similar to an interface conceptually. Unlike C++, this is not done through specific function definitions or operator overloading.

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

The following builtins are available

- @destructor
- @clone
- @eql

### Extern

Sometimes, certain "base" behaviour needs to be overridden. For example, custom behaviour on a destructor, or cloning, etc. In Rust for example, this is achieved through simple builtin traits such as [std::ops::Drop](https://doc.rust-lang.org/std/ops/trait.Drop.html). In C++ the compiler can recognize certain function definitions on a given type including operators.

Any struct defined within a script is able to implement these builtins for custom behaviour.

The language that the scripts are embedded in can implement some of that behaviour itself, such as a custom C++ destructor for a struct. As such, any struct defined in a script that implements custom behaviour for these builtins may not be used for extern calls, and will emit a compiler error.

