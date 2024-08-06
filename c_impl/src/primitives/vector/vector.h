#pragma once

#include "../../c_basic_types.h"
#include "../script_value.h"

#ifdef __cplusplus
extern "C" {
#endif

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


CubsVec2f cubs_vec2f_add(const CubsVec2f* self, const CubsVec2f* vec);

CubsVec2f cubs_vec2f_add_scalar(const CubsVec2f* self, double scalar);

CubsVec2f cubs_vec2f_sub(const CubsVec2f* self, const CubsVec2f* vec);

CubsVec2f cubs_vec2f_sub_scalar(const CubsVec2f* self, double scalar);

CubsVec2f cubs_vec2f_mul(const CubsVec2f* self, const CubsVec2f* vec);

CubsVec2f cubs_vec2f_mul_scalar(const CubsVec2f* self, double scalar);

CubsVec2f cubs_vec2f_div(const CubsVec2f* self, const CubsVec2f* vec);

CubsVec2f cubs_vec2f_div_scalar(const CubsVec2f* self, double scalar);

double cubs_vec2f_dot(const CubsVec2f* self, const CubsVec2f* vec);


CubsVec3f cubs_vec3f_add(const CubsVec3f* self, const CubsVec3f* vec);

CubsVec3f cubs_vec3f_add_scalar(const CubsVec3f* self, double scalar);

CubsVec3f cubs_vec3f_sub(const CubsVec3f* self, const CubsVec3f* vec);

CubsVec3f cubs_vec3f_sub_scalar(const CubsVec3f* self, double scalar);

CubsVec3f cubs_vec3f_mul(const CubsVec3f* self, const CubsVec3f* vec);

CubsVec3f cubs_vec3f_mul_scalar(const CubsVec3f* self, double scalar);

CubsVec3f cubs_vec3f_div(const CubsVec3f* self, const CubsVec3f* vec);

CubsVec3f cubs_vec3f_div_scalar(const CubsVec3f* self, double scalar);

double cubs_vec3f_dot(const CubsVec3f* self, const CubsVec3f* vec);

CubsVec3f cubs_vec3f_cross(const CubsVec3f* self, const CubsVec3f* vec);


CubsVec4f cubs_vec4f_add(const CubsVec4f* self, const CubsVec4f* vec);

CubsVec4f cubs_vec4f_add_scalar(const CubsVec4f* self, double scalar);

CubsVec4f cubs_vec4f_sub(const CubsVec4f* self, const CubsVec4f* vec);

CubsVec4f cubs_vec4f_sub_scalar(const CubsVec4f* self, double scalar);

CubsVec4f cubs_vec4f_mul(const CubsVec4f* self, const CubsVec4f* vec);

CubsVec4f cubs_vec4f_mul_scalar(const CubsVec4f* self, double scalar);

CubsVec4f cubs_vec4f_div(const CubsVec4f* self, const CubsVec4f* vec);

CubsVec4f cubs_vec4f_div_scalar(const CubsVec4f* self, double scalar);

double cubs_vec4f_dot(const CubsVec4f* self, const CubsVec4f* vec);

#ifdef __cplusplus
} // extern "C"
#endif
