# CubicScript

Embeddable Scripting Language For Multiplayer Games

## Build and Install

### Manual

CubicScript does not require any special build steps, only a C compiler. As a result, you are safe to just drop in the source code directly into any project.

From there, include one of the following headers:

C: `#include "(relative_install_location)/include/cubic_script.h"`

C++: `#include "(relative_install_location)/include/cubic_script.hpp"

#### Making Custom Abstraction Layer

All of the functions/symbols that are intended for API use are accessible from `include/cubic_script.h`. These symbols will also be found in the 

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
