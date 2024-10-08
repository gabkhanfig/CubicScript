#include "array.h"
#include <assert.h>
#include "../../platform/mem.h"
#include <string.h>
#include "../../util/panic.h"
#include <stdio.h>
#include "../context.h"
#include "../../util/hash.h"

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

// CubsArray cubs_array_init_primitive(CubsValueTag tag)
// {   
//     assert(tag != cubsValueTagUserClass && "Use cubs_array_init_user_struct for user defined structs");
//     return cubs_array_init_user_struct(cubs_primitive_context_for_tag(tag));
// }

CubsArray cubs_array_init(const CubsTypeContext *context)
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
    if(self->context->destructor.func.externC != NULL) {       
        char* byteStart = (char*)self->buf;
        for(size_t i = 0; i < self->len; i++) {
            const size_t actualIndex = i * sizeOfType;
            cubs_context_fast_deinit((void*)&byteStart[actualIndex], self->context);
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
   
        cubs_context_fast_clone(valueTempStorage, selfValue, self->context);

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
    assert(self->context->eql.func.externC != NULL);
    assert(other->context->eql.func.externC != NULL);
    assert(self->context->eql.func.externC == other->context->eql.func.externC);
    assert(self->context->sizeOfType == other->context->sizeOfType);

    if(self->len != other->len) {
        return false;
    }

    const size_t sizeOfType = self->context->sizeOfType;
    for(size_t i = 0; i < self->len; i++) {
        const void* selfValue = (const void*)&((const char*)self->buf)[i * sizeOfType];
        const void* otherValue = (const void*)&((const char*)other->buf)[i * sizeOfType];


        if(cubs_context_fast_eql(selfValue, otherValue, self->context) == false) {
            return false;
        }
    }
    return true;
}

size_t cubs_array_hash(const CubsArray *self)
{
    assert(self->context->hash.func.externC != NULL);

    const size_t globalHashSeed = cubs_hash_seed();
    size_t h = globalHashSeed;

    for(size_t i = 0; i < self->len; i++) {
        const size_t hashedValue = cubs_context_fast_hash(cubs_array_at_unchecked(self, i), self->context);
        h = cubs_combine_hash(hashedValue, h);
    }

    return h;
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

CubsArrayMutIter cubs_array_mut_iter_begin(CubsArray* self) {
    const CubsArrayMutIter iter = {._arr = self, ._nextIndex = 0, .value = NULL};
    return iter;
}

/// For C++ interop
CubsArrayMutIter cubs_array_mut_iter_end(CubsArray* self) {
    const CubsArrayMutIter iter = {._arr = self, ._nextIndex = self->len, .value = NULL};
    return iter;
}

bool cubs_array_mut_iter_next(CubsArrayMutIter* iter) {
    if(iter->_nextIndex == iter->_arr->len) {
        return false;
    }
  
    const size_t sizeOfType = iter->_arr->context->sizeOfType;
    iter->value = (void*)&((char*)iter->_arr->buf)[iter->_nextIndex * sizeOfType];
    iter->_nextIndex += 1;
    return true;
}

CubsArrayReverseConstIter cubs_array_reverse_const_iter_begin(const CubsArray* self) {
    const CubsArrayReverseConstIter iter = {._arr = self, ._priorIndex = self->len, .value = NULL};
    return iter;
}

/// For C++ interop
CubsArrayReverseConstIter cubs_array_reverse_const_iter_end(const CubsArray* self) {
    const CubsArrayReverseConstIter iter = {._arr = self, ._priorIndex = 0, .value = NULL};
    return iter;
}

bool cubs_array_reverse_const_iter_next(CubsArrayReverseConstIter* iter) {
    if(iter->_priorIndex == 0) {
        return false;
    }

    const size_t sizeOfType = iter->_arr->context->sizeOfType;
    iter->_priorIndex -= 1; // decrement BEFORE access
    iter->value = (const void*)&((const char*)iter->_arr->buf)[iter->_priorIndex * sizeOfType];
    return true;
}

CubsArrayReverseMutIter cubs_array_reverse_mut_iter_begin(CubsArray* self) {    
    const CubsArrayReverseMutIter iter = {._arr = self, ._priorIndex = self->len, .value = NULL};
    return iter;
}

/// For C++ interop
CubsArrayReverseMutIter cubs_array_reverse_mut_iter_end(CubsArray* self) {
    const CubsArrayReverseMutIter iter = {._arr = self, ._priorIndex = 0, .value = NULL};
    return iter;
}

bool cubs_array_reverse_mut_iter_next(CubsArrayReverseMutIter* iter) {
    if(iter->_priorIndex == 0) {
        return false;
    }

    const size_t sizeOfType = iter->_arr->context->sizeOfType;
    iter->_priorIndex -= 1; // decrement BEFORE access
    iter->value = (void*)&((char*)iter->_arr->buf)[iter->_priorIndex * sizeOfType];
    return true;
}