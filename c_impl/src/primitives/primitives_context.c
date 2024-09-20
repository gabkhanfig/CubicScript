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

#pragma region Bool

static int bool_clone(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_BOOL_CONTEXT);
    cubs_function_return_set_value(handler, (void*)self.ref, &CUBS_BOOL_CONTEXT); // explicitly const cast
    return 0;
}

static int bool_eql(CubsCFunctionHandler handler) {
    CubsConstRef lhs;
    const CubsTypeContext* lhsContext;
    CubsConstRef rhs;
    const CubsTypeContext* rhsContext;

    cubs_function_take_arg(&handler, 0, (void*)&lhs, &lhsContext);
    cubs_function_take_arg(&handler, 1, (void*)&lhs, &lhsContext);

    assert(lhsContext == &CUBS_CONST_REF_CONTEXT || lhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(lhs.context == &CUBS_BOOL_CONTEXT);
    assert(rhsContext == &CUBS_CONST_REF_CONTEXT || rhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(rhs.context == &CUBS_BOOL_CONTEXT);

    bool result = (*(const bool*)lhs.ref) == (*(const bool*)rhs.ref);
    cubs_function_return_set_value(handler, (void*)&result, &CUBS_BOOL_CONTEXT);
    return 0;
}

static int bool_hash(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_BOOL_CONTEXT);
    int64_t hashed = *(const int64_t*)self.ref;
    cubs_function_return_set_value(handler, (void*)&hashed, &CUBS_INT_CONTEXT);
    return 0;
}

const CubsTypeContext CUBS_BOOL_CONTEXT = {
.   sizeOfType = 1,
    .destructor = {0},
    .clone = {.func = {.externC = &bool_clone}, .funcType = cubsFunctionPtrTypeC},
    .eql = {.func = {.externC = &bool_eql}, .funcType = cubsFunctionPtrTypeC},
    .hash = {.func = {.externC = &bool_hash}, .funcType = cubsFunctionPtrTypeC},
    .name = "bool",
    .nameLength = 4,
};

#pragma endregion

#pragma region Int

static int int_clone(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_INT_CONTEXT);
    cubs_function_return_set_value(handler, (void*)self.ref, &CUBS_INT_CONTEXT); // explicitly const cast
    return 0;
}

static int int_eql(CubsCFunctionHandler handler) {
    CubsConstRef lhs;
    const CubsTypeContext* lhsContext;
    CubsConstRef rhs;
    const CubsTypeContext* rhsContext;

    cubs_function_take_arg(&handler, 0, (void*)&lhs, &lhsContext);
    cubs_function_take_arg(&handler, 1, (void*)&lhs, &lhsContext);

    assert(lhsContext == &CUBS_CONST_REF_CONTEXT || lhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(lhs.context == &CUBS_INT_CONTEXT);
    assert(rhsContext == &CUBS_CONST_REF_CONTEXT || rhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(rhs.context == &CUBS_INT_CONTEXT);

    bool result = (*(const int64_t*)lhs.ref) == (*(const int64_t*)rhs.ref);
    cubs_function_return_set_value(handler, (void*)&result, &CUBS_BOOL_CONTEXT);
    return 0;
}

static int int_hash(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_INT_CONTEXT);
    int64_t hashed = *(const int64_t*)self.ref;
    cubs_function_return_set_value(handler, (void*)&hashed, &CUBS_INT_CONTEXT);
    return 0;
}

const CubsTypeContext CUBS_INT_CONTEXT = {
    .sizeOfType = sizeof(int64_t),
    .destructor = {0}, 
    .clone = {.func = {.externC = &int_clone}, .funcType = cubsFunctionPtrTypeC},
    .eql = {.func = {.externC = &int_eql}, .funcType = cubsFunctionPtrTypeC},
    .hash = {.func = {.externC = &int_hash}, .funcType = cubsFunctionPtrTypeC},
    .name = "int",
    .nameLength = 3,
};

#pragma endregion

#pragma region Float

static int float_clone(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_FLOAT_CONTEXT);
    cubs_function_return_set_value(handler, (void*)self.ref, &CUBS_FLOAT_CONTEXT); // explicitly const cast
    return 0;
}

