#include "array.h"
#include <assert.h>
#include "../../util/global_allocator.h"
#include <string.h>
#include "../../util/panic.h"
#include <stdio.h>
#include "../primitives_context.h"

static const size_t CAPACITY_BITMASK = 0xFFFFFFFFFFFFULL;
static const size_t TAG_SHIFT = 48;
static const size_t TAG_BITMASK = 0xFFULL << 48;
static const size_t TYPE_SIZE_SHIFT = 56;
static const size_t TYPE_SIZE_BITMASK = 0xFFULL << 56;
static const size_t NON_CAPACITY_BITMASK = ~(0xFFFFFFFFFFFFULL);

static size_t growCapacity(size_t current, size_t minimum) {
    while(true) {
        current += (current / 2) + 8;
        if(current >= minimum) {
            return current;
        }
    }
}

static void ensure_total_capacity(CubsArray* self, size_t minCapacity) {
    assert(minCapacity <= 0xFFFFFFFFFFFFULL);
    const size_t sizeOfType = self->context->sizeOfType;
    if(self->buf == NULL) {
        void* mem = cubs_malloc(minCapacity * sizeOfType, _Alignof(size_t));    
        self->buf = mem;
        self->capacity = minCapacity;
    }
    else {
        const size_t currentCapacity = self->capacity;
        if(currentCapacity >= minCapacity) {
            return;
        }

        const size_t grownCapacity = growCapacity(currentCapacity, minCapacity);

        void* newBuffer = cubs_malloc(grownCapacity * sizeOfType, _Alignof(size_t));
        memcpy(newBuffer, self->buf, currentCapacity * sizeOfType);
        cubs_free(self->buf, currentCapacity * sizeOfType, _Alignof(size_t));

        self->buf = newBuffer;
        self->capacity = grownCapacity;
    }
}

CubsArray cubs_array_init_primitive(CubsValueTag tag)
{   
    const CubsStructContext* rtti = NULL;
    switch(tag) {
        case cubsValueTagBool: {
            rtti = &CUBS_BOOL_CONTEXT;
        } break;
        case cubsValueTagInt: {
            rtti = &CUBS_INT_CONTEXT;
        } break;
        case cubsValueTagFloat: {
            rtti = &CUBS_FLOAT_CONTEXT;
        } break;
        case cubsValueTagString: {
            rtti = &CUBS_STRING_CONTEXT;
        } break;
        case cubsValueTagArray: {
            rtti = &CUBS_ARRAY_CONTEXT;
        } break;
        default: {
            cubs_panic("unsupported array type");
        } break;
    }
    return cubs_array_init_user_struct(rtti);
}

CubsArray cubs_array_init_user_struct(const CubsStructContext *rtti)
{
    assert(rtti != NULL);
    const CubsArray arr = {.len = 0, .buf = NULL, .capacity = 0, .context = rtti};
    return arr;
}

void cubs_array_deinit(CubsArray *self)
{
    if(self->buf == NULL) {
        return;
    }

    const size_t sizeOfType = self->context->sizeOfType;
    if(self->context->onDeinit != NULL) {       
        char* byteStart = (char*)self->buf;
        for(size_t i = 0; i < self->len; i++) {
            const size_t actualIndex = i * sizeOfType;
            self->context->onDeinit((void*)&byteStart[actualIndex]);
        }      
    }
    
    cubs_free(self->buf, sizeOfType * self->capacity, _Alignof(size_t));
    self->buf = NULL;
    self->len = 0;
}

void cubs_array_push_unchecked(CubsArray *self, void *value)
{
    ensure_total_capacity(self, self->len + 1);
    const size_t sizeOfType = self->context->sizeOfType;
    memcpy((void*)&((char*)self->buf)[self->len * sizeOfType], value, sizeOfType);
    self->len += 1;
}

// void cubs_array_push_raw_unchecked(CubsArray *self, CubsRawValue value)
// {  
//     cubs_array_push_unchecked(self, &value);
// }

// void cubs_array_push(CubsArray *self, CubsTaggedValue value)
// {
//     assert(value.tag == cubs_array_tag(self));
//     cubs_array_push_unchecked(self, &value.value);
// }

const void* cubs_array_at_unchecked(const CubsArray *self, size_t index)
{
    assert(index < self->len);
    const size_t sizeOfType = self->context->sizeOfType;
    return (const void*)&((const char*)self->buf)[index * sizeOfType];
}

CubsArrayError cubs_array_at(const void** out, const CubsArray *self, size_t index)
{
    if(index >= self->len) {
        return cubsArrayErrorOutOfRange;
    }
    const void* temp = cubs_array_at_unchecked(self, index);
    *out = temp;
    return cubsArrayErrorNone;
}

void* cubs_array_at_mut_unchecked(CubsArray *self, size_t index)
{
    assert(index < self->len);
    const size_t sizeOfType = self->context->sizeOfType;
    return (void*)&((char*)self->buf)[index * sizeOfType];
}

CubsArrayError cubs_array_at_mut(void** out, CubsArray *self, size_t index)
{
    if(index >= self->len) {
        return cubsArrayErrorOutOfRange;
    }
    void* temp = cubs_array_at_mut_unchecked(self, index);
    *out = temp;
    return cubsArrayErrorNone;
}
