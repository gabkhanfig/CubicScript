#include "result.h"
#include "../primitives_context.h"
#include "../../util/global_allocator.h"
#include <assert.h>
#include <string.h>
#include "../error/error.h"

CubsResult cubs_result_init_ok_primitive(void *okValue, CubsValueTag okTag)
{
    if(okValue == NULL) {
        assert(okTag == 0);
        return cubs_result_init_ok_user_class(NULL, NULL);
    } else {
        return cubs_result_init_ok_user_class(okValue, cubs_primitive_context_for_tag(okTag));
    }
}

CubsResult cubs_result_init_ok_user_class(void *okValue, const CubsTypeContext *okContext)
{
    if(okValue == NULL) {
        const CubsResult result = {.metadata = {0}, .isErr = false, .context = NULL};
        return result;
    } else {
        assert(okContext != NULL);
        CubsResult result = {.metadata = {0}, .isErr = false, .context = okContext};
        if(okContext->sizeOfType <= sizeof(result.metadata)) {
            memcpy(&result.metadata, okValue, okContext->sizeOfType);
        } else {
            void* mem = cubs_malloc(okContext->sizeOfType, _Alignof(size_t));
            memcpy(mem, okValue, okContext->sizeOfType);
            result.metadata[0] = mem;
        }
        return result;
    }
}

CubsResult cubs_result_init_err_primitive(CubsError errValue, CubsValueTag okTag)
{
    if(okTag == 0) {
        return cubs_result_init_err_user_class(errValue, NULL);
    } else {        
        return cubs_result_init_err_user_class(errValue, cubs_primitive_context_for_tag(okTag));
    }
}

CubsResult cubs_result_init_err_user_class(CubsError errValue, const CubsTypeContext *okContext)
{
    CubsResult result = {.metadata = {0}, .isErr = true, .context = okContext};
    memcpy((void*)&result.metadata, (const void*)&errValue, sizeof(CubsError));
    return result;
}

void cubs_result_deinit(CubsResult *self)
{
    if(!self->isErr) {
        if(self->context == NULL) {
            return;
        }
        void* okValue = cubs_result_get_ok_mut(self);
        if(self->context->destructor != NULL) {
            self->context->destructor(okValue);
        }
        if(self->context->sizeOfType > sizeof(self->metadata)) {
            cubs_free(okValue, self->context->sizeOfType, _Alignof(size_t));
        }
    } else {
        CubsError* err = cubs_result_get_err_mut(self);
        cubs_error_deinit(err);
    }
    memset((void*)self, 0, sizeof(CubsResult));
}

const void *cubs_result_get_ok(const CubsResult *self)
{
    assert(!self->isErr);
    assert(self->context != NULL);

    if(self->context->sizeOfType <= sizeof(self->metadata)) {
        return &self->metadata;
    } else {
        return self->metadata[0];
    }
}

void *cubs_result_get_ok_mut(CubsResult *self)
{
    assert(!self->isErr);
    assert(self->context != NULL);

    if(self->context->sizeOfType <= sizeof(self->metadata)) {
        return &self->metadata;
    } else {
        return self->metadata[0];
    }
}

void cubs_result_take_ok(void *outOk, CubsResult *self)
{
    assert(!self->isErr);
    assert(self->context != NULL);

    void* okValue = cubs_result_get_ok_mut(self);
    memcpy(outOk, okValue, self->context->sizeOfType);
    if(self->context->sizeOfType > sizeof(self->metadata)) {
        cubs_free(okValue, self->context->sizeOfType, _Alignof(size_t));
    }
    memset((void*)self, 0, sizeof(CubsResult));
}

const CubsError *cubs_result_get_err(const CubsResult *self)
{
    assert(self->isErr);
    return (const CubsError*)&self->metadata;
}

CubsError *cubs_result_get_err_mut(CubsResult *self)
{
    assert(self->isErr);
    return (CubsError*)&self->metadata;
}

CubsError cubs_result_take_err(CubsResult *self)
{
    assert(self->isErr);
    CubsError err;
    memcpy((void*)&err, (const void*)cubs_result_get_err(self), sizeof(CubsError));
    memset((void*)self, 0, sizeof(CubsResult));
    return err;
}