static int float_eql(CubsCFunctionHandler handler) {
    CubsConstRef lhs;
    const CubsTypeContext* lhsContext;
    CubsConstRef rhs;
    const CubsTypeContext* rhsContext;

    cubs_function_take_arg(&handler, 0, (void*)&lhs, &lhsContext);
    cubs_function_take_arg(&handler, 1, (void*)&lhs, &lhsContext);

    assert(lhsContext == &CUBS_CONST_REF_CONTEXT || lhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(lhs.context == &CUBS_FLOAT_CONTEXT);
    assert(rhsContext == &CUBS_CONST_REF_CONTEXT || rhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(rhs.context == &CUBS_FLOAT_CONTEXT);

    bool result = (*(const double*)lhs.ref) == (*(const double*)rhs.ref);
    cubs_function_return_set_value(handler, (void*)&result, &CUBS_BOOL_CONTEXT);
    return 0;
}

static int float_hash(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_FLOAT_CONTEXT);
    int64_t hashed = (int64_t)(*(const double*)self.ref); // cast to integer cause silly float representation nonsense
    cubs_function_return_set_value(handler, (void*)&hashed, &CUBS_INT_CONTEXT);
    return 0;
}

const CubsTypeContext CUBS_FLOAT_CONTEXT = {
    .sizeOfType = sizeof(double),
    .destructor = {0}, 
    .clone = {.func = {.externC = &float_clone}, .funcType = cubsFunctionPtrTypeC},
    .eql = {.func = {.externC = &float_eql}, .funcType = cubsFunctionPtrTypeC},
    .hash = {.func = {.externC = &float_hash}, .funcType = cubsFunctionPtrTypeC},
    .name = "float",
    .nameLength = 5,
};

#pragma endregion

#pragma region String

static int string_deinit(CubsCFunctionHandler handler) {
    CubsString self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_STRING_CONTEXT);
    cubs_string_deinit(&self);
}

static int string_clone(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_STRING_CONTEXT);
    CubsString clone = cubs_string_clone((const CubsString*)self.ref);
    cubs_function_return_set_value(handler, (void*)&clone, &CUBS_STRING_CONTEXT); // explicitly const cast
    return 0;
}

