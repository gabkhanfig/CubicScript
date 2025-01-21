#include "context.h"
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
const CubsTypeContext CUBS__CONTEXT = {
    .sizeOfType = sizeof(),
    .destructor = {0}, 
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "",
    .nameLength = ,
    .members = ,
    .membersLen = ,
};
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
    CubsConstRef lhs = {0};
    const CubsTypeContext* lhsContext = NULL;
    CubsConstRef rhs = {0};
    const CubsTypeContext* rhsContext = NULL;

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
    .sizeOfType = 1,
    .destructor = {0},
    .clone = {.func = {.externC = &bool_clone}, .funcType = cubsFunctionPtrTypeC},
    .eql = {.func = {.externC = &bool_eql}, .funcType = cubsFunctionPtrTypeC},
    .hash = {.func = {.externC = &bool_hash}, .funcType = cubsFunctionPtrTypeC},
    .name = "bool",
    .nameLength = 4,
    .members = NULL,
    .membersLen = 0,
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
    cubs_function_take_arg(&handler, 1, (void*)&rhs, &rhsContext);

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
    .members = NULL,
    .membersLen = 0,
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
    cubs_function_take_arg(&handler, 1, (void*)&rhs, &rhsContext);

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
    .members = NULL,
    .membersLen = 0,
};

#pragma endregion

#pragma region Char

static int char_clone(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_CHAR_CONTEXT);
    cubs_function_return_set_value(handler, (void*)self.ref, &CUBS_CHAR_CONTEXT); // explicitly const cast
    return 0;
}

static int char_eql(CubsCFunctionHandler handler) {
    CubsConstRef lhs;
    const CubsTypeContext* lhsContext;
    CubsConstRef rhs;
    const CubsTypeContext* rhsContext;

    cubs_function_take_arg(&handler, 0, (void*)&lhs, &lhsContext);
    cubs_function_take_arg(&handler, 1, (void*)&rhs, &rhsContext);

    assert(lhsContext == &CUBS_CONST_REF_CONTEXT || lhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(lhs.context == &CUBS_CHAR_CONTEXT);
    assert(rhsContext == &CUBS_CONST_REF_CONTEXT || rhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(rhs.context == &CUBS_CHAR_CONTEXT);

    bool result = (*(const CubsChar*)lhs.ref) == (*(const CubsChar*)rhs.ref);
    cubs_function_return_set_value(handler, (void*)&result, &CUBS_BOOL_CONTEXT);
    return 0;
}

static int char_hash(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_CHAR_CONTEXT);
    int64_t hashed = (int64_t)*(const CubsChar*)self.ref;
    cubs_function_return_set_value(handler, (void*)&hashed, &CUBS_INT_CONTEXT);
    return 0;
}

const CubsTypeContext CUBS_CHAR_CONTEXT = {
    .sizeOfType = sizeof(CubsChar),
    .destructor = {0}, 
    .clone = {.func = {.externC = &char_clone}, .funcType = cubsFunctionPtrTypeC},
    .eql = {.func = {.externC = &char_eql}, .funcType = cubsFunctionPtrTypeC},  
    .hash = {.func = {.externC = &char_hash}, .funcType = cubsFunctionPtrTypeC},
    .name = "char",
    .nameLength = 4,
    .members = NULL,
    .membersLen = 0,
};

#pragma endregion

#pragma region String

static int string_deinit(CubsCFunctionHandler handler) {
    CubsString self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_STRING_CONTEXT);
    cubs_string_deinit(&self);
    return 0;
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
    cubs_function_take_arg(&handler, 1, (void*)&rhs, &rhsContext);

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
    .members = NULL,
    .membersLen = 0,
};

#pragma endregion

#pragma region Array

static int array_deinit(CubsCFunctionHandler handler) {
    CubsArray self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_ARRAY_CONTEXT);
    cubs_array_deinit(&self);
    return 0;
}

static int array_clone(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_ARRAY_CONTEXT);
    CubsArray clone = cubs_array_clone((const CubsArray*)self.ref);
    cubs_function_return_set_value(handler, (void*)&clone, &CUBS_ARRAY_CONTEXT); // explicitly const cast
    return 0;
}

