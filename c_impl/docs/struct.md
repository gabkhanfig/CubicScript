# Structs

Structs in CubicScript use the C layout. There are two possible types of structs, being `struct` and `extern struct`.

## Script Structs

Normal script `struct`'s are allowed to define methods, and inherit interfaces.

## Extern Structs

There are situations where structs that are compatible with the programming language the scripts are embedded in are needed within the scripts themselves. Since it would be difficult to draw the line at what can be overridden for the struct's context, `extern struct`'s cannot have any overridden behaviour. They cannot implement any interfaces, and can only use `extern fn` methods, which have no declaration, only the definition. Upon compiling the scripts, these extern structs must have their type information passed in.
