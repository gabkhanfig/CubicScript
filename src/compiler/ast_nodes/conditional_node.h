#ifndef CONDITIONAL_NODE_H
#define CONDITIONAL_NODE_H

#include <stddef.h>

struct ExprValue;
struct AstNodeArray;
struct AstNode;
struct TokenIter;
struct StackVariablesArray;

// TODO switch statement
/// If/else for now.
typedef struct ConditionalNode {
    /// Conditions for each `if / else if` branch
    struct ExprValue* conditions;
    /// With an `else` branch, will be `blocksLen - 1`, otherwise is equal 
    /// to `blocksLen`.
    size_t conditionsLen;
    /// Statements within each branch, including optionally 1 extra for an
    /// `else` branch.
    struct AstNodeArray* statementBlocks;
    size_t blocksLen;
    /// The max capacity of BOTH `conditions` and `statementBlocks`.
    size_t capacity;
} ConditionalNode;

AstNode cubs_conditional_node_init(struct TokenIter* iter, struct StackVariablesArray* variables);

#endif