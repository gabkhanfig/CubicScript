# CubicScript

Embeddable Scripting Language For Cross Platform Multiplayer Games

Minimum supported compiler versions for all platforms.

- C: C11
- C++: C++17 and C11
- Zig: 0.13.0
- Rust: SOON

*These are the minimum compiler version for the provided language specific abstractions. In practice, as long as you have a C11 compiler, and can link to the static library, any language with any language specific compiler version is fine.*

## Build and Install

### Manual

CubicScript does not require any special build steps, only a C11 compiler. As a result, you are safe to just drop in the source code directly into any project.

From there, include one of the following headers:

C: `#include "(relative_install_location)/include/cubic_script.h"`

C++: `#include "(relative_install_location)/include/cubic_script.hpp"`

#### Making Custom Abstraction Layer

All of the functions/symbols that are intended for API use are accessible from `include/cubic_script.h`. You will need to link the static library and declare the specific extern C symbols.

### CMake

#### Command Line

CubicScript is build with cmake similar to any other cmake project that generates a static library.
*Tested for windows, mac, and linux*

```bash
# From the install location

mkdir build
cd build
cmake ..
cmake --build .
```

Then link the output `CubicScript.lib` or `CubicScript.a` file depending on your platform, and set the correct include directory to `(relative_install_location)/CubicScript/include`

C: `#include <cubic_script.h>`

C++: `#include <cubic_script.hpp>`

#### Include In CMake Project

```cmake
add_subdirectory ("(relative_install_location)/CubicScript")
```

C: `#include <cubic_script.h>`

C++: `#include <cubic_script.hpp>`

### C

Use the compilation and linker steps described above. The API can be accessed through `cubic_script.h`, with all the functions starting with `cubs_` and all constants starting with `CUBS_`.

### C++

Use the compilation and linker steps described above. The API can be accessed through `cubic_script.hpp`, with everything being within the `cubs` namespace. There is also the `cubs::c` namespace for easy access to the C symbols without having to clutter the global namespace. You may also choose to just use `cubic_script.h`, in which all symbols are wrapped in `extern "C"` blocks where appropriate to be including in a C++ file without issue.

### Zig

First, add the git archive url into your projects build.zig.zon file.

```zig
// build.zig.zon
...
    .dependencies = .{
        .cubic_script = .{
            .url = "INSERT GIT TAG URL",
        },
    },
```

Next, run `zig build`. In the command line, there should be an error saying `error: dependency is missing hash field`, along with the expected hash. Copy the `.hash = "...",` under the `.url` field.

```zig
// build.zig.zon
...
    .dependencies = .{
        .cubic_script = .{
            .url = "INSERT GIT TAG URL",
            .hash = "THE HASH FROM THE ERROR",
        },
    },
```

Next, in the build.zig file, add the dependency, and then import the `cubic_script` module to your artifact.

```zig
// build.zig
...
const cubic_script_dependency = b.dependency("cubic_script", .{});
my_exe_or_lib_or_test.root_module.addImport("cubic_script", cubic_script_dependency.module("cubic_script"));
```

Lastly, in any file that is part of that artifact, import `"cubic_script"`.

```zig
// main.zig
const cubic_script = @import("cubic_script");
```

That's all!

### Rust

COMING SOON