static int array_eql(CubsCFunctionHandler handler) {
    CubsConstRef lhs;
    const CubsTypeContext* lhsContext;
    CubsConstRef rhs;
    const CubsTypeContext* rhsContext;

    cubs_function_take_arg(&handler, 0, (void*)&lhs, &lhsContext);
    cubs_function_take_arg(&handler, 1, (void*)&rhs, &rhsContext);

    assert(lhsContext == &CUBS_CONST_REF_CONTEXT || lhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(lhs.context == &CUBS_ARRAY_CONTEXT);
    assert(rhsContext == &CUBS_CONST_REF_CONTEXT || rhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(rhs.context == &CUBS_ARRAY_CONTEXT);

    bool result = cubs_array_eql((const CubsArray*)lhs.ref, (const CubsArray*)rhs.ref);
    cubs_function_return_set_value(handler, (void*)&result, &CUBS_BOOL_CONTEXT);
    return 0;
}

static int array_hash(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_ARRAY_CONTEXT);
    size_t hashed = cubs_array_hash((const CubsArray*)self.ref);
    cubs_function_return_set_value(handler, (void*)&hashed, &CUBS_INT_CONTEXT);
    return 0;
}

const CubsTypeContext CUBS_ARRAY_CONTEXT = {
    .sizeOfType = sizeof(CubsArray),
    .destructor = {.func = {.externC = &array_deinit}, .funcType = cubsFunctionPtrTypeC},
    .clone = {.func = {.externC = &array_clone}, .funcType = cubsFunctionPtrTypeC},
    .eql = {.func = {.externC = &array_eql}, .funcType = cubsFunctionPtrTypeC},
    .hash = {.func = {.externC = &array_hash}, .funcType = cubsFunctionPtrTypeC},
    .name = "array",
    .nameLength = 5,
    .members = NULL,
    .membersLen = 0,
};

#pragma endregion

#pragma region Set

static int set_deinit(CubsCFunctionHandler handler) {
    CubsSet self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_SET_CONTEXT);
    cubs_set_deinit(&self);
    return 0;
}

static int set_clone(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_SET_CONTEXT);
    CubsSet clone = cubs_set_clone((const CubsSet*)self.ref);
    cubs_function_return_set_value(handler, (void*)&clone, &CUBS_SET_CONTEXT); // explicitly const cast
    return 0;
}

static int set_eql(CubsCFunctionHandler handler) {
    CubsConstRef lhs;
    const CubsTypeContext* lhsContext;
    CubsConstRef rhs;
    const CubsTypeContext* rhsContext;

    cubs_function_take_arg(&handler, 0, (void*)&lhs, &lhsContext);
    cubs_function_take_arg(&handler, 1, (void*)&rhs, &rhsContext);

    assert(lhsContext == &CUBS_CONST_REF_CONTEXT || lhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(lhs.context == &CUBS_SET_CONTEXT);
    assert(rhsContext == &CUBS_CONST_REF_CONTEXT || rhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(rhs.context == &CUBS_SET_CONTEXT);

    bool result = cubs_set_eql((const CubsSet*)lhs.ref, (const CubsSet*)rhs.ref);
    cubs_function_return_set_value(handler, (void*)&result, &CUBS_BOOL_CONTEXT);
    return 0;
}

static int set_hash(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_SET_CONTEXT);
    size_t hashed = cubs_set_hash((const CubsSet*)self.ref);
    cubs_function_return_set_value(handler, (void*)&hashed, &CUBS_INT_CONTEXT);
    return 0;
}

const CubsTypeContext CUBS_SET_CONTEXT = {
    .sizeOfType = sizeof(CubsSet),
    .destructor = {.func = {.externC = &set_deinit}, .funcType = cubsFunctionPtrTypeC},
    .clone = {.func = {.externC = &set_clone}, .funcType = cubsFunctionPtrTypeC},
    .eql = {.func = {.externC = &set_eql}, .funcType = cubsFunctionPtrTypeC},
    .hash = {.func = {.externC = &set_hash}, .funcType = cubsFunctionPtrTypeC},
    .name = "set",
    .nameLength = 3,
    .members = NULL,
    .membersLen = 0,
};

#pragma endregion

#pragma region Map

static int map_deinit(CubsCFunctionHandler handler) {
    CubsMap self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_MAP_CONTEXT);
    cubs_map_deinit(&self);
    return 0;
}

static int map_clone(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_MAP_CONTEXT);
    CubsMap clone = cubs_map_clone((const CubsMap*)self.ref);
    cubs_function_return_set_value(handler, (void*)&clone, &CUBS_MAP_CONTEXT); // explicitly const cast
    return 0;
}

