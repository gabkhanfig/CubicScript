#include "result.h"
#include <assert.h>
#include "../../util/global_allocator.h"
#include <string.h>
#include "../string/string.h"

CubsError cubs_error_init_unchecked(CubsString errorName, void *optionalErrorMetadata, CubsValueTag optionalErrorTag)
{
    CubsError err = {.name = errorName, .metadata = NULL};
    if(optionalErrorMetadata == NULL) {
        return err;
    }

    const size_t sizeOfType = cubs_size_of_tagged_type(optionalErrorTag);
    CubsTaggedValue* mem = cubs_malloc(sizeof(CubsTaggedValue), _Alignof(CubsTaggedValue));
    mem->tag = optionalErrorTag;
    memcpy(&mem->value, optionalErrorMetadata, sizeOfType);
    err.metadata = (void*)mem;
    return err;
}

CubsError cubs_error_init_raw_unchecked(CubsString errorName, CubsRawValue* optionalErrorMetadata, CubsValueTag optionalErrorTag) {
    return cubs_error_init_unchecked(errorName, (void*)optionalErrorMetadata, optionalErrorTag);
}

CubsError cubs_error_init(CubsString errorName, CubsTaggedValue *optionalErrorMetadata)
{
    if(optionalErrorMetadata == NULL) {
        const CubsError err = {.name = errorName, .metadata = NULL};
        return err;
    } else {
        return cubs_error_init_raw_unchecked(errorName, &optionalErrorMetadata->value, optionalErrorMetadata->tag);
    }
}

void cubs_error_deinit(CubsError *self)
{
    cubs_string_deinit(&self->name);
    CubsTaggedValue* metadata = (CubsTaggedValue*)self->metadata;
    if(metadata == NULL) {
        return;
    }
    cubs_tagged_value_deinit(metadata);
    cubs_free((void*)metadata, sizeof(CubsTaggedValue), _Alignof(CubsTaggedValue));
    self->metadata = NULL;
}

const CubsTaggedValue *cubs_error_metadata(const CubsError *self)
{
    return (const CubsTaggedValue*)self->metadata;
}

CubsTaggedValue cubs_error_take_metadata_unchecked(CubsError *self)
{
    assert(self->metadata != NULL);
    CubsTaggedValue* metadata = (CubsTaggedValue*)self->metadata;
    CubsTaggedValue out = *metadata;
    cubs_free((void*)metadata, sizeof(CubsTaggedValue), _Alignof(CubsTaggedValue));
    self->metadata = NULL;
    return out;
}

bool cubs_error_take_metadata(CubsTaggedValue *out, CubsError *self)
{
    if(self->metadata == NULL) {
        return false;
    }
    *out = cubs_error_take_metadata_unchecked(self);
    return true;
}

static const size_t ERR_METADATA_PTR_BITMASK = 0xFFFFFFFFFFFFULL;
static const size_t OK_TAG_SHIFT = 48;
static const size_t OK_TAG_BITMASK = 0b111111ULL << 48;
static const size_t OK_SIZE_SHIFT = 54;
static const size_t OK_SIZE_BITMASK = 0b111111ULL << 54;
static const size_t IS_ERR_BIT = 1ULL << 63;

CubsResult cubs_result_init_ok_unchecked(CubsValueTag okTag, void *okValue)
{
    if(okTag == cubsValueTagNone) {
        const CubsResult result = {0};
        return result;
    }
    const size_t sizeOfOk = cubs_size_of_tagged_type(okTag);
    const size_t tagInfo = (((size_t)okTag) << OK_TAG_SHIFT) | (sizeOfOk << OK_SIZE_SHIFT);
    if(sizeOfOk > sizeof(void*[4])) {
        void* mem = cubs_malloc(sizeOfOk, _Alignof(size_t));
        memcpy(mem, okValue, sizeOfOk);
        const CubsResult result = {.metadata = {(void*)tagInfo, mem, NULL, NULL, NULL}};
        return result;
    } else {
        CubsResult result = {.metadata = {(void*)tagInfo, NULL, NULL, NULL, NULL}};
        memcpy(&result.metadata[1], okValue, sizeOfOk);
        return result;
    }
}

