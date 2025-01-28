#ifndef PARSE_STATEMENTS_H
#define PARSE_STATEMENTS_H

#include "../tokenizer.h"
#include <assert.h>
#include "../ast.h"
#include "return_node.h"
#include "variable_declaration.h"

/// Parses the next statement in the iterator.
/// @return true if a statement was parsed, false if the end of the statements
/// was reached, at the `}` character.
inline static bool parse_next_statement(AstNode* outNode, TokenIter* iter, StackVariablesArray* variables) {
    TokenType token = cubs_token_iter_next(iter);
    if(token != RIGHT_BRACE_SYMBOL) {
        assert(token != TOKEN_NONE);

        switch(token) {
            case RETURN_KEYWORD: {
                AstNode returnNode = cubs_return_node_init(iter, variables);
                *outNode = returnNode;
            } break;

            case CONST_KEYWORD: // fallthrough
            case MUT_KEYWORD: {
                AstNode variableDeclarationNode = cubs_variable_declaration_node_init(iter, variables);
                *outNode = variableDeclarationNode;
            } break;

            default: {
                assert(false && "Invalid token in statements");
            } break;
        }
        return true;
    } else {
        return false;
    }
}

#endif