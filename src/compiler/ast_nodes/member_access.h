#ifndef MEMBER_ACCESS_H
#define MEMBER_ACCESS_H

#include "../../primitives/string/string_slice.h"
#include <stddef.h>

struct TokenIter;
struct StackVariablesArray;
struct CubsTypeContext;

typedef struct MemberAccessNode {
    size_t sourceVariableIndex;
    /// Array of nested member names. Is length `len`.
    /// `variable.member1.member2.member3` for example, where the array
    /// contains the names of those members.
    CubsStringSlice* members;
    /// Array of struct member access destination variables.
    /// The final one is the resulting destination for the entire expression.
    size_t* destinations;
    uint16_t* memberIndices;
    size_t len;
} MemberAccessNode;

struct AstNode cubs_member_access_node_init(
    struct TokenIter* iter,
    struct StackVariablesArray* variables//,
    //struct FunctionDependencies* dependencies
);

#endif