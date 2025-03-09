#ifndef MEMBER_ASSIGN_H
#define MEMBER_ASSIGN_H

#include <stddef.h>
#include <stdint.h>
#include "expression_value.h"

struct TokenIter;
struct StackVariablesArray;
struct CubsStringSlice;
struct FunctionDependencies;

typedef struct MemberAssignNode {
    size_t variableIndex;
    bool updatingReference;
    /// Only used if `updatingReference` is true.
    size_t refVariableIndex;
    ExprValue newValue;
    /// Array of nested member names. Is length `len`.
    /// `variable.member1.member2.member3` for example, where the array
    /// contains the names of those members.
    struct CubsStringSlice* members;
    /// Array of struct member access destination variables.
    /// The final one is the resulting destination for the entire expression.
    size_t* destinations;
    uint16_t* memberIndices;
    size_t len;
} MemberAssignNode;

struct AstNode cubs_member_assign_node_init(
    struct TokenIter* iter,
    struct StackVariablesArray* variables,
    struct FunctionDependencies* dependencies
);

#endif