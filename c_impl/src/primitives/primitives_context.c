#include "primitives_context.h"
#include "../primitives/string/string.h"
#include "../primitives/array/array.h"
#include "../primitives/set/set.h"
#include "../primitives/map/map.h"
#include "../primitives/option/option.h"
#include "../primitives/error/error.h"
#include "../primitives/result/result.h"
#include "../primitives/sync_ptr/sync_ptr.h"
#include "../primitives/function/function.h"
#include "../primitives/reference/reference.h"
#include "../util/panic.h"
#include <assert.h>

/*
static const CubsTypeContext _CONTEXT = {
    .sizeOfType = sizeof(),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "",
    .nameLength = ,
};
const CubsTypeContext* CUBS__CONTEXT = &_CONTEXT;
*/

static int bool_clone(CubsCFunctionHandler handler) {
    bool self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == CUBS_BOOL_CONTEXT);
    cubs_function_return_set_value(handler, (void*)&self, CUBS_BOOL_CONTEXT);
    return 0;
}

static int bool_eql(CubsCFunctionHandler handler) {
    bool lhs;
    const CubsTypeContext* lhsContext;
    bool rhs;
    const CubsTypeContext* rhsContext;
    cubs_function_take_arg(&handler, 0, (void*)&lhs, &lhsContext);
    cubs_function_take_arg(&handler, 1, (void*)&lhs, &lhsContext);
    assert(lhsContext == CUBS_BOOL_CONTEXT);
    assert(rhsContext == CUBS_BOOL_CONTEXT);
    bool result = lhs == rhs;
    cubs_function_return_set_value(handler, (void*)&result, CUBS_BOOL_CONTEXT);
    return 0;
}

static int bool_hash(CubsCFunctionHandler handler) {
    bool self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    int64_t hashed = (int64_t)self;
    cubs_function_return_set_value(handler, (void*)&hashed, CUBS_INT_CONTEXT);
    return 0;
}

static const CubsTypeContext BOOL_CONTEXT = {
.   sizeOfType = 1,
    .destructor = {0},
    .clone = {.func = {.externC = &bool_clone}, .funcType = cubsFunctionPtrTypeC},
    .eql = {0},
    .hash = {0},
    .name = "bool",
    .nameLength = 4,
};
const CubsTypeContext* CUBS_BOOL_CONTEXT = &BOOL_CONTEXT;

static void int_clone(int64_t* dst, const int64_t* self) {
    *dst = *self;
}

static bool int_eql(const int64_t* self, const int64_t* other) {
    return *self == *other;
}

static size_t int_hash(const int64_t* self) {
    // Don't bother combining with the seed, as the hashmap and hashset do that themselves
    return (size_t)(*self);
}

static const CubsTypeContext INT_CONTEXT = {
    .sizeOfType = sizeof(int64_t),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "int",
    .nameLength = 3,
};
const CubsTypeContext* CUBS_INT_CONTEXT = &INT_CONTEXT;

static void float_clone(double* dst, const double* self) {
    *dst = *self;
}

static bool float_eql(const double* self, const double* other) {
    return *self == *other;
}

static size_t float_hash(const double* self) {  
    // Since technically multiple representations can be the same value,
    // cast to an integer and hash from there 
    // Don't bother combining with the seed, as the hashmap and hashset do that themselves
    const int64_t floatAsInt = (int64_t)(*self);
    return int_hash(&floatAsInt);
}

static const CubsTypeContext FLOAT_CONTEXT = {
    .sizeOfType = sizeof(double),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "float",
    .nameLength = 5,
};
const CubsTypeContext* CUBS_FLOAT_CONTEXT = &FLOAT_CONTEXT;

static void string_clone(CubsString* dst, const CubsString* self) {
    const CubsString temp = cubs_string_clone(self);
    *dst = temp;
}

static const CubsTypeContext STRING_CONTEXT = {
    .sizeOfType = sizeof(CubsString),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "string",
    .nameLength = 6,
};
const CubsTypeContext* CUBS_STRING_CONTEXT = &STRING_CONTEXT;