static int string_eql(CubsCFunctionHandler handler) {
    CubsConstRef lhs;
    const CubsTypeContext* lhsContext;
    CubsConstRef rhs;
    const CubsTypeContext* rhsContext;

    cubs_function_take_arg(&handler, 0, (void*)&lhs, &lhsContext);
    cubs_function_take_arg(&handler, 1, (void*)&lhs, &lhsContext);

    assert(lhsContext == &CUBS_CONST_REF_CONTEXT || lhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(lhs.context == &CUBS_STRING_CONTEXT);
    assert(rhsContext == &CUBS_CONST_REF_CONTEXT || rhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(rhs.context == &CUBS_STRING_CONTEXT);

    bool result = cubs_string_eql((const CubsString*)lhs.ref, (const CubsString*)rhs.ref);
    cubs_function_return_set_value(handler, (void*)&result, &CUBS_BOOL_CONTEXT);
    return 0;
}

static int string_hash(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_STRING_CONTEXT);
    size_t hashed = cubs_string_hash((const CubsString*)self.ref);
    cubs_function_return_set_value(handler, (void*)&hashed, &CUBS_INT_CONTEXT);
    return 0;
}

const CubsTypeContext CUBS_STRING_CONTEXT = {
    .sizeOfType = sizeof(CubsString),
    .destructor = {.func = {.externC = &string_deinit}, .funcType = cubsFunctionPtrTypeC},
    .clone = {.func = {.externC = &string_clone}, .funcType = cubsFunctionPtrTypeC},
    .eql = {.func = {.externC = &string_eql}, .funcType = cubsFunctionPtrTypeC},
    .hash = {.func = {.externC = &string_hash}, .funcType = cubsFunctionPtrTypeC},
    .name = "string",
    .nameLength = 6,
};

#pragma endregion

static void array_clone(CubsArray* dst, const CubsArray* self) {
    const CubsArray temp = cubs_array_clone(self);
    *dst = temp;
}

const CubsTypeContext CUBS_ARRAY_CONTEXT = {
    .sizeOfType = sizeof(CubsArray),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "array",
    .nameLength = 5,
};

static void set_clone(CubsSet* dst, const CubsSet* self) {
    const CubsSet temp = cubs_set_clone(self);
    *dst = temp;
}

const CubsTypeContext CUBS_SET_CONTEXT = {
    .sizeOfType = sizeof(CubsSet),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "set",
    .nameLength = 3,
};

static void map_clone(CubsMap* dst, const CubsMap* self) {
    const CubsMap temp = cubs_map_clone(self);
    *dst = temp;
}

const CubsTypeContext CUBS_MAP_CONTEXT = {
    .sizeOfType = sizeof(CubsMap),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "map",
    .nameLength = 3,
};

static void option_clone(CubsOption* dst, const CubsOption* self) {
    const CubsOption temp = cubs_option_clone(self);
    *dst = temp;
}

const CubsTypeContext CUBS_OPTION_CONTEXT = {
    .sizeOfType = sizeof(CubsOption),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "option",
    .nameLength = 6,
};

static void error_clone(CubsError* dst, const CubsError* self) {
    const CubsError temp = cubs_error_clone(self);
    *dst = temp;
}

const CubsTypeContext CUBS_ERROR_CONTEXT = {
    .sizeOfType = sizeof(CubsError),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "error",
    .nameLength = 5,
};

// static void result_clone(CubsResult* dst, const CubsResult* self) {
//     const CubsResult temp = cubs_result_clone(self);
//     *dst = temp;
// }

const CubsTypeContext CUBS_RESULT_CONTEXT = {
    .sizeOfType = sizeof(CubsResult),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "result",
    .nameLength = 6,
};

const CubsTypeContext CUBS_UNIQUE_CONTEXT = {
    .sizeOfType = sizeof(CubsUnique),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "unique",
    .nameLength = 6,
};

static void shared_clone(CubsShared* dst, const CubsShared* self) {
    const CubsShared temp = cubs_shared_clone(self);
    *dst = temp;
}

const CubsTypeContext CUBS_SHARED_CONTEXT = {
    .sizeOfType = sizeof(CubsShared),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "shared",
    .nameLength = 6,
};

static void weak_clone(CubsWeak* dst, const CubsWeak* self) {
    const CubsWeak temp = cubs_weak_clone(self);
    *dst = temp;
}

const CubsTypeContext CUBS_WEAK_CONTEXT = {
    .sizeOfType = sizeof(CubsWeak),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "weak",
    .nameLength = 4,
};

const CubsTypeContext CUBS_FUNCTION_CONTEXT = {
    .sizeOfType = sizeof(CubsFunction),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "function",
    .nameLength = 8,
};

const CubsTypeContext CUBS_CONST_REF_CONTEXT = {
    .sizeOfType = sizeof(CubsConstRef),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "const_ref",
    .nameLength = 9,
};

const CubsTypeContext CUBS_MUT_REF_CONTEXT = {
    .sizeOfType = sizeof(CubsMutRef),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "mut_ref",
    .nameLength = 7,
};

void cubs_context_fast_deinit(void *value, const CubsTypeContext *context)
{
    if(context->destructor.func.externC == NULL) { // works for script types too cause union
        return;
    }
    else if(context == &CUBS_STRING_CONTEXT) {
        cubs_string_deinit((CubsString*)value);
    } else if (context == &CUBS_ARRAY_CONTEXT) {
        cubs_array_deinit((CubsString*)value);
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
    if(context == &CUBS_STRING_CONTEXT) {
        const CubsString ret = cubs_string_clone((const CubsString*)value);
        *(CubsString*)out = ret;
    } else {
        CubsFunctionCallArgs args = cubs_function_start_call(&context->clone);

        CubsConstRef arg = {.ref = value, .context = context};
        cubs_function_push_arg(&args, (void*)&arg, &CUBS_CONST_REF_CONTEXT);

        const CubsTypeContext* outContext = NULL;
        const CubsFunctionReturn ret = {.value = out, .context = &outContext};
        const int result = cubs_function_call(args, ret);
        assert(outContext == context && "return type for clone mismatch");
    }
}

bool cubs_context_fast_eql(const void *lhs, const void *rhs, const CubsTypeContext *context)
{
    assert(context->eql.func.externC != NULL && "Cannot do equality comaprison on type that doesn't have a valid externC or script function");
    if(context == &CUBS_STRING_CONTEXT) {
        return cubs_string_eql(lhs, rhs);
    } else {
        CubsFunctionCallArgs args = cubs_function_start_call(&context->clone);

        CubsConstRef argLhs = {.ref = lhs, .context = context};
        CubsConstRef argRhs = {.ref = rhs, .context = context};
        cubs_function_push_arg(&args, (void*)&argLhs, &CUBS_CONST_REF_CONTEXT);
        cubs_function_push_arg(&args, (void*)&argRhs, &CUBS_CONST_REF_CONTEXT);

        bool out;
        const CubsTypeContext* outContext = NULL;
        const CubsFunctionReturn ret = {.value = (void*)&out, .context = &outContext};
        const int result = cubs_function_call(args, ret);
        assert(outContext == &CUBS_BOOL_CONTEXT && "expected bool return type for equality comparison");
        return out;
    }
}

size_t cubs_context_fast_hash(const void *value, const CubsTypeContext *context)
{
    assert(context->eql.func.externC != NULL && "Cannot do hash on type that doesn't have a valid externC or script function");
    if(context == &CUBS_STRING_CONTEXT) {
        return cubs_string_hash(value);
    } else {
        CubsFunctionCallArgs args = cubs_function_start_call(&context->clone);

        CubsConstRef arg = {.ref = value, .context = context};
        cubs_function_push_arg(&args, (void*)&arg, &CUBS_CONST_REF_CONTEXT);

        int64_t out;
        const CubsTypeContext* outContext = NULL;
        const CubsFunctionReturn ret = {.value = (void*)&out, .context = &outContext};
        const int result = cubs_function_call(args, ret);
        assert(outContext == &CUBS_INT_CONTEXT && "expected int return type for hash");
        return (size_t)out;
    }
}
