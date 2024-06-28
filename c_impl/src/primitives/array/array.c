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
    assert(tag != cubsValueTagUserStruct && "Use cubs_array_init_user_struct for user defined structs");
    return cubs_array_init_user_struct(cubs_primitive_context_for_tag(tag));
}

CubsArray cubs_array_init_user_struct(const CubsStructContext *context)
{
    assert(context != NULL);
    const CubsArray arr = {.len = 0, .buf = NULL, .capacity = 0, .context = context};
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

CubsArray cubs_array_clone(const CubsArray *self)
{
    CubsArray newSelf = {.len = self->len, .context = self->context, .buf = NULL, .capacity = 0};

    if(self->len == 0) {
        return newSelf;
    }

    ensure_total_capacity(&newSelf, self->len);
  
    const size_t sizeOfType = self->context->sizeOfType;
    void* valueTempStorage = cubs_malloc(sizeOfType, _Alignof(size_t));

    for(size_t i = 0; i < self->len; i++) {

        void* selfValue = (void*)&((char*)self->buf)[i * sizeOfType];
        void* newValue = (void*)&((char*)newSelf.buf)[i * sizeOfType];
   
        self->context->clone(valueTempStorage, selfValue);

        memcpy(newValue, valueTempStorage, sizeOfType);
    }

    cubs_free(valueTempStorage, sizeOfType, _Alignof(size_t));
    return newSelf;
}

void cubs_array_push_unchecked(CubsArray *self, void *value)
{
    ensure_total_capacity(self, self->len + 1);
    const size_t sizeOfType = self->context->sizeOfType;
    memcpy((void*)&((char*)self->buf)[self->len * sizeOfType], value, sizeOfType);
    self->len += 1;
}

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

bool cubs_array_eql(const CubsArray *self, const CubsArray *other)
{
    assert(self->context->eql != NULL);
    assert(other->context->eql != NULL);
    assert(self->context->eql == other->context->eql);
    assert(self->context->sizeOfType == other->context->sizeOfType);
    assert(self->context->tag == other->context->tag);

    if(self->len != other->len) {
        return false;
    }

    const size_t sizeOfType = self->context->sizeOfType;
    for(size_t i = 0; i < self->len; i++) {
        const void* selfValue = (const void*)&((const char*)self->buf)[i * sizeOfType];
        const void* otherValue = (const void*)&((const char*)other->buf)[i * sizeOfType];

        if(self->context->eql(selfValue, otherValue) == false) {
            return false;
        }
    }
    return true;
}


CubsArrayConstIter cubs_array_const_iter_begin(const CubsArray* self) {
    const CubsArrayConstIter iter = {._arr = self, ._nextIndex = 0, .value = NULL};
    return iter;
}

CubsArrayConstIter cubs_array_const_iter_end(const CubsArray* self) {
    const CubsArrayConstIter iter = {._arr = self, ._nextIndex = self->len, .value = NULL};
    return iter;
}

bool cubs_array_const_iter_next(CubsArrayConstIter* iter) {
    if(iter->_nextIndex == iter->_arr->len) {
        return false;
    }
  
    const size_t sizeOfType = iter->_arr->context->sizeOfType;
    iter->value = (const void*)&((const char*)iter->_arr->buf)[iter->_nextIndex * sizeOfType];
    iter->_nextIndex += 1;
    return true;
}