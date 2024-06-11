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

CubsVec2f cubs_vec2f_add(const CubsVec2f *self, const CubsVec2f *vec)
{
    const CubsVec2f out = {.x = self->x + vec->x, .y = self->y + vec->y};
    return out;
}

CubsVec2f cubs_vec2f_add_scalar(const CubsVec2f *self, double scalar)
{
    const CubsVec2f out = {.x = self->x + scalar, .y = self->y + scalar};
    return out;
}

CubsVec2f cubs_vec2f_sub(const CubsVec2f *self, const CubsVec2f *vec)
{
    const CubsVec2f out = {.x = self->x - vec->x, .y = self->y - vec->y};
    return out;
}

CubsVec2f cubs_vec2f_sub_scalar(const CubsVec2f *self, double scalar)
{
    const CubsVec2f out = {.x = self->x - scalar, .y = self->y - scalar};
    return out;
}

CubsVec2f cubs_vec2f_mul(const CubsVec2f *self, const CubsVec2f *vec)
{
    const CubsVec2f out = {.x = self->x * vec->x, .y = self->y * vec->y};
    return out;
}

CubsVec2f cubs_vec2f_mul_scalar(const CubsVec2f *self, double scalar)
{
    const CubsVec2f out = {.x = self->x * scalar, .y = self->y * scalar};
    return out;
}

CubsVec2f cubs_vec2f_div(const CubsVec2f *self, const CubsVec2f *vec)
{
    const CubsVec2f out = {.x = self->x / vec->x, .y = self->y / vec->y};
    return out;
}

CubsVec2f cubs_vec2f_div_scalar(const CubsVec2f *self, double scalar)
{
    const CubsVec2f out = {.x = self->x / scalar, .y = self->y / scalar};
    return out;
}

double cubs_vec2f_dot(const CubsVec2f *self, const CubsVec2f *vec)
{
    double result = 0.0;
    result += self->x * vec->x;
    result += self->y * vec->y;
    return result;
}

CubsVec3f cubs_vec3f_add(const CubsVec3f *self, const CubsVec3f *vec)
{
    const CubsVec3f out = {.x = self->x + vec->x, .y = self->y + vec->y, .z = self->z + vec->z};
    return out;
}

CubsVec3f cubs_vec3f_add_scalar(const CubsVec3f *self, double scalar)
{
    const CubsVec3f out = {.x = self->x + scalar, .y = self->y + scalar, .z = self->z + scalar};
    return out;
}

CubsVec3f cubs_vec3f_sub(const CubsVec3f *self, const CubsVec3f *vec)
{
    const CubsVec3f out = {.x = self->x - vec->x, .y = self->y - vec->y, .z = self->z - vec->z};
    return out;
}

CubsVec3f cubs_vec3f_sub_scalar(const CubsVec3f *self, double scalar)
{
    const CubsVec3f out = {.x = self->x - scalar, .y = self->y - scalar, .z = self->z - scalar};
    return out;
}

CubsVec3f cubs_vec3f_mul(const CubsVec3f *self, const CubsVec3f *vec)
{
    const CubsVec3f out = {.x = self->x * vec->x, .y = self->y * vec->y, .z = self->z * vec->z};
    return out;
}

CubsVec3f cubs_vec3f_mul_scalar(const CubsVec3f *self, double scalar)
{
    const CubsVec3f out = {.x = self->x * scalar, .y = self->y * scalar, .z = self->z * scalar};
    return out;
}

CubsVec3f cubs_vec3f_div(const CubsVec3f *self, const CubsVec3f *vec)
{
    const CubsVec3f out = {.x = self->x / vec->x, .y = self->y / vec->y, .z = self->z / vec->z};
    return out;
}

CubsVec3f cubs_vec3f_div_scalar(const CubsVec3f *self, double scalar)
{
    const CubsVec3f out = {.x = self->x / scalar, .y = self->y / scalar, .z = self->z / scalar};
    return out;
}

double cubs_vec3f_dot(const CubsVec3f *self, const CubsVec3f *vec)
{
    double result = 0.0;
    result += self->x * vec->x;
    result += self->y * vec->y;
    result += self->z * vec->z;
    return result;
}

CubsVec3f cubs_vec3f_cross(const CubsVec3f *self, const CubsVec3f *vec)
{
    const CubsVec3f out = {
        .x = (self->y * vec->z) - (self->z * vec->y),
        .y = (self->z * vec->x) - (self->x * vec->z),
        .z = (self->x * vec->y) - (self->y * vec->x)
    };   
    return out;
}

CubsVec4f cubs_vec4f_add(const CubsVec4f *self, const CubsVec4f *vec)
{
    const CubsVec4f out = {.x = self->x + vec->x, .y = self->y + vec->y, .z = self->z + vec->z, .w = self->w + vec->w};
    return out;
}

CubsVec4f cubs_vec4f_add_scalar(const CubsVec4f *self, double scalar)
{
    const CubsVec4f out = {.x = self->x + scalar, .y = self->y + scalar, .z = self->z + scalar, .w = self->w + scalar};
    return out;
}

CubsVec4f cubs_vec4f_sub(const CubsVec4f *self, const CubsVec4f *vec)
{
    const CubsVec4f out = {.x = self->x - vec->x, .y = self->y - vec->y, .z = self->z - vec->z, .w = self->w - vec->w};
    return out;
}

CubsVec4f cubs_vec4f_sub_scalar(const CubsVec4f *self, double scalar)
{
    const CubsVec4f out = {.x = self->x - scalar, .y = self->y - scalar, .z = self->z - scalar, .w = self->w - scalar};
    return out;
}

CubsVec4f cubs_vec4f_mul(const CubsVec4f *self, const CubsVec4f *vec)
{
    const CubsVec4f out = {.x = self->x * vec->x, .y = self->y * vec->y, .z = self->z * vec->z, .w = self->w * vec->w};
    return out;
}

CubsVec4f cubs_vec4f_mul_scalar(const CubsVec4f *self, double scalar)
{
    const CubsVec4f out = {.x = self->x * scalar, .y = self->y * scalar, .z = self->z * scalar, .w = self->w * scalar};
    return out;
}

CubsVec4f cubs_vec4f_div(const CubsVec4f *self, const CubsVec4f *vec)
{
    const CubsVec4f out = {.x = self->x / vec->x, .y = self->y / vec->y, .z = self->z / vec->z, .w = self->w / vec->w};
    return out;
}

CubsVec4f cubs_vec4f_div_scalar(const CubsVec4f *self, double scalar)
{
    const CubsVec4f out = {.x = self->x / scalar, .y = self->y / scalar, .z = self->z / scalar, .w = self->w / scalar};
    return out;
}

double cubs_vec4f_dot(const CubsVec4f *self, const CubsVec4f *vec)
{
    double result = 0.0;
    result += self->x * vec->x;
    result += self->y * vec->y;
    result += self->z * vec->z;
    result += self->w * vec->w;
    return result;
}
