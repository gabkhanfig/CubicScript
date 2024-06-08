#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "../script_value.h"

CubsVec2i cubs_vec2i_add(const CubsVec2i* self, const CubsVec2i* vec);

CubsVec2i cubs_vec2i_add_scalar(const CubsVec2i* self, int64_t scalar);

CubsVec2i cubs_vec2i_sub(const CubsVec2i* self, const CubsVec2i* vec);

CubsVec2i cubs_vec2i_sub_scalar(const CubsVec2i* self, int64_t scalar);

CubsVec2i cubs_vec2i_mul(const CubsVec2i* self, const CubsVec2i* vec);

CubsVec2i cubs_vec2i_mul_scalar(const CubsVec2i* self, int64_t scalar);

CubsVec2i cubs_vec2i_div(const CubsVec2i* self, const CubsVec2i* vec);

CubsVec2i cubs_vec2i_div_scalar(const CubsVec2i* self, int64_t scalar);


CubsVec3i cubs_vec3i_add(const CubsVec3i* self, const CubsVec3i* vec);

CubsVec3i cubs_vec3i_add_scalar(const CubsVec3i* self, int64_t scalar);

CubsVec3i cubs_vec3i_sub(const CubsVec3i* self, const CubsVec3i* vec);

CubsVec3i cubs_vec3i_sub_scalar(const CubsVec3i* self, int64_t scalar);

CubsVec3i cubs_vec3i_mul(const CubsVec3i* self, const CubsVec3i* vec);

CubsVec3i cubs_vec3i_mul_scalar(const CubsVec3i* self, int64_t scalar);

CubsVec3i cubs_vec3i_div(const CubsVec3i* self, const CubsVec3i* vec);

CubsVec3i cubs_vec3i_div_scalar(const CubsVec3i* self, int64_t scalar);


CubsVec4i cubs_vec4i_add(const CubsVec4i* self, const CubsVec4i* vec);

CubsVec4i cubs_vec4i_add_scalar(const CubsVec4i* self, int64_t scalar);

CubsVec4i cubs_vec4i_sub(const CubsVec4i* self, const CubsVec4i* vec);

CubsVec4i cubs_vec4i_sub_scalar(const CubsVec4i* self, int64_t scalar);

CubsVec4i cubs_vec4i_mul(const CubsVec4i* self, const CubsVec4i* vec);

CubsVec4i cubs_vec4i_mul_scalar(const CubsVec4i* self, int64_t scalar);

CubsVec4i cubs_vec4i_div(const CubsVec4i* self, const CubsVec4i* vec);

CubsVec4i cubs_vec4i_div_scalar(const CubsVec4i* self, int64_t scalar);