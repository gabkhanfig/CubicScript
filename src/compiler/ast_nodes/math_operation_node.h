#pragma once

#include "../../c_basic_types.h"
#include "../ast.h"

union MathValueMetadata {
    /// Index within the stack variables to find the name of the variable
    size_t variableIndex;
    int64_t intLiteral;
    double floatLiteral;
};

/// Corresponds with `MathValueMetadata`
enum MathValueType {
    Variable,
    IntLit,
    FloatLit,
};

/// Tagged union
typedef struct MathValue {
    MathValueType tag;
    MathValueMetadata value;
} MathValue;

typedef enum MathOp {
    Add,
} MathOp;

