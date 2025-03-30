#include "parse_statements.h"
#include "tokenizer.h"
#include <assert.h>
#include "../ast.h"
#include "../ast_nodes/return_node.h"
#include "../ast_nodes/variable_declaration.h"
#include "../ast_nodes/variable_assignment.h"
#include "../ast_nodes/conditional_node.h"
#include "../ast_nodes/function_call.h"
#include "../ast_nodes/member_assign.h"
#include "../stack_variables.h"
#include "../graph/function_dependency_graph.h"
#include "../graph/scope.h"
#include <stdio.h>

bool parse_next_statement(AstNode *outNode, TokenIter *iter, StackVariablesArray *variables, FunctionDependencies* dependencies, Scope* outerScope)
{
    TokenType token = cubs_token_iter_next(iter);
    if(token != RIGHT_BRACE_SYMBOL) {
        assert(token != TOKEN_NONE);

        switch(token) {
            case RETURN_KEYWORD: {
                AstNode returnNode = cubs_return_node_init(iter, variables, dependencies);
                *outNode = returnNode;
            } break;

            case CONST_KEYWORD: // fallthrough
            case MUT_KEYWORD: {
                AstNode variableDeclarationNode = cubs_variable_declaration_node_init(iter, variables, dependencies);
                *outNode = variableDeclarationNode;
            } break;

            case IF_KEYWORD: {
                AstNode conditionalNode = cubs_conditional_node_init(iter, variables, dependencies, outerScope);
                *outNode = conditionalNode;
            } break;

            case IDENTIFIER: {
                const TokenType afterIdentifier = cubs_token_iter_peek(iter);
                if(afterIdentifier == LEFT_PARENTHESES_SYMBOL) {
                    const CubsStringSlice functionName = iter->current.value.identifier;
                    (void)cubs_token_iter_next(iter);
                    AstNode callNode = cubs_function_call_node_init(functionName, false, 0, iter, variables, dependencies);
                    *outNode = callNode;
                    (void)cubs_token_iter_next(iter);
                    assert(iter->current.tag == SEMICOLON_SYMBOL); // TODO handle chaining function calls
                } else if(afterIdentifier == ASSIGN_OPERATOR) {
                    AstNode variableAssign = cubs_variable_assignment_node_init(iter, variables, dependencies);
                    *outNode = variableAssign;
                } else if(afterIdentifier == PERIOD_SYMBOL) {
                    // TODO member function calls
                    AstNode memberAssign = cubs_member_assign_node_init(iter, variables, dependencies);
                    *outNode = memberAssign;
                } else {
                    assert(false && "Unknown token after identifier at start of statement");
                }
            } break;

            default: {
                fprintf(stderr, "Invalid token: %d\n", token);
                assert(false && "Invalid token in statements");
            } break;
        }
        return true;
    } else {
        return false;
    }
}