static int map_eql(CubsCFunctionHandler handler) {
    CubsConstRef lhs;
    const CubsTypeContext* lhsContext;
    CubsConstRef rhs;
    const CubsTypeContext* rhsContext;

    cubs_function_take_arg(&handler, 0, (void*)&lhs, &lhsContext);
    cubs_function_take_arg(&handler, 1, (void*)&rhs, &rhsContext);

    assert(lhsContext == &CUBS_CONST_REF_CONTEXT || lhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(lhs.context == &CUBS_MAP_CONTEXT);
    assert(rhsContext == &CUBS_CONST_REF_CONTEXT || rhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(rhs.context == &CUBS_MAP_CONTEXT);

    bool result = cubs_map_eql((const CubsMap*)lhs.ref, (const CubsMap*)rhs.ref);
    cubs_function_return_set_value(handler, (void*)&result, &CUBS_BOOL_CONTEXT);
    return 0;
}

static int map_hash(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_MAP_CONTEXT);
    size_t hashed = cubs_map_hash((const CubsMap*)self.ref);
    cubs_function_return_set_value(handler, (void*)&hashed, &CUBS_INT_CONTEXT);
    return 0;
}

const CubsTypeContext CUBS_MAP_CONTEXT = {
    .sizeOfType = sizeof(CubsMap),
    .destructor = {.func = {.externC = &map_deinit}, .funcType = cubsFunctionPtrTypeC},
    .clone = {.func = {.externC = &map_clone}, .funcType = cubsFunctionPtrTypeC},
    .eql = {.func = {.externC = &map_eql}, .funcType = cubsFunctionPtrTypeC},
    .hash = {.func = {.externC = &map_hash}, .funcType = cubsFunctionPtrTypeC},
    .name = "map",
    .nameLength = 3,
    .members = NULL,
    .membersLen = 0,
};

#pragma endregion

#pragma region Option

static int option_deinit(CubsCFunctionHandler handler) {
    CubsOption self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_OPTION_CONTEXT);
    cubs_option_deinit(&self);
    return 0;
}

static int option_clone(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_OPTION_CONTEXT);
    CubsOption clone = cubs_option_clone((const CubsOption*)self.ref);
    cubs_function_return_set_value(handler, (void*)&clone, &CUBS_OPTION_CONTEXT); // explicitly const cast
    return 0;
}

static int option_eql(CubsCFunctionHandler handler) {
    CubsConstRef lhs;
    const CubsTypeContext* lhsContext;
    CubsConstRef rhs;
    const CubsTypeContext* rhsContext;

    cubs_function_take_arg(&handler, 0, (void*)&lhs, &lhsContext);
    cubs_function_take_arg(&handler, 1, (void*)&rhs, &rhsContext);

    assert(lhsContext == &CUBS_CONST_REF_CONTEXT || lhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(lhs.context == &CUBS_OPTION_CONTEXT);
    assert(rhsContext == &CUBS_CONST_REF_CONTEXT || rhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(rhs.context == &CUBS_OPTION_CONTEXT);

    bool result = cubs_option_eql((const CubsOption*)lhs.ref, (const CubsOption*)rhs.ref);
    cubs_function_return_set_value(handler, (void*)&result, &CUBS_BOOL_CONTEXT);
    return 0;
}

static int option_hash(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_OPTION_CONTEXT);
    size_t hashed = cubs_option_hash((const CubsOption*)self.ref);
    cubs_function_return_set_value(handler, (void*)&hashed, &CUBS_INT_CONTEXT);
    return 0;
}

const CubsTypeContext CUBS_OPTION_CONTEXT = {
    .sizeOfType = sizeof(CubsOption),
    .destructor = {.func = {.externC = &option_deinit}, .funcType = cubsFunctionPtrTypeC},
    .clone = {.func = {.externC = &option_clone}, .funcType = cubsFunctionPtrTypeC},
    .eql = {.func = {.externC = &option_eql}, .funcType = cubsFunctionPtrTypeC},
    .hash = {.func = {.externC = &option_hash}, .funcType = cubsFunctionPtrTypeC},
    .name = "option",
    .nameLength = 6,
    .members = NULL,
    .membersLen = 0,
};

#pragma endregion

#pragma region Error

static int error_deinit(CubsCFunctionHandler handler) {
    CubsError self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_ERROR_CONTEXT);
    cubs_error_deinit(&self);
    return 0;
}

static int error_clone(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_ERROR_CONTEXT);
    CubsError clone = cubs_error_clone((const CubsError*)self.ref);
    cubs_function_return_set_value(handler, (void*)&clone, &CUBS_ERROR_CONTEXT); // explicitly const cast
    return 0;
}

