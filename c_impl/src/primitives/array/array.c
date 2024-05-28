#include "array.h"
#include <assert.h>
#include "../../util/global_allocator.h"
#include <string.h>
#include "../../util/panic.h"
#include <stdio.h>

static const size_t CAPACITY_BITMASK = 0xFFFFFFFFFFFFULL;
static const size_t TAG_SHIFT = 48;
static const size_t TAG_BITMASK = 0xFFULL << 48;
static const size_t TYPE_SIZE_SHIFT = 56;
static const size_t TYPE_SIZE_BITMASK = 0xFFULL << 56;
static const size_t NON_CAPACITY_BITMASK = ~(0xFFFFFFFFFFFFULL);

static size_t array_capacity(const CubsArray* self) {
    return self->_metadata & CAPACITY_BITMASK;
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
    assert(minCapacity <= 0xFFFFFFFFFFFFULL);
    const size_t sizeOfType = cubs_array_size_of_type(self);
    if(self->_buf == NULL) {
        void* mem = cubs_malloc(minCapacity * sizeOfType, _Alignof(size_t));    
        self->_buf = mem;
        self->_metadata = (self->_metadata & NON_CAPACITY_BITMASK) | minCapacity;
    }
    else {
        const size_t currentCapacity = array_capacity(self);
        if(currentCapacity >= minCapacity) {
            return;
        }

        const size_t grownCapacity = growCapacity(currentCapacity, minCapacity);

        void* newBuffer = cubs_malloc(grownCapacity * sizeOfType, _Alignof(size_t));
        memcpy(newBuffer, self->_buf, currentCapacity * sizeOfType);
        cubs_free(self->_buf, currentCapacity * sizeOfType, _Alignof(size_t));

        self->_buf = newBuffer;
        self->_metadata = (self->_metadata & NON_CAPACITY_BITMASK) | grownCapacity;
    }
}

CubsArray cubs_array_init(CubsValueTag tag)
{   
    const size_t tagAsSizeT = (size_t)tag;
    const size_t dataSize = cubs_size_of_tagged_type(tag);
    assert(dataSize <= 0xFF);
    const CubsArray arr = {.len = 0, ._buf = NULL, ._metadata = (tagAsSizeT << TAG_SHIFT) | (dataSize << TYPE_SIZE_SHIFT)};
    return arr;
}

void cubs_array_deinit(CubsArray *self)
{
    if(self->_buf == NULL) {
        return;
    }

    const CubsValueTag tag = cubs_array_tag(self);
    const size_t sizeOfType = cubs_array_size_of_type(self);
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
            for(size_t i = 0; i < self->len; i++) {
                const size_t actualIndex = i * sizeOfType;
                char* byteStart = (char*)self->_buf;
                cubs_void_value_deinit((void*)&byteStart[actualIndex], tag);
            }
        } break;
    }
    
    cubs_free(self->_buf, sizeOfType * array_capacity(self), _Alignof(size_t));
    self->_buf = NULL;
    self->len = 0;
}

CubsValueTag cubs_array_tag(const CubsArray *self)
{
    return (self->_metadata & TAG_BITMASK) >> TAG_SHIFT;
}

size_t cubs_array_size_of_type(const CubsArray *self)
{
    return (self->_metadata & TYPE_SIZE_BITMASK) >> TYPE_SIZE_SHIFT;
}

void cubs_array_push_unchecked(CubsArray *self, const void *value)
{
    ensure_total_capacity(self, self->len + 1);
    const size_t sizeOfType = cubs_array_size_of_type(self);
    memcpy((void*)&((char*)self->_buf)[self->len * sizeOfType], value, sizeOfType);
    self->len += 1;
}

void cubs_array_push_raw_unchecked(CubsArray *self, CubsRawValue value)
{  
    cubs_array_push_unchecked(self, (const void*)&value);
}

void cubs_array_push(CubsArray *self, CubsTaggedValue value)
{
    // if(value.tag != cubs_array_tag(self)) {
    //   fprintf(stderr, "tag is %d, value is %x", value.tag, value.value.intNum);
    // }
    assert(value.tag == cubs_array_tag(self));
    cubs_array_push_unchecked(self, &value.value);
}

const void* cubs_array_at_unchecked(const CubsArray *self, size_t index)
{
    assert(index < self->len);
    const size_t sizeOfType = cubs_array_size_of_type(self);
    return (const void*)&((const char*)self->_buf)[index * sizeOfType];
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
    const size_t sizeOfType = cubs_array_size_of_type(self);
    return (void*)&((char*)self->_buf)[index * sizeOfType];
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