CubsResult cubs_result_init_ok_raw_unchecked(CubsValueTag okTag, CubsRawValue okValue)
{
    return cubs_result_init_ok_unchecked(okTag, (void*)&okValue);
}

CubsResult cubs_result_init_ok(CubsTaggedValue okValue)
{
    return cubs_result_init_ok_unchecked(okValue.tag, (void*)&okValue.value);
}

CubsResult cubs_result_init_err(CubsValueTag okTag, CubsError err)
{
    const size_t sizeOfOk = cubs_size_of_tagged_type(okTag);
    CubsResult result = *(CubsResult*)&err;
    result.metadata[0] = (void*)(((size_t)result.metadata[0]) | (((size_t)okTag) << OK_TAG_SHIFT) | (sizeOfOk << OK_SIZE_SHIFT) | IS_ERR_BIT);
    return result;
}

void cubs_result_deinit(CubsResult *self)
{
    if(cubs_result_is_ok(self)) {
        const CubsValueTag tag = cubs_result_ok_tag(self);
        const size_t sizeOfOk = cubs_size_of_tagged_type(tag);
        if(sizeOfOk > sizeof(void*[4])) {
            void* mem = self->metadata[1];
            if(mem == NULL) {
                return;
            }
            cubs_void_value_deinit(mem, tag);
            cubs_free(mem, sizeOfOk, _Alignof(size_t));
        } else {
            cubs_void_value_deinit((void*)&self->metadata[1], tag);
        }
    } else {
        CubsError err = cubs_result_err_unchecked(self);
        cubs_error_deinit(&err);
    }
}

CubsValueTag cubs_result_ok_tag(const CubsResult * self)
{
    const size_t mask = ((size_t)self->metadata[0]) & OK_TAG_BITMASK;
    return (CubsValueTag)(mask >> OK_TAG_SHIFT);
}

size_t cubs_result_size_of_ok(const CubsResult *self)
{
    const size_t mask = ((size_t)self->metadata[0]) & OK_SIZE_BITMASK;
    return (CubsValueTag)(mask >> OK_SIZE_SHIFT);
}

bool cubs_result_is_ok(const CubsResult *self)
{
    const size_t mask = ((size_t)self->metadata[0]) & IS_ERR_BIT;
    return mask == 0;
}

void cubs_result_ok_unchecked(void *outOk, CubsResult *self)
{
    assert(cubs_result_is_ok(self));
    const size_t sizeOfOk = cubs_result_size_of_ok(self);
    if(sizeOfOk > sizeof(void*[4])) {
        void* src = self->metadata[1];
        memcpy(outOk, src, sizeOfOk);
        cubs_free(src, sizeOfOk, _Alignof(size_t));
    } else {
        memcpy(outOk, &self->metadata[1], sizeOfOk);
    }
    memset(&self->metadata[1], 0, sizeof(void*[4]));
}

CubsResultError cubs_result_ok(void *outOk, CubsResult *self)
{
    if(!cubs_result_is_ok(self)) {
        return cubsResultErrorIsErr;
    }
    cubs_result_ok_unchecked(outOk, self);
    return cubsResultErrorNone;
}

CubsError cubs_result_err_unchecked(CubsResult *self)
{
    _Static_assert(sizeof(CubsError) == sizeof(CubsResult), "CubsError and CubsResult must match in size");
    assert(!cubs_result_is_ok(self));
    CubsError out;
    memcpy((void*)&out, self, sizeof(CubsError));
    out.metadata = (void*)(((size_t)out.metadata) & ERR_METADATA_PTR_BITMASK); // removing flags from metadata ptr
    memset(&self->metadata[1], 0, sizeof(void*[4]));
    self->metadata[0] = (void*)(((size_t)self->metadata[0]) & ~ERR_METADATA_PTR_BITMASK); // remote metadata reference
    return out;
}

CubsResultError cubs_result_err(CubsError *out, CubsResult *self)
{
    if(cubs_result_is_ok(self)) {
        return cubsResultErrorIsOk;
    }
    *out = cubs_result_err_unchecked(self);
    return cubsResultErrorNone;
}
