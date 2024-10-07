#pragma once

#include "../../c_basic_types.h"

struct CubsTypeContext;

/// 0 / null intialization makes it a none option.
typedef struct CubsOption {
    bool isSome;
    void* _metadata[4];
    const struct CubsTypeContext* context;
} CubsOption;

#ifdef __cplusplus
extern "C" {
#endif

/// If `optionalValue != NULL`, takes ownership. Otherwise, this is a none option.
//CubsOption cubs_option_init_primitive(CubsValueTag tag, void* optionalValue);

/// If `optionalValue != NULL`, takes ownership. Otherwise, this is a none option.
CubsOption cubs_option_init(const struct CubsTypeContext* context, void* optionalValue);

void cubs_option_deinit(CubsOption* self);

CubsOption cubs_option_clone(const CubsOption* self);

/// Always returns a valid pointer.
/// # Debug Asserts
/// `self->isSome`
const void* cubs_option_get(const CubsOption* self);

/// Always returns a valid pointer.
/// # Debug Asserts
/// `self->isSome`
void* cubs_option_get_mut(CubsOption* self);

/// memcpy's the owned some value into `out`, relinquishing ownership.
/// # Debug Asserts
/// `self->isSome`
void cubs_option_take(void* out, CubsOption* self);

bool cubs_option_eql(const CubsOption* self, const CubsOption* other);

size_t cubs_option_hash(const CubsOption* self);

#ifdef __cplusplus
} // extern "C"
#endif