static int error_eql(CubsCFunctionHandler handler) {
    CubsConstRef lhs;
    const CubsTypeContext* lhsContext;
    CubsConstRef rhs;
    const CubsTypeContext* rhsContext;

    cubs_function_take_arg(&handler, 0, (void*)&lhs, &lhsContext);
    cubs_function_take_arg(&handler, 1, (void*)&rhs, &rhsContext);

    assert(lhsContext == &CUBS_CONST_REF_CONTEXT || lhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(lhs.context == &CUBS_ERROR_CONTEXT);
    assert(rhsContext == &CUBS_CONST_REF_CONTEXT || rhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(rhs.context == &CUBS_ERROR_CONTEXT);

    bool result = cubs_error_eql((const CubsError*)lhs.ref, (const CubsError*)rhs.ref);
    cubs_function_return_set_value(handler, (void*)&result, &CUBS_BOOL_CONTEXT);
    return 0;
}

static int error_hash(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_ERROR_CONTEXT);
    size_t hashed = cubs_error_hash((const CubsError*)self.ref);
    cubs_function_return_set_value(handler, (void*)&hashed, &CUBS_INT_CONTEXT);
    return 0;
}

const CubsTypeContext CUBS_ERROR_CONTEXT = {
    .sizeOfType = sizeof(CubsError),
    .destructor = {.func = {.externC = &error_deinit}, .funcType = cubsFunctionPtrTypeC},
    .clone = {.func = {.externC = &error_clone}, .funcType = cubsFunctionPtrTypeC},
    .eql = {.func = {.externC = &error_eql}, .funcType = cubsFunctionPtrTypeC},
    .hash = {.func = {.externC = &error_hash}, .funcType = cubsFunctionPtrTypeC},
    .name = "error",
    .nameLength = 5,
    .members = NULL,
    .membersLen = 0,
};

#pragma endregion

#pragma region Result

static int result_deinit(CubsCFunctionHandler handler) {
    CubsResult self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_RESULT_CONTEXT);
    cubs_result_deinit(&self);
    return 0;
}

const CubsTypeContext CUBS_RESULT_CONTEXT = {
    .sizeOfType = sizeof(CubsResult),
    .destructor = {.func = {.externC = &result_deinit}, .funcType = cubsFunctionPtrTypeC},
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "result",
    .nameLength = 6,
    .members = NULL,
    .membersLen = 0,
};

#pragma endregion

#pragma region Unique

static int unique_deinit(CubsCFunctionHandler handler) {
    CubsUnique self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_UNIQUE_CONTEXT);
    cubs_unique_deinit(&self);
    return 0;
}

const CubsTypeContext CUBS_UNIQUE_CONTEXT = {
    .sizeOfType = sizeof(CubsUnique),
    .destructor = {.func = {.externC = &unique_deinit}, .funcType = cubsFunctionPtrTypeC},
    .clone = {0},
    .eql = {0},
    .hash = {0},
    .name = "unique",
    .nameLength = 6,
    .members = NULL,
    .membersLen = 0,
};

#pragma endregion

#pragma region Shared

static int shared_deinit(CubsCFunctionHandler handler) {
    CubsShared self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_ERROR_CONTEXT);
    cubs_shared_deinit(&self);
    return 0;
}

static int shared_clone(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_ERROR_CONTEXT);
    CubsShared clone = cubs_shared_clone((const CubsShared*)self.ref);
    cubs_function_return_set_value(handler, (void*)&clone, &CUBS_SHARED_CONTEXT); // explicitly const cast
    return 0;
}

