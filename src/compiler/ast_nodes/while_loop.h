#pragma once
#ifndef WHILE_LOOP_H
#define WHILE_LOOP_H

#include "../../c_basic_types.h"
#include "expression_value.h"
#include "ast_node_array.h"

struct AstNode;
struct TokenIter;
struct StackVariablesArray;
struct FunctionDependencies;
struct Scope;

typedef struct WhileLoopNode {
    /// The loop condition to be checked at the beginning of every loop iteration
    ExprValue condition;
    AstNodeArray statements;
    struct Scope* scope;
} WhileLoopNode;

struct AstNode cubs_while_loop_node_init(
    struct TokenIter* iter,
    struct StackVariablesArray* variables,
    struct FunctionDependencies* dependencies,
    struct Scope* outerScope
);

#endif