static void array_clone(CubsArray* dst, const CubsArray* self) {
    const CubsArray temp = cubs_array_clone(self);
    *dst = temp;
}

static const CubsTypeContext ARRAY_CONTEXT = {
    .sizeOfType = sizeof(CubsArray),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "array",
    .nameLength = 5,
};
const CubsTypeContext* CUBS_ARRAY_CONTEXT = &ARRAY_CONTEXT;

static void set_clone(CubsSet* dst, const CubsSet* self) {
    const CubsSet temp = cubs_set_clone(self);
    *dst = temp;
}

static const CubsTypeContext SET_CONTEXT = {
    .sizeOfType = sizeof(CubsSet),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "set",
    .nameLength = 3,
};
const CubsTypeContext* CUBS_SET_CONTEXT = &SET_CONTEXT;

static void map_clone(CubsMap* dst, const CubsMap* self) {
    const CubsMap temp = cubs_map_clone(self);
    *dst = temp;
}

static const CubsTypeContext MAP_CONTEXT = {
    .sizeOfType = sizeof(CubsMap),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "map",
    .nameLength = 3,
};
const CubsTypeContext* CUBS_MAP_CONTEXT = &MAP_CONTEXT;

static void option_clone(CubsOption* dst, const CubsOption* self) {
    const CubsOption temp = cubs_option_clone(self);
    *dst = temp;
}

static const CubsTypeContext OPTION_CONTEXT = {
    .sizeOfType = sizeof(CubsOption),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "option",
    .nameLength = 6,
};
const CubsTypeContext* CUBS_OPTION_CONTEXT = &OPTION_CONTEXT;

static void error_clone(CubsError* dst, const CubsError* self) {
    const CubsError temp = cubs_error_clone(self);
    *dst = temp;
}

static const CubsTypeContext ERROR_CONTEXT = {
    .sizeOfType = sizeof(CubsError),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "error",
    .nameLength = 5,
};
const CubsTypeContext* CUBS_ERROR_CONTEXT = &ERROR_CONTEXT;

// static void result_clone(CubsResult* dst, const CubsResult* self) {
//     const CubsResult temp = cubs_result_clone(self);
//     *dst = temp;
// }

static const CubsTypeContext RESULT_CONTEXT = {
    .sizeOfType = sizeof(CubsResult),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "result",
    .nameLength = 6,
};
const CubsTypeContext* CUBS_RESULT_CONTEXT = &RESULT_CONTEXT;

static const CubsTypeContext UNIQUE_CONTEXT = {
    .sizeOfType = sizeof(CubsUnique),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "unique",
    .nameLength = 6,
};
const CubsTypeContext* CUBS_UNIQUE_CONTEXT = &UNIQUE_CONTEXT;

static void shared_clone(CubsShared* dst, const CubsShared* self) {
    const CubsShared temp = cubs_shared_clone(self);
    *dst = temp;
}

static const CubsTypeContext SHARED_CONTEXT = {
    .sizeOfType = sizeof(CubsShared),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "shared",
    .nameLength = 6,
};
const CubsTypeContext* CUBS_SHARED_CONTEXT = &SHARED_CONTEXT;

static void weak_clone(CubsWeak* dst, const CubsWeak* self) {
    const CubsWeak temp = cubs_weak_clone(self);
    *dst = temp;
}

static const CubsTypeContext WEAK_CONTEXT = {
    .sizeOfType = sizeof(CubsWeak),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "weak",
    .nameLength = 4,
};
const CubsTypeContext* CUBS_WEAK_CONTEXT = &WEAK_CONTEXT;

static const CubsTypeContext FUNCTION_CONTEXT = {
    .sizeOfType = sizeof(CubsFunction),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "function",
    .nameLength = 8,
};
const CubsTypeContext* CUBS_FUNCTION_CONTEXT = &FUNCTION_CONTEXT;

