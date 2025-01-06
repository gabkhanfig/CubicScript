#include "expression_value.h"
#include "../stack_variables.h"
#include "../../platform/mem.h"
#include "../../interpreter/function_definition.h"

bool cubs_parse_expression(
    ExprValue* out,
    TokenIter* iter, 
    struct StackVariablesArray* variables, 
    bool hasDestination, 
    size_t destinationVariableIndex
) {
    const TokenType firstToken = cubs_token_iter_next(iter);
    // If the expression is just ";", for now return zeroed integer
    // TODO handle true empty value
    if(firstToken == SEMICOLON_SYMBOL) {
        return false;
    }

    switch(firstToken) {
        case INT_LITERAL: {

            ExprValue value = {0};
            value.tag = IntLit;
            value.value.intLiteral = iter->current.value.intLiteral;
            *out = value;
        } break;
        default: {
            assert(false && "Cannot handle anything other than int literals");
        } break;
    }

    // TODO handle other expressions such as binary expression

    const TokenType mustBeSemicolon = cubs_token_iter_next(iter);
    assert(mustBeSemicolon == SEMICOLON_SYMBOL && "Expected semicolon to follow variable initial value");
}