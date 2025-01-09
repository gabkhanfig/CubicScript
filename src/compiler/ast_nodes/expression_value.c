#include "expression_value.h"
#include "../stack_variables.h"
#include "../../platform/mem.h"
#include "../../interpreter/function_definition.h"

/// Steps the iterator forward to after the value.
static ExprValue parse_expression_value(TokenIter* iter, StackVariablesArray* variables) {
    (void)cubs_token_iter_next(iter);
    const Token token = iter->current;

    assert(token.tag != SEMICOLON_SYMBOL);

    ExprValue value = {0};

    switch(token.tag) {
        case INT_LITERAL: {
            value.tag = IntLit;
            value.value.intLiteral = token.value.intLiteral;
        } break;
        case IDENTIFIER: {
            // TODO handle other kinds of identifiers such as structs function pointers
            const CubsStringSlice identifier = iter->current.value.identifier;
            value.tag = Variable;
            const bool didFind = cubs_stack_variables_array_find(
                variables, &value.value.variableIndex, identifier);
            assert(didFind && "Did not find stack variable");     
        } break;
        default: {
            assert(false && "Cannot handle anything other than int literals and variables by identifiers");
        } break;
    }

    (void)cubs_token_iter_next(iter);

    return value;
}

ExprValue cubs_parse_expression(
    TokenIter* iter, 
    StackVariablesArray* variables, 
    bool hasDestination, 
    size_t destinationVariableIndex
) {
    const ExprValue firstValue = parse_expression_value(iter, variables);
    
    const TokenType tokenAfterFirst = iter->current.tag;
    // Means first token is the only one in the expression
    if(tokenAfterFirst == SEMICOLON_SYMBOL) {
        return firstValue;
    }

    if(tokenAfterFirst == LEFT_PARENTHESES_SYMBOL) {
        assert(false && "Cannot currently handle function calls");
    }

    // TODO handle other expressions such as binary expression
    assert(false && "TODO handle other expressions");
    return firstValue;
}