static int shared_eql(CubsCFunctionHandler handler) {
    CubsConstRef lhs;
    const CubsTypeContext* lhsContext;
    CubsConstRef rhs;
    const CubsTypeContext* rhsContext;

    cubs_function_take_arg(&handler, 0, (void*)&lhs, &lhsContext);
    cubs_function_take_arg(&handler, 1, (void*)&rhs, &rhsContext);

    assert(lhsContext == &CUBS_CONST_REF_CONTEXT || lhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(lhs.context == &CUBS_ERROR_CONTEXT);
    assert(rhsContext == &CUBS_CONST_REF_CONTEXT || rhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(rhs.context == &CUBS_ERROR_CONTEXT);

    bool result = cubs_shared_eql((const CubsShared*)lhs.ref, (const CubsShared*)rhs.ref);
    cubs_function_return_set_value(handler, (void*)&result, &CUBS_BOOL_CONTEXT);
    return 0;
}

const CubsTypeContext CUBS_SHARED_CONTEXT = {
    .sizeOfType = sizeof(CubsShared),
    .destructor = {.func = {.externC = &shared_deinit}, .funcType = cubsFunctionPtrTypeC},
    .clone = {.func = {.externC = &shared_clone}, .funcType = cubsFunctionPtrTypeC},
    .eql = {.func = {.externC = &shared_eql}, .funcType = cubsFunctionPtrTypeC},
    .hash = {0},
    .name = "shared",
    .nameLength = 6,
    .members = NULL,
    .membersLen = 0,
};

#pragma endregion

#pragma region Weak

static int weak_deinit(CubsCFunctionHandler handler) {
    CubsWeak self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_ERROR_CONTEXT);
    cubs_weak_deinit(&self);
    return 0;
}

static int weak_clone(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_ERROR_CONTEXT);
    CubsWeak clone = cubs_weak_clone((const CubsWeak*)self.ref);
    cubs_function_return_set_value(handler, (void*)&clone, &CUBS_WEAK_CONTEXT); // explicitly const cast
    return 0;
}

static int weak_eql(CubsCFunctionHandler handler) {
    CubsConstRef lhs;
    const CubsTypeContext* lhsContext;
    CubsConstRef rhs;
    const CubsTypeContext* rhsContext;

    cubs_function_take_arg(&handler, 0, (void*)&lhs, &lhsContext);
    cubs_function_take_arg(&handler, 1, (void*)&rhs, &rhsContext);

    assert(lhsContext == &CUBS_CONST_REF_CONTEXT || lhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(lhs.context == &CUBS_ERROR_CONTEXT);
    assert(rhsContext == &CUBS_CONST_REF_CONTEXT || rhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(rhs.context == &CUBS_ERROR_CONTEXT);

    bool result = cubs_weak_eql((const CubsWeak*)lhs.ref, (const CubsWeak*)rhs.ref);
    cubs_function_return_set_value(handler, (void*)&result, &CUBS_BOOL_CONTEXT);
    return 0;
}

const CubsTypeContext CUBS_WEAK_CONTEXT = {
    .sizeOfType = sizeof(CubsWeak),
    .destructor = {.func = {.externC = &weak_deinit}, .funcType = cubsFunctionPtrTypeC},
    .clone = {.func = {.externC = &weak_clone}, .funcType = cubsFunctionPtrTypeC},
    .eql = {.func = {.externC = &weak_eql}, .funcType = cubsFunctionPtrTypeC},
    .hash = {0},
    .name = "weak",
    .nameLength = 4,
    .members = NULL,
    .membersLen = 0,
};

#pragma endregion

#pragma region Function

static int function_clone(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT); 
    assert(self.context == &CUBS_FUNCTION_CONTEXT);
    CubsFunction clone = *(const CubsFunction*)self.ref;
    cubs_function_return_set_value(handler, (void*)&clone, &CUBS_FUNCTION_CONTEXT); // explicitly const cast
    return 0;
}

static int function_eql(CubsCFunctionHandler handler) {
    CubsConstRef lhs;
    const CubsTypeContext* lhsContext;
    CubsConstRef rhs;
    const CubsTypeContext* rhsContext;

    cubs_function_take_arg(&handler, 0, (void*)&lhs, &lhsContext);
    cubs_function_take_arg(&handler, 1, (void*)&rhs, &rhsContext);

    assert(lhsContext == &CUBS_CONST_REF_CONTEXT || lhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(lhs.context == &CUBS_FUNCTION_CONTEXT);
    assert(rhsContext == &CUBS_CONST_REF_CONTEXT || rhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(rhs.context == &CUBS_FUNCTION_CONTEXT);

    bool result = cubs_function_eql((const CubsFunction*)lhs.ref, (const CubsFunction*)rhs.ref);
    cubs_function_return_set_value(handler, (void*)&result, &CUBS_BOOL_CONTEXT);
    return 0;
}

static int function_hash(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_FUNCTION_CONTEXT);
    size_t hashed = cubs_function_hash((const CubsFunction*)self.ref);
    cubs_function_return_set_value(handler, (void*)&hashed, &CUBS_INT_CONTEXT);
    return 0;
}

const CubsTypeContext CUBS_FUNCTION_CONTEXT = {
    .sizeOfType = sizeof(CubsFunction),
    .destructor = {0}, 
    .clone = {.func = {.externC = &function_clone}, .funcType = cubsFunctionPtrTypeC},
    .eql = {.func = {.externC = &function_eql}, .funcType = cubsFunctionPtrTypeC},
    .hash = {.func = {.externC = &function_hash}, .funcType = cubsFunctionPtrTypeC},
    .name = "function",
    .nameLength = 8,
    .members = NULL,
    .membersLen = 0,
};

#pragma endregion

#pragma region ConstRef

// For the sake of consistency, pass reference types by reference

static int const_ref_clone(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT); 
    assert(self.context == &CUBS_CONST_REF_CONTEXT);
    CubsConstRef clone = *(const CubsConstRef*)self.ref;
    cubs_function_return_set_value(handler, (void*)&clone, &CUBS_CONST_REF_CONTEXT); // explicitly const cast
    return 0;
}

static int const_ref_eql(CubsCFunctionHandler handler) {
    CubsConstRef lhs;
    const CubsTypeContext* lhsContext;
    CubsConstRef rhs;
    const CubsTypeContext* rhsContext;

    cubs_function_take_arg(&handler, 0, (void*)&lhs, &lhsContext);
    cubs_function_take_arg(&handler, 1, (void*)&rhs, &rhsContext);

    assert(lhsContext == &CUBS_CONST_REF_CONTEXT || lhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(lhs.context == &CUBS_CONST_REF_CONTEXT);
    assert(rhsContext == &CUBS_CONST_REF_CONTEXT || rhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(rhs.context == &CUBS_CONST_REF_CONTEXT);

    bool result = cubs_const_ref_eql((const CubsConstRef*)lhs.ref, (const CubsConstRef*)rhs.ref);
    cubs_function_return_set_value(handler, (void*)&result, &CUBS_BOOL_CONTEXT);
    return 0;
}

static int const_ref_hash(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_CONST_REF_CONTEXT);
    size_t hashed = cubs_const_ref_hash((const CubsConstRef*)self.ref);
    cubs_function_return_set_value(handler, (void*)&hashed, &CUBS_INT_CONTEXT);
    return 0;
}

const CubsTypeContext CUBS_CONST_REF_CONTEXT = {
    .sizeOfType = sizeof(CubsConstRef),
    .destructor = {0}, 
    .clone = {.func = {.externC = &const_ref_clone}, .funcType = cubsFunctionPtrTypeC},
    .eql = {.func = {.externC = &const_ref_eql}, .funcType = cubsFunctionPtrTypeC},
    .hash = {.func = {.externC = &const_ref_hash}, .funcType = cubsFunctionPtrTypeC},
    .name = "const_ref",
    .nameLength = 9,
    .members = NULL,
    .membersLen = 0,
};

#pragma endregion

#pragma region MutRef

static int mut_ref_clone(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT); 
    assert(self.context == &CUBS_MUT_REF_CONTEXT);
    CubsMutRef clone = *(const CubsMutRef*)self.ref;
    cubs_function_return_set_value(handler, (void*)&clone, &CUBS_MUT_REF_CONTEXT); // explicitly const cast
    return 0;
}

static int mut_ref_eql(CubsCFunctionHandler handler) {
    CubsConstRef lhs;
    const CubsTypeContext* lhsContext;
    CubsConstRef rhs;
    const CubsTypeContext* rhsContext;

    cubs_function_take_arg(&handler, 0, (void*)&lhs, &lhsContext);
    cubs_function_take_arg(&handler, 1, (void*)&rhs, &rhsContext);

    assert(lhsContext == &CUBS_CONST_REF_CONTEXT || lhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(lhs.context == &CUBS_MUT_REF_CONTEXT);
    assert(rhsContext == &CUBS_CONST_REF_CONTEXT || rhsContext == &CUBS_MUT_REF_CONTEXT);
    assert(rhs.context == &CUBS_MUT_REF_CONTEXT);

    bool result = cubs_mut_ref_eql((const CubsMutRef*)lhs.ref, (const CubsMutRef*)rhs.ref);
    cubs_function_return_set_value(handler, (void*)&result, &CUBS_BOOL_CONTEXT);
    return 0;
}

static int mut_ref_hash(CubsCFunctionHandler handler) {
    CubsConstRef self;
    const CubsTypeContext* context;
    cubs_function_take_arg(&handler, 0, (void*)&self, &context);
    assert(context == &CUBS_CONST_REF_CONTEXT || context == &CUBS_MUT_REF_CONTEXT);
    assert(self.context == &CUBS_CONST_REF_CONTEXT);
    size_t hashed = cubs_mut_ref_hash((const CubsMutRef*)self.ref);
    cubs_function_return_set_value(handler, (void*)&hashed, &CUBS_INT_CONTEXT);
    return 0;
}

const CubsTypeContext CUBS_MUT_REF_CONTEXT = {
    .sizeOfType = sizeof(CubsMutRef),
    .destructor = {0}, 
    .clone = {.func = {.externC = &mut_ref_clone}, .funcType = cubsFunctionPtrTypeC},
    .eql = {.func = {.externC = &mut_ref_eql}, .funcType = cubsFunctionPtrTypeC},
    .hash = {.func = {.externC = &mut_ref_hash}, .funcType = cubsFunctionPtrTypeC},
    .name = "mut_ref",
    .nameLength = 7,
    .members = NULL,
    .membersLen = 0,
};

#pragma endregion

void cubs_context_fast_deinit(void *value, const CubsTypeContext *context)
{
    if(context->destructor.func.externC == NULL) { // works for script types too cause union
        return;
    }
    else if(context == &CUBS_STRING_CONTEXT) {
        cubs_string_deinit((CubsString*)value);
    } else if (context == &CUBS_ARRAY_CONTEXT) {
        cubs_array_deinit((CubsArray*)value);
    } else if(context == &CUBS_SET_CONTEXT) {
        cubs_set_deinit((CubsSet*)value);
    } else if (context == &CUBS_MAP_CONTEXT) {
        cubs_map_deinit((CubsMap*)value);
    } else if (context == &CUBS_OPTION_CONTEXT) {
        cubs_option_deinit((CubsOption*)value);
    } else if(context == &CUBS_ERROR_CONTEXT) {
        cubs_error_deinit((CubsError*)value);
    } else if (context == &CUBS_RESULT_CONTEXT) {
        cubs_result_deinit((CubsResult*)value);
    }  else if (context == &CUBS_UNIQUE_CONTEXT) {
        cubs_unique_deinit((CubsUnique*)value);
    } else if(context == &CUBS_SHARED_CONTEXT) {
        cubs_shared_deinit((CubsShared*)value);
    } else if (context == &CUBS_WEAK_CONTEXT) {
        cubs_weak_deinit((CubsWeak*)value);
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
    if(context == &CUBS_BOOL_CONTEXT) {
        *(bool*)out = *(const bool*)value;
    } else if(context == &CUBS_INT_CONTEXT) {
        *(int64_t*)out = *(const int64_t*)value;
    } else if(context == &CUBS_FLOAT_CONTEXT) {
        *(double*)out = *(const double*)value;
    } else if(context == &CUBS_CHAR_CONTEXT) {
        *(CubsChar*)out = *(const CubsChar*)value;
    } else if(context == &CUBS_STRING_CONTEXT) {
        const CubsString ret = cubs_string_clone((const CubsString*)value);
        *(CubsString*)out = ret;
    } else if(context == &CUBS_ARRAY_CONTEXT) {
        const CubsArray ret = cubs_array_clone((const CubsArray*)value);
        *(CubsArray*)out = ret;
    } else if(context == &CUBS_SET_CONTEXT) {
        const CubsSet ret = cubs_set_clone((const CubsSet*)value);
        *(CubsSet*)out = ret;
    } else if(context == &CUBS_MAP_CONTEXT) {
        const CubsMap ret = cubs_map_clone((const CubsMap*)value);
        *(CubsMap*)out = ret;
    } else if(context == &CUBS_OPTION_CONTEXT) {
        const CubsOption ret = cubs_option_clone((const CubsOption*)value);
        *(CubsOption*)out = ret;
    } else if(context == &CUBS_ERROR_CONTEXT) {
        const CubsError ret = cubs_error_clone((const CubsError*)value);
        *(CubsError*)out = ret;
    // TODO result clone?
    } else if(context == &CUBS_SHARED_CONTEXT) {
        const CubsShared ret = cubs_shared_clone((const CubsShared*)value);
        *(CubsShared*)out = ret;
    } else if(context == &CUBS_WEAK_CONTEXT) {
        const CubsWeak ret = cubs_weak_clone((const CubsWeak*)value);
        *(CubsWeak*)out = ret;
    } else if(context == &CUBS_FUNCTION_CONTEXT) {
        const CubsFunction ret = *(const CubsFunction*)value;
        *(CubsFunction*)out = ret;
    } else if(context == &CUBS_CONST_REF_CONTEXT) {
        const CubsConstRef ret = *(const CubsConstRef*)value;
        *(CubsConstRef*)out = ret;
    } else if(context == &CUBS_MUT_REF_CONTEXT) {
        const CubsMutRef ret = *(const CubsMutRef*)value;
        *(CubsMutRef*)out = ret;
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
    if(context == &CUBS_BOOL_CONTEXT) {
        return (*(const bool*)lhs) == (*(const bool*)rhs);
    } else if(context == &CUBS_INT_CONTEXT) {
        return (*(const int64_t*)lhs) == (*(const int64_t*)rhs);
    } else if(context == &CUBS_FLOAT_CONTEXT) {
        return (*(const double*)lhs) == (*(const double*)rhs);
    } else if(context == &CUBS_CHAR_CONTEXT) {
        return (*(const CubsChar*)lhs) == (*(const CubsChar*)rhs);
    } else if(context == &CUBS_STRING_CONTEXT) {
        return cubs_string_eql((const CubsString*)lhs, (const CubsString*)rhs);
    } else if(context == &CUBS_ARRAY_CONTEXT) {
        return cubs_array_eql((const CubsArray*)lhs, (const CubsArray*)rhs);
    } else if(context == &CUBS_SET_CONTEXT) {
        return cubs_set_eql((const CubsSet*)lhs, (const CubsSet*)rhs);
    } else if(context == &CUBS_MAP_CONTEXT) {
        return cubs_map_eql((const CubsMap*)lhs, (const CubsMap*)rhs);
    } else if(context == &CUBS_OPTION_CONTEXT) {
        return cubs_option_eql((const CubsOption*)lhs, (const CubsOption*)rhs);
    } else if(context == &CUBS_ERROR_CONTEXT) {
        return cubs_error_eql((const CubsError*)lhs, (const CubsError*)rhs);
    } else if(context == &CUBS_SHARED_CONTEXT) {
        return cubs_shared_eql((const CubsShared*)lhs, (const CubsShared*)rhs);
    } else if(context == &CUBS_WEAK_CONTEXT) {
        return cubs_weak_eql((const CubsWeak*)lhs, (const CubsWeak*)rhs);
    } else if(context == &CUBS_WEAK_CONTEXT) {
        return cubs_function_eql((const CubsFunction*)lhs, (const CubsFunction*)rhs);
    } else if(context == &CUBS_CONST_REF_CONTEXT) {
        return cubs_const_ref_eql((const CubsConstRef*)lhs, (const CubsConstRef*)rhs);
    } else if(context == &CUBS_MUT_REF_CONTEXT) {
        return cubs_mut_ref_eql((const CubsMutRef*)lhs, (const CubsMutRef*)rhs);
    } else {
        CubsFunctionCallArgs args = cubs_function_start_call(&context->eql);

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
    if(context == &CUBS_BOOL_CONTEXT) {
        return (size_t)(*(const bool*)value);
    } else if(context == &CUBS_INT_CONTEXT) {
        return (size_t)(*(const int64_t*)value);
    } else if(context == &CUBS_FLOAT_CONTEXT) {
        return (size_t)(int64_t)(*(const double*)value);
    } else if(context == &CUBS_CHAR_CONTEXT) {
        return (size_t)(int64_t)(*(const CubsChar*)value);
    } else if(context == &CUBS_STRING_CONTEXT) {
        return cubs_string_hash((const CubsString*)value);
    } else if(context == &CUBS_SET_CONTEXT) {
        return cubs_set_hash((const CubsSet*)value);
    } else if(context == &CUBS_MAP_CONTEXT) {
        return cubs_map_hash((const CubsMap*)value);
    } else if(context == &CUBS_OPTION_CONTEXT) {
        return cubs_option_hash((const CubsOption*)value);
    } else if(context == &CUBS_ERROR_CONTEXT) {
        return cubs_error_hash((const CubsError*)value);
    } else if(context == &CUBS_FUNCTION_CONTEXT) {
        return cubs_function_hash((const CubsFunction*)value);
    } else if(context == &CUBS_CONST_REF_CONTEXT) {
        return cubs_const_ref_hash((const CubsConstRef*)value);
    } else if(context == &CUBS_MUT_REF_CONTEXT) {
        return cubs_mut_ref_hash((const CubsMutRef*)value);
    } else {
        CubsFunctionCallArgs args = cubs_function_start_call(&context->hash);

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
