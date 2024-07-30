#pragma once

/// # Cubic Script C++ Wrapper
/// cubic_script.hpp is guaranteed compatible with C++17 minimum, as it is sufficiently widely used:
/// - [Unreal Engine 5](https://dev.epicgames.com/documentation/en-us/unreal-engine/epic-cplusplus-coding-standard-for-unreal-engine?application_version=5.0#:~:text=Unreal%20Engine%20requires%20a%20minimum%20language%20version%20of%20C%2B%2B17%20to%20build)
/// - [Godot 4.x](https://docs.godotengine.org/en/stable/contributing/development/cpp_usage_guidelines.html#:~:text=Since%20Godot%204.0%2C%20the%20C%2B%2B%20standard%20used%20throughout%20the%20codebase%20is%20a%20subset%20of%20C%2B%2B17)
namespace cubs{}

#include "../src/primitives/script_value.hpp"
#include "../src/primitives/string/string.hpp"
#include "../src/primitives/array/array.hpp"