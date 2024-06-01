#include "option.h"
#include <assert.h>
#include "../../util/global_allocator.h"
#include <string.h>

const size_t MAX_INLINE_STORAGE = sizeof(void*[4]);

CubsOption cubs_option_init_unchecked(CubsValueTag tag, void *value)
{
    const size_t sizeOfValue = cubs_size_of_tagged_type(tag);
    if(sizeOfValue > MAX_INLINE_STORAGE) { // Would mean type cannot fit within the buffer
        void* valueStorage = cubs_malloc(sizeOfValue, _Alignof(size_t));
        memcpy(valueStorage, value, sizeOfValue);
        const CubsOption option = {.tag = tag, .sizeOfType = sizeOfValue, .isSome = true, .metadata = {valueStorage, NULL, NULL, NULL}};
        return option;
    }
    else {
        CubsOption option = {.tag = tag, .sizeOfType = sizeOfValue, .isSome = true};
        memcpy(option.metadata, value, sizeOfValue);
        return option;
    }
}

CubsOption cubs_option_init_raw_unchecked(CubsValueTag tag, CubsRawValue value)
{
    return cubs_option_init_unchecked(tag, (void*)&value);
}

CubsOption cubs_option_init(CubsTaggedValue value)
{
    return cubs_option_init_unchecked(value.tag, (void*)&value.value);
}

void cubs_option_deinit(CubsOption *self)
{
    if(!self->isSome) {
        return;
    }

    cubs_void_value_deinit(cubs_option_get_mut_unchecked(self), self->tag);
    memset((void*)self, 0, sizeof(CubsOption));
}

const void *cubs_option_get_unchecked(const CubsOption *self)
{
    assert(self->isSome);
    if(self->sizeOfType > MAX_INLINE_STORAGE) {
        return self->metadata[0];
    }
    else {
        return self->metadata;
    }
}

void *cubs_option_get_mut_unchecked(CubsOption *self)
{
    assert(self->isSome);
    if(self->sizeOfType > MAX_INLINE_STORAGE) {
        return self->metadata[0];
    }
    else {
        return self->metadata;
    }
}

CubsOptionError cubs_option_get(const void **out, const CubsOption *self)
{
    if(!self->isSome) {
        return cubsOptionErrorIsNone;
    }
    *out = cubs_option_get_unchecked(self);
    return cubsOptionErrorNone;
}

CubsOptionError cubs_option_get_mut(void **out, CubsOption *self)
{
    if(!self->isSome) {
        return cubsOptionErrorIsNone;
    }
    *out = cubs_option_get_mut_unchecked(self);
    return cubsOptionErrorNone;
}

CubsOptionError cubs_option_take(void* out, CubsOption* self)
{
    if(!self->isSome) {
        return cubsOptionErrorIsNone;
    }
    memcpy(out, cubs_option_get_unchecked(self), self->sizeOfType);
    memset((void*)self, 0, sizeof(CubsOption));
    return cubsOptionErrorNone;
}
