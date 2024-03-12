# CubicScript

Embeddable Scripting Language For Multiplayer Games

## Build and Install

CubicScript currently only supports zig modules. In the future, a full static library will be available, with a C header.

### Integration Into A Zig Project

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