static const CubsTypeContext CONST_REF_CONTEXT = {
    .sizeOfType = sizeof(CubsConstRef),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "const_ref",
    .nameLength = 9,
};
const CubsTypeContext* CUBS_CONST_REF_CONTEXT = &CONST_REF_CONTEXT;

static const CubsTypeContext MUT_REF_CONTEXT = {
    .sizeOfType = sizeof(CubsMutRef),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "mut_ref",
    .nameLength = 7,
};
const CubsTypeContext* CUBS_MUT_REF_CONTEXT = &MUT_REF_CONTEXT;

void cubs_context_fast_deinit(void *value, const CubsTypeContext *context)
{
    if(context->destructor.func.externC == NULL) { // works for script types too cause union
        return;
    }
    else if(context == CUBS_STRING_CONTEXT) {
        cubs_string_deinit((CubsString*)value);
    } else {
        CubsFunctionCallArgs args = cubs_function_start_call(&context->destructor);
        cubs_function_push_arg(&args, value, context);
        const CubsFunctionReturn nullReturn = {0};
        const int result = cubs_function_call(args, nullReturn);
        assert(result == 0 && "Deinitialization can never fail");
    }
}

void cubs_context_fast_clone(void *out, const void *value, const CubsTypeContext *context)
{
    assert(context->clone.func.externC != NULL && "Cannot clone type that doesn't have a valid externC or script function");
    if(context == CUBS_STRING_CONTEXT) {
        const CubsString ret = cubs_string_clone((const CubsString*)value);
        *(CubsString*)out = ret;
    } else {
        CubsFunctionCallArgs args = cubs_function_start_call(&context->clone);

        CubsConstRef arg = {.ref = value, .context = context};
        cubs_function_push_arg(&args, (void*)&arg, CUBS_CONST_REF_CONTEXT);

        const CubsTypeContext* outContext = NULL;
        const CubsFunctionReturn ret = {.value = out, .context = &outContext};
        const int result = cubs_function_call(args, ret);
        assert(outContext == context && "return type for clone mismatch");
    }
}

bool cubs_context_fast_eql(const void *lhs, const void *rhs, const CubsTypeContext *context)
{
    assert(context->eql.func.externC != NULL && "Cannot do equality comaprison on type that doesn't have a valid externC or script function");
    if(context == CUBS_STRING_CONTEXT) {
        return cubs_string_eql(lhs, rhs);
    } else {
        CubsFunctionCallArgs args = cubs_function_start_call(&context->clone);

        CubsConstRef argLhs = {.ref = lhs, .context = context};
        CubsConstRef argRhs = {.ref = rhs, .context = context};
        cubs_function_push_arg(&args, (void*)&argLhs, CUBS_CONST_REF_CONTEXT);
        cubs_function_push_arg(&args, (void*)&argRhs, CUBS_CONST_REF_CONTEXT);

        bool out;
        const CubsTypeContext* outContext = NULL;
        const CubsFunctionReturn ret = {.value = (void*)&out, .context = &outContext};
        const int result = cubs_function_call(args, ret);
        assert(outContext == CUBS_BOOL_CONTEXT && "expected bool return type for equality comparison");
        return out;
    }
}

size_t cubs_context_fast_hash(const void *value, const CubsTypeContext *context)
{
    assert(context->eql.func.externC != NULL && "Cannot do hash on type that doesn't have a valid externC or script function");
    if(context == CUBS_STRING_CONTEXT) {
        return cubs_string_hash(value);
    } else {
        CubsFunctionCallArgs args = cubs_function_start_call(&context->clone);

        CubsConstRef arg = {.ref = value, .context = context};
        cubs_function_push_arg(&args, (void*)&arg, CUBS_CONST_REF_CONTEXT);

        int64_t out;
        const CubsTypeContext* outContext = NULL;
        const CubsFunctionReturn ret = {.value = (void*)&out, .context = &outContext};
        const int result = cubs_function_call(args, ret);
        assert(outContext == CUBS_INT_CONTEXT && "expected int return type for hash");
        return (size_t)out;
    }
}
