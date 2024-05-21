#include "array.h"
#include <assert.h>
#include "../util/global_allocator.h"

const size_t PTR_BITMASK = 0xFFFFFFFFFFFFULL;
const size_t TAG_BITMASK = ~0xFFFFFFFFFFFFULL;
const size_t TAG_SHIFT = 48;

typedef struct Inner {
    size_t len;
    size_t capacity;
} Inner;

/// May return NULL
const Inner* as_inner(const CubsArray* self) {
    const Inner* inner = (const Inner*)(const void*)(((size_t)self->_inner) & PTR_BITMASK);
    return inner;
}

/// May return NULL
Inner* as_inner_mut(CubsArray* self) {
    Inner* inner = (Inner*)(void*)(((size_t)self->_inner) & PTR_BITMASK);
    return inner;
}

const CubsRawValue* buf_start(const Inner* inner) {
    return (const CubsRawValue*)&inner[1];
}

CubsRawValue* buf_start_mut(Inner* inner) {
    return (CubsRawValue*)&inner[1];
}

CubsArray cubs_array_init(CubsValueTag tag)
{   
    const size_t tagAsSizeT = (size_t)tag;
    const CubsArray arr = {._inner = (void*)(tagAsSizeT << TAG_SHIFT)};
    return arr;
}

void cubs_array_deinit(CubsArray *self)
{
    Inner* inner = as_inner_mut(self);
    if(inner == NULL) {
        return;
    }

    const CubsValueTag tag = cubs_array_tag(self);
    CubsRawValue* buf = buf_start_mut(inner);
    switch(tag) {
        case cubsValueTagNone: break;
        case cubsValueTagBool: break;
        case cubsValueTagInt: break;
        case cubsValueTagFloat: break;
        case cubsValueTagConstRef: break;
        case cubsValueTagMutRef: break;
        case cubsValueTagInterfaceRef: break;
        case cubsValueTagFunctionPtr: break;
        default: {
            for(size_t i = 0; i < inner->len; i++) {
                cubs_raw_value_deinit(&buf[i], tag);
            }
        } break;
    }
    
    cubs_free((void*)inner, sizeof(Inner) + (sizeof(CubsRawValue) * inner->len), _Alignof(size_t));
    self->_inner = NULL;
}

CubsValueTag cubs_array_tag(const CubsArray *self)
{
    const size_t mask = ((size_t)(self->_inner)) & TAG_BITMASK;
    return mask >> TAG_SHIFT;
}
