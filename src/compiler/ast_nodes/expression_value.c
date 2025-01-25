#include "expression_value.h"
#include "../stack_variables.h"
#include "../../platform/mem.h"
#include "../../interpreter/function_definition.h"
#include "binary_expression.h"
#include <stdio.h>

/// Steps the iterator forward to after the value.
static ExprValue parse_expression_value(TokenIter* iter, StackVariablesArray* variables) {
    // TODO nested expressions

    //(void)cubs_token_iter_next(iter);
    const Token token = iter->current;

    assert(token.tag != SEMICOLON_SYMBOL);

    ExprValue value = {0};

    switch(token.tag) {
        case INT_LITERAL: {
                const CubsString variableName = cubs_string_init_unchecked((CubsStringSlice){.str = "_tmpIntLit", .len = 10});
            
                StackVariableInfo temporaryVariable = {
                    .name = variableName,
                    .isTemporary = true,
                    .typeInfo = cubs_type_resolution_info_from_context(&CUBS_INT_CONTEXT),
                };

                value.tag = IntLit;
                value.value.intLiteral.literal = token.value.intLiteral;
                // Variable order is preserved
                value.value.intLiteral.variableIndex = variables->len;

                // variables->len will be increased by 1
                cubs_stack_variables_array_push_temporary(variables, temporaryVariable);
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
            fprintf(stderr, "%d hmm\n", token.tag);
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

    if(is_token_operator(tokenAfterFirst)) {
        assert(tokenAfterFirst == ADD_OPERATOR);

        size_t outSrc;
        if(hasDestination) {
            outSrc = destinationVariableIndex;
        } else {
            const CubsString variableName = cubs_string_init_unchecked((CubsStringSlice){.str = "_tmpBinExprOut", .len = 14});
            
            StackVariableInfo temporaryVariable = {
                .name = variableName,
                .isTemporary = true,
                .typeInfo = cubs_type_resolution_info_from_context(&CUBS_INT_CONTEXT),
            };
            // order is preserved
            outSrc = variables->len;
            // variables->len will be increased by 1
            cubs_stack_variables_array_push_temporary(variables, temporaryVariable);
        }
        (void)cubs_token_iter_next(iter); // step to next

        const BinaryExprOp binaryExpressionOperator = Add;
        const ExprValue secondValue = parse_expression_value(iter, variables);

        ExprValue outValue = {0};
        outValue.tag = Expression;
        outValue.value.expression = cubs_binary_expr_node_init(
            variables, 
            outSrc, 
            binaryExpressionOperator, 
            firstValue, 
            secondValue
        );

        return outValue;
    }

    // TODO handle other expressions such as binary expression
    assert(false && "TODO handle other expressions");
    return firstValue;
}