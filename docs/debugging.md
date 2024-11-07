# Debugging

## Development of CubicScript

Being able to debug during development of the language is invaluable.

### LLDB

Within VsCode, the [launch.json](https://github.com/gabkhanfig/CubicScript/tree/main/.vscode/launch.json) file already contains the necessary steps to start debugging with [LLDB](https://lldb.llvm.org/).

### Other Debuggers

Running `zig build` will generate both the Zig and C++ executables along with their debug symbols. Both can be found relative to the project working directory `/zig-out/test/`.
