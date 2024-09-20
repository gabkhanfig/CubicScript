#include "reference.h"
#include <assert.h>
#include "../primitives_context.h"

bool cubs_const_ref_eql(const CubsConstRef *self, const CubsConstRef *other)
{
    assert(self->context == other->context);
    assert(self->context->eql.func.externC != NULL);
    return cubs_context_fast_eql(self->ref, other->ref, self->context);
}

bool cubs_const_ref_eql_value(const CubsConstRef* self, const void* other) 
{
    assert(other != NULL);
    assert(self->context->eql.func.externC != NULL);
    return cubs_context_fast_eql(self->ref, other, self->context);
}

size_t cubs_const_ref_hash(const CubsConstRef *self)
{
    assert(self->context->hash.func.externC != NULL);
    return cubs_context_fast_hash(self->ref, self->context);
}

bool cubs_mut_ref_eql(const CubsMutRef *self, const CubsMutRef *other)
{
    assert(self->context == other->context);
    assert(self->context->eql.func.externC != NULL);
    return cubs_context_fast_eql(self->ref, other->ref, self->context);
}

bool cubs_mut_ref_eql_value(const CubsMutRef *self, const void *other)
{
    assert(other != NULL);
    assert(self->context->eql.func.externC != NULL);
    return cubs_context_fast_eql(self->ref, other, self->context);
}

size_t cubs_mut_ref_hash(const CubsMutRef *self)
{
    assert(self->context->hash.func.externC != NULL);
    return cubs_context_fast_hash(self->ref, self->context);
}
