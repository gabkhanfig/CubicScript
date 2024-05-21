#include "array.h"
#include <assert.h>
#include "../util/global_allocator.h"
#include <string.h>
#include "../util/panic.h"
#include <stdio.h>

const size_t PTR_BITMASK = 0xFFFFFFFFFFFFULL;
const size_t TAG_BITMASK = ~0xFFFFFFFFFFFFULL;
const size_t TAG_SHIFT = 48;

typedef struct Inner {
    size_t len;
    size_t capacity;
} Inner;

Inner* inner_init(size_t capacity) {
    Inner* self = (Inner*)cubs_malloc(sizeof(Inner) + (sizeof(CubsRawValue) * capacity), _Alignof(size_t));
    self->len = 0;
    self->capacity = capacity;
    return self;
}

/// May return NULL
const Inner* as_inner(const CubsArray* self) {
    const size_t mask = ((size_t)(self->_inner)) & PTR_BITMASK;
    const Inner* inner = (const Inner*)(const void*)mask;
    return inner;
}

/// May return NULL
Inner* as_inner_mut(CubsArray* self) {
    size_t mask = ((size_t)(self->_inner)) & PTR_BITMASK;
    Inner* inner = (Inner*)(void*)mask;
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
    
    cubs_free((void*)inner, sizeof(Inner) + (sizeof(CubsRawValue) * inner->capacity), _Alignof(size_t));
    self->_inner = NULL;
}

CubsValueTag cubs_array_tag(const CubsArray *self)
{
    const size_t mask = ((size_t)(self->_inner)) & TAG_BITMASK;
    return mask >> TAG_SHIFT;
}

size_t cubs_array_len(const CubsArray *self)
{
    const Inner* inner = as_inner(self);
    if(inner == NULL) {
        return 0;
    }
    return inner->len;
}

static size_t growCapacity(size_t current, size_t minimum) {
    while(true) {
        current += (current / 2) + 8;
        if(current >= minimum) {
            return current;
        }
    }
}

static void ensure_total_capacity(CubsArray* self, size_t minCapacity) {
    Inner* inner = as_inner_mut(self);
    if(inner == NULL) {
        Inner* newInner = inner_init(minCapacity);
        // If inner is null, only the tag is present.
        const size_t selfMask = (size_t)(self->_inner);
        assert((selfMask & PTR_BITMASK) == 0);
        self->_inner = (void*)(selfMask | (size_t)newInner);
        return;
    }

    if(inner->capacity >= minCapacity) {
        return;
    }

    const size_t grownCapacity = growCapacity(inner->capacity, minCapacity);
    
    Inner* newInner = inner_init(grownCapacity);
    newInner->len = inner->len;

    CubsRawValue* newBuffer = buf_start_mut(newInner);
    const CubsRawValue* oldBuffer = buf_start_mut(inner);

    memcpy((void*)newBuffer, (const void*)oldBuffer, inner->len * sizeof(CubsRawValue));

    cubs_free((void*)inner, sizeof(Inner) + (sizeof(CubsRawValue) * inner->capacity), _Alignof(size_t));

    const size_t selfTagMask = ((size_t)(self->_inner)) & TAG_BITMASK;
    self->_inner = (void*)(selfTagMask | (size_t)newInner);
}

void cubs_array_push_unchecked(CubsArray* self, CubsRawValue value)
{
    const size_t currentLen = cubs_array_len(self);
    
    ensure_total_capacity(self, currentLen + 1);
    Inner* inner = as_inner_mut(self); // must be after the capcity change
    
    CubsRawValue* buf = buf_start_mut(inner);

    inner->len = currentLen + 1;
    buf[currentLen] = value;
}

void cubs_array_push(CubsArray *self, CubsTaggedValue value)
{
    assert(value.tag == cubs_array_tag(self));
    cubs_array_push_unchecked(self, value.value);
}

const CubsRawValue *cubs_array_at_unchecked(const CubsArray *self, size_t index)
{
    const Inner* inner = as_inner(self);
    #if _DEBUG
    if(inner == NULL) {
        char buf[256] = {0};
        (void)sprintf_s(buf, 256, "CubicScript Array index out of range! Tried to access index %ld from array of length 0", index);
        cubs_panic(buf);
    } else if(index >= inner->len) {
        char buf[256] = {0};
        (void)sprintf_s(buf, 256, "CubicScript Array index out of range! Tried to access index %ld from array of length %ld", index, inner->len);
        cubs_panic(buf);
    }
    #endif
    return &buf_start(inner)[index];

    
}

CubsArrayError cubs_array_at(const CubsRawValue** out, const CubsArray *self, size_t index)
{
    const Inner* inner = as_inner(self);
    if(inner == NULL) {
        return cubsArrayErrorOutOfRange;
    }
    else if(index >= inner->len)  {
        return cubsArrayErrorOutOfRange;
    }
    else {
        *out = &buf_start(inner)[index];
        return cubsArrayErrorNone;
    }
}
