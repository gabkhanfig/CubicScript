#include "expression_value.h"
#include "../stack_variables.h"
#include "../../platform/mem.h"
#include "../../interpreter/function_definition.h"

ExprValue cubs_parse_expression(
    TokenIter* iter, 
    struct StackVariablesArray* variables, 
    bool hasDestination, 
    size_t destinationVariableIndex
) {
    const TokenType firstToken = cubs_token_iter_next(iter);
    // If the expression is just ";", for now return zeroed integer
    // TODO handle true empty value
    assert(firstToken != SEMICOLON_SYMBOL);

    ExprValue firstValue = {0};

    switch(firstToken) {
        case INT_LITERAL: {
            firstValue.tag = IntLit;
            firstValue.value.intLiteral = iter->current.value.intLiteral;
        } break;
        default: {
            assert(false && "Cannot handle anything other than int literals");
        } break;
    }

    
    const TokenType tokenAfterFirst = cubs_token_iter_next(iter);
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