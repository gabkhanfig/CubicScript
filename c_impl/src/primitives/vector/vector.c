#include "vector.h"

// TODO maybe simd?

CubsVec2i cubs_vec2i_add(const CubsVec2i *self, const CubsVec2i *vec)
{
    const CubsVec2i out = {.x = self->x + vec->x, .y = self->y + vec->y};
    return out;
}

CubsVec2i cubs_vec2i_add_scalar(const CubsVec2i *self, int64_t scalar)
{
    const CubsVec2i out = {.x = self->x + scalar, .y = self->y + scalar};
    return out;
}

CubsVec2i cubs_vec2i_sub(const CubsVec2i *self, const CubsVec2i *vec)
{
    const CubsVec2i out = {.x = self->x - vec->x, .y = self->y - vec->y};
    return out;
}

CubsVec2i cubs_vec2i_sub_scalar(const CubsVec2i *self, int64_t scalar)
{
    const CubsVec2i out = {.x = self->x - scalar, .y = self->y - scalar};
    return out;
}

CubsVec2i cubs_vec2i_mul(const CubsVec2i *self, const CubsVec2i *vec)
{
    const CubsVec2i out = {.x = self->x * vec->x, .y = self->y * vec->y};
    return out;
}

CubsVec2i cubs_vec2i_mul_scalar(const CubsVec2i *self, int64_t scalar)
{
    const CubsVec2i out = {.x = self->x * scalar, .y = self->y * scalar};
    return out;
}

CubsVec2i cubs_vec2i_div(const CubsVec2i *self, const CubsVec2i *vec)
{
    const CubsVec2i out = {.x = self->x / vec->x, .y = self->y / vec->y};
    return out;
}

CubsVec2i cubs_vec2i_div_scalar(const CubsVec2i *self, int64_t scalar)
{
    const CubsVec2i out = {.x = self->x / scalar, .y = self->y / scalar};
    return out;
}

CubsVec3i cubs_vec3i_add(const CubsVec3i *self, const CubsVec3i *vec)
{
    const CubsVec3i out = {.x = self->x + vec->x, .y = self->y + vec->y, .z = self->z + vec->z};
    return out;
}

CubsVec3i cubs_vec3i_add_scalar(const CubsVec3i *self, int64_t scalar)
{
    const CubsVec3i out = {.x = self->x + scalar, .y = self->y + scalar, .z = self->z + scalar};
    return out;
}

CubsVec3i cubs_vec3i_sub(const CubsVec3i *self, const CubsVec3i *vec)
{
    const CubsVec3i out = {.x = self->x - vec->x, .y = self->y - vec->y, .z = self->z - vec->z};
    return out;
}

CubsVec3i cubs_vec3i_sub_scalar(const CubsVec3i *self, int64_t scalar)
{
    const CubsVec3i out = {.x = self->x - scalar, .y = self->y - scalar, .z = self->z - scalar};
    return out;
}

CubsVec3i cubs_vec3i_mul(const CubsVec3i *self, const CubsVec3i *vec)
{
    const CubsVec3i out = {.x = self->x * vec->x, .y = self->y * vec->y, .z = self->z * vec->z};
    return out;
}

CubsVec3i cubs_vec3i_mul_scalar(const CubsVec3i *self, int64_t scalar)
{
    const CubsVec3i out = {.x = self->x * scalar, .y = self->y * scalar, .z = self->z * scalar};
    return out;
}

CubsVec3i cubs_vec3i_div(const CubsVec3i *self, const CubsVec3i *vec)
{
    const CubsVec3i out = {.x = self->x / vec->x, .y = self->y / vec->y, .z = self->z / vec->z};
    return out;
}

CubsVec3i cubs_vec3i_div_scalar(const CubsVec3i *self, int64_t scalar)
{
    const CubsVec3i out = {.x = self->x / scalar, .y = self->y / scalar, .z = self->z / scalar};
    return out;
}

CubsVec4i cubs_vec4i_add(const CubsVec4i *self, const CubsVec4i *vec)
{
    const CubsVec4i out = {.x = self->x + vec->x, .y = self->y + vec->y, .z = self->z + vec->z, .w = self->w + vec->w};
    return out;
}

CubsVec4i cubs_vec4i_add_scalar(const CubsVec4i *self, int64_t scalar)
{
    const CubsVec4i out = {.x = self->x + scalar, .y = self->y + scalar, .z = self->z + scalar, .w = self->w + scalar};
    return out;
}

CubsVec4i cubs_vec4i_sub(const CubsVec4i *self, const CubsVec4i *vec)
{
    const CubsVec4i out = {.x = self->x - vec->x, .y = self->y - vec->y, .z = self->z - vec->z, .w = self->w - vec->w};
    return out;
}

CubsVec4i cubs_vec4i_sub_scalar(const CubsVec4i *self, int64_t scalar)
{
    const CubsVec4i out = {.x = self->x - scalar, .y = self->y - scalar, .z = self->z - scalar, .w = self->w - scalar};
    return out;
}

CubsVec4i cubs_vec4i_mul(const CubsVec4i *self, const CubsVec4i *vec)
{
    const CubsVec4i out = {.x = self->x * vec->x, .y = self->y * vec->y, .z = self->z * vec->z, .w = self->w * vec->w};
    return out;
}

CubsVec4i cubs_vec4i_mul_scalar(const CubsVec4i *self, int64_t scalar)
{
    const CubsVec4i out = {.x = self->x * scalar, .y = self->y * scalar, .z = self->z * scalar, .w = self->w * scalar};
    return out;
}

CubsVec4i cubs_vec4i_div(const CubsVec4i *self, const CubsVec4i *vec)
{
    const CubsVec4i out = {.x = self->x / vec->x, .y = self->y / vec->y, .z = self->z / vec->z, .w = self->w / vec->w};
    return out;
}

CubsVec4i cubs_vec4i_div_scalar(const CubsVec4i *self, int64_t scalar)
{
    const CubsVec4i out = {.x = self->x / scalar, .y = self->y / scalar, .z = self->z / scalar, .w = self->w / scalar};
    return out;
}
