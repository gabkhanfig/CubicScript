#include "expression_value.h"
#include "../stack_variables.h"
#include "../../platform/mem.h"
#include "../../interpreter/function_definition.h"
#include "binary_expression.h"
#include <stdio.h>
#include "../../program/program_internal.h"

/// Steps the iterator forward to after the value.
static ExprValue parse_expression_value(TokenIter* iter, StackVariablesArray* variables) {
    // TODO nested expressions

    //(void)cubs_token_iter_next(iter);
    const Token token = iter->current;

    assert(token.tag != SEMICOLON_SYMBOL);

    ExprValue value = {0};

    switch(token.tag) {
        case TRUE_KEYWORD: 
        case FALSE_KEYWORD: {
            const CubsString variableName = cubs_string_init_unchecked((CubsStringSlice){.str = "_tmpBoolLit", .len = 11});

            StackVariableInfo temporaryVariable = {
                .name = variableName,
                .isTemporary = true,
                .isMutable = false,
                .typeInfo = cubs_type_resolution_info_from_context(&CUBS_BOOL_CONTEXT),
            };

            value.tag = BoolLit;
            value.value.boolLiteral.literal = token.tag == TRUE_KEYWORD; // If "true", then true literal, otherwise false literal
            value.value.intLiteral.variableIndex = variables->len;
            cubs_stack_variables_array_push_temporary(variables, temporaryVariable);
        } break;
        case INT_LITERAL: {
            const CubsString variableName = cubs_string_init_unchecked((CubsStringSlice){.str = "_tmpIntLit", .len = 10});
            
            StackVariableInfo temporaryVariable = {
                .name = variableName,
                .isTemporary = true,
                .isMutable = false,
                .typeInfo = cubs_type_resolution_info_from_context(&CUBS_INT_CONTEXT),
            };

            value.tag = IntLit;
            value.value.intLiteral.literal = token.value.intLiteral;
            // Variable order is preserved
            value.value.intLiteral.variableIndex = variables->len;

            // variables->len will be increased by 1
            cubs_stack_variables_array_push_temporary(variables, temporaryVariable);
        } break;
        case FLOAT_LITERAL: {
            const CubsString variableName = cubs_string_init_unchecked((CubsStringSlice){.str = "_tmpFloatLit", .len = 12});
            
            StackVariableInfo temporaryVariable = {
                .name = variableName,
                .isTemporary = true,
                .isMutable = false,
                .typeInfo = cubs_type_resolution_info_from_context(&CUBS_FLOAT_CONTEXT),
            };

            value.tag = FloatLit;
            value.value.floatLiteral.literal = token.value.floatLiteral;
            // Variable order is preserved
            value.value.floatLiteral.variableIndex = variables->len;

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

    if(tokenAfterFirst == RIGHT_PARENTHESES_SYMBOL) {
        return firstValue;
    }

    if(tokenAfterFirst == LEFT_PARENTHESES_SYMBOL) {
        assert(false && "Cannot currently handle function calls");
    }

    if(is_token_operator(tokenAfterFirst)) {
        switch(tokenAfterFirst) {
            case EQUAL_OPERATOR:
            case ADD_OPERATOR: {
                size_t outSrc;
                if(hasDestination) {
                    outSrc = destinationVariableIndex;
                } else {
                    const CubsString variableName = cubs_string_init_unchecked((CubsStringSlice){.str = "_tmpBinExprOut", .len = 14});
                    
                    StackVariableInfo temporaryVariable = {
                        .name = variableName,
                        .isTemporary = true,
                        .isMutable = false,
                        .typeInfo = {0},
                    };
                    if(tokenAfterFirst == EQUAL_OPERATOR) {
                        temporaryVariable.typeInfo = cubs_type_resolution_info_from_context(&CUBS_BOOL_CONTEXT);
                    } else if(tokenAfterFirst == ADD_OPERATOR) {
                        temporaryVariable.typeInfo = cubs_type_resolution_info_from_context(&CUBS_INT_CONTEXT);
                    }
                    // order is preserved
                    outSrc = variables->len;
                    // variables->len will be increased by 1
                    cubs_stack_variables_array_push_temporary(variables, temporaryVariable);
                }
                (void)cubs_token_iter_next(iter); // step to next

                BinaryExprOp binaryExpressionOperator;
                if(tokenAfterFirst == EQUAL_OPERATOR) {
                    binaryExpressionOperator = Equal;
                } else if(tokenAfterFirst == ADD_OPERATOR) {
                    binaryExpressionOperator = Add;
                }
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
            } break;
            default: {
                cubs_panic("Unexpected token in expresson");
            }
        }
    }

    // TODO handle other expressions such as binary expression
    assert(false && "TODO handle other expressions");
    return firstValue;
}

const CubsTypeContext *cubs_expr_node_resolve_type(ExprValue *self, CubsProgram *program, const FunctionBuilder* builder, StackVariablesArray *variables)
{
    switch(self->tag) {
        case BoolLit: {
            TypeResolutionInfo* typeInfo = &variables->variables[self->value.boolLiteral.variableIndex].typeInfo;
            assert(typeInfo->knownContext == &CUBS_BOOL_CONTEXT);
            return &CUBS_BOOL_CONTEXT;
        } break;
        case IntLit: {
            TypeResolutionInfo* typeInfo = &variables->variables[self->value.intLiteral.variableIndex].typeInfo;
            assert(typeInfo->knownContext == &CUBS_INT_CONTEXT);
            return &CUBS_INT_CONTEXT;
        } break;
        case FloatLit: {
            TypeResolutionInfo* typeInfo = &variables->variables[self->value.floatLiteral.variableIndex].typeInfo;
            assert(typeInfo->knownContext == &CUBS_FLOAT_CONTEXT);
            return &CUBS_FLOAT_CONTEXT;
        } break;
        case Variable: {
            TypeResolutionInfo* typeInfo = &variables->variables[self->value.variableIndex].typeInfo;
            if(typeInfo->knownContext == NULL) {
                const CubsStringSlice typeName = typeInfo->typeName;
                const CubsTypeContext* argContext = cubs_program_find_type_context(program, typeName);
                assert(argContext != NULL);
                typeInfo->knownContext = argContext;
            }
            return typeInfo->knownContext;
        } break;
        case Expression: {
            AstNode* exprNode = &self->value.expression;
            ast_node_resolve_types(exprNode, program, builder, variables);
            
            assert(exprNode->vtable->nodeType == astNodeBinaryExpression);
            const size_t index = ((const BinaryExprNode*)exprNode->ptr)->outputVariableIndex;            
            const TypeResolutionInfo* typeInfo = &variables->variables[index].typeInfo;
            assert(typeInfo->knownContext != NULL);
            return typeInfo->knownContext;
        } break;
        case FunctionCall: {
            cubs_panic("Cannot yet handle function call expression type resolution");
        } break;
    }
}
