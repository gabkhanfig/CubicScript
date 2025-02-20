#ifndef PARSE_STATEMENTS_H
#define PARSE_STATEMENTS_H

#include <stdbool.h>

struct AstNode;
struct TokenIter;
struct StackVariablesArray;
struct FunctionDependencies;

/// Parses the next statement in the iterator.
/// @return true if a statement was parsed, false if the end of the statements
/// was reached, at the `}` character.
bool parse_next_statement(
    struct AstNode* outNode, 
    struct TokenIter* iter, 
    struct StackVariablesArray* variables, 
    struct FunctionDependencies* dependencies
);

#endif