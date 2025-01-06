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

    ExprValue value = {0};

    switch(firstToken) {
        case INT_LITERAL: {
            value.tag = IntLit;
            value.value.intLiteral = iter->current.value.intLiteral;
        } break;
        default: {
            assert(false && "Cannot handle anything other than int literals");
        } break;
    }

    // TODO handle other expressions such as binary expression

    const TokenType mustBeSemicolon = cubs_token_iter_next(iter);
    assert(mustBeSemicolon == SEMICOLON_SYMBOL && "Expected semicolon to follow variable initial value");
    return value;
}