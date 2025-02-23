#include "expression_value.h"
#include "../stack_variables.h"
#include "../../platform/mem.h"
#include "../../interpreter/function_definition.h"
#include "binary_expression.h"
#include "function_call.h"
#include <stdio.h>
#include "../../interpreter/interpreter.h"
#include "../../interpreter/operations.h"
#include "../../program/program.h"
#include "../../program/program_internal.h"
#include "../graph/function_dependency_graph.h"

// struct ParsedExprValue;

// typedef struct {

// } ;

// enum ParsedExprValueTag {
//     ParsedVariableName,
//     ParsedBoolLiteral,
//     ParsedIntLiteral,
//     ParsedFloatLiteral,
//     ParsedFunctionName,
// };

// union ParsedExprValueMetadata {
//     CubsStringSlice variableName;
//     bool boolLit;
//     int64_t intLit;
//     double floatLit;
//     CubsStringSlice functionName;
// };

// /// 
// typedef struct ParsedExprValue {
//     enum ParsedExprValueTag tag;
//     union ParsedExprValueMetadata value;
// } ParsedExprValue;

/// Steps the iterator forward to after the value.
static ExprValue parse_expression_value(
    TokenIter* iter,
    StackVariablesArray* variables,
    FunctionDependencies* dependencies
    // bool hasDestination,
    // size_t destinationVariableIndex
) {
    // TODO nested expressions

    //(void)cubs_token_iter_next(iter);
    const Token token = iter->current;

    assert(token.tag != SEMICOLON_SYMBOL || token.tag != COMMA_SYMBOL);

    ExprValue value = {0};

    switch(token.tag) {
        case TRUE_KEYWORD: 
        case FALSE_KEYWORD: {
            const CubsString variableName = cubs_string_init_unchecked((CubsStringSlice){.str = "_tmpBoolLit", .len = 11});

            StackVariableInfo temporaryVariable = {
                .name = variableName,
                .isTemporary = true,
                .isMutable = false,
                //.typeInfo = cubs_type_resolution_info_from_context(&CUBS_BOOL_CONTEXT),
                .typeInfo = (TypeResolutionInfo){.tag = TypeInfoBool, .value._bool = NULL},
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
                //.typeInfo = cubs_type_resolution_info_from_context(&CUBS_INT_CONTEXT),
                .typeInfo = (TypeResolutionInfo){.tag = TypeInfoInt, .value._int = NULL},
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
                //.typeInfo = cubs_type_resolution_info_from_context(&CUBS_FLOAT_CONTEXT),   
                .typeInfo = (TypeResolutionInfo){.tag = TypeInfoFloat, .value._float = NULL},
            };

            value.tag = FloatLit;
            value.value.floatLiteral.literal = token.value.floatLiteral;
            // Variable order is preserved
            value.value.floatLiteral.variableIndex = variables->len;

            // variables->len will be increased by 1
            cubs_stack_variables_array_push_temporary(variables, temporaryVariable);
        } break;
        case IDENTIFIER: {
            const CubsStringSlice identifier = iter->current.value.identifier;
            const TokenType afterIdentifier = cubs_token_iter_peek(iter);
            // TODO function pointers
            if(afterIdentifier == LEFT_PARENTHESES_SYMBOL) {
                (void)cubs_token_iter_next(iter);

                const CubsString variableName = cubs_string_init_unchecked((CubsStringSlice){.str = "_tmpFnRet", .len = 9});
            
                StackVariableInfo temporaryVariable = {
                    .name = variableName,
                    .isTemporary = true,
                    .isMutable = false,
                    //.typeInfo = NULL,          
                    .typeInfo = (TypeResolutionInfo){.tag = TypeInfoUnknown, .value._unknown = NULL},
                };

                const size_t retVariableIndex = variables->len;

                // variables->len will be increased by 1
                cubs_stack_variables_array_push_temporary(variables, temporaryVariable);

                const AstNode callNode = cubs_function_call_node_init(
                    identifier, true, retVariableIndex, iter, variables, dependencies);

                value.tag = FunctionCall;
                value.value.functionCall = callNode;
            } else {
                // TODO handle other kinds of identifiers such as structs?
                value.tag = Variable;
                const bool didFind = cubs_stack_variables_array_find(
                    variables, &value.value.variableIndex, identifier);
                assert(didFind && "Did not find stack variable"); 
            }        
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
    FunctionDependencies* dependencies,
    bool hasDestination,
    size_t destinationVariableIndex
) {
    ExprValue firstValue = parse_expression_value(
        iter, variables, dependencies);
    
    const TokenType tokenAfterFirst = iter->current.tag;

    if(firstValue.tag == FunctionCall && hasDestination) {
        // Override the return variable index.
        // TODO figure out more optimal way to do this to avoid many unused temporaries
        AstNode functionCallNode = firstValue.value.functionCall;
        assert(functionCallNode.vtable->nodeType == astNodeTypeFunctionCall);

        FunctionCallNode* obj = (FunctionCallNode*)functionCallNode.ptr;
        obj->hasReturnVariable = hasDestination;
        obj->returnVariable = destinationVariableIndex;
    }

    // Means first token is the only one in the expression
    if(tokenAfterFirst == SEMICOLON_SYMBOL || tokenAfterFirst == COMMA_SYMBOL) {
        return firstValue;
    }

    if(tokenAfterFirst == RIGHT_PARENTHESES_SYMBOL) {
        // Used for syntax such as:
        // if (value)
        return firstValue;
    }

    if(tokenAfterFirst == LEFT_PARENTHESES_SYMBOL) {
        assert(false && "Cannot currently chain function calls");
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
                        //temporaryVariable.typeInfo = cubs_type_resolution_info_from_context(&CUBS_BOOL_CONTEXT);
                        temporaryVariable.typeInfo = (TypeResolutionInfo){.tag = TypeInfoBool, .value._bool = NULL};
                    } else if(tokenAfterFirst == ADD_OPERATOR) {
                        //temporaryVariable.typeInfo = cubs_type_resolution_info_from_context(&CUBS_INT_CONTEXT);
                        temporaryVariable.typeInfo = (TypeResolutionInfo){.tag = TypeInfoInt, .value._int = NULL};
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
                const ExprValue secondValue = parse_expression_value(
                    iter, variables, dependencies);

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
            const TypeResolutionInfo* typeInfo = &variables->variables[self->value.boolLiteral.variableIndex].typeInfo;
            //assert(typeInfo->knownContext == &CUBS_BOOL_CONTEXT);
            assert(typeInfo->tag == TypeInfoBool);
            return &CUBS_BOOL_CONTEXT;
        } break;
        case IntLit: {
            const TypeResolutionInfo* typeInfo = &variables->variables[self->value.intLiteral.variableIndex].typeInfo;
            //assert(typeInfo->knownContext == &CUBS_INT_CONTEXT);
            assert(typeInfo->tag == TypeInfoInt);
            return &CUBS_INT_CONTEXT;
        } break;
        case FloatLit: {
            const TypeResolutionInfo* typeInfo = &variables->variables[self->value.floatLiteral.variableIndex].typeInfo;
            //assert(typeInfo->knownContext == &CUBS_FLOAT_CONTEXT);
            assert(typeInfo->tag == TypeInfoFloat);
            return &CUBS_FLOAT_CONTEXT;
        } break;
        case Variable: {
            const TypeResolutionInfo* typeInfo = &variables->variables[self->value.variableIndex].typeInfo;
            // if(typeInfo->knownContext == NULL) {
            //     const CubsStringSlice typeName = typeInfo->typeName;
            //     const CubsTypeContext* argContext = cubs_program_find_type_context(program, typeName);
            //     assert(argContext != NULL);
            //     typeInfo->knownContext = argContext;
            // }
            // return typeInfo->knownContext;
            return cubs_type_resolution_info_get_context(typeInfo, program);
        } break;
        case Expression: {
            AstNode* exprNode = &self->value.expression;
            ast_node_resolve_types(exprNode, program, builder, variables);
            
            assert(exprNode->vtable->nodeType == astNodeBinaryExpression);
            const size_t index = ((const BinaryExprNode*)exprNode->ptr)->outputVariableIndex;            
            const TypeResolutionInfo* typeInfo = &variables->variables[index].typeInfo;
            // assert(typeInfo->knownContext != NULL);
            // return typeInfo->knownContext;
            return cubs_type_resolution_info_get_context(typeInfo, program);
        } break;
        case FunctionCall: { 
            AstNode* exprNode = &self->value.functionCall;
            ast_node_resolve_types(exprNode, program, builder, variables);

            const FunctionCallNode* callNode = (const FunctionCallNode*)exprNode->ptr;
            if(!callNode->hasReturnVariable) {
                return NULL;
            }

            const size_t index = callNode->returnVariable;            
            const TypeResolutionInfo* typeInfo = &variables->variables[index].typeInfo;
            // assert(typeInfo->knownContext != NULL);
            // return typeInfo->knownContext;
            return cubs_type_resolution_info_get_context(typeInfo, program);
        } break;
    }
}

ExprValueDst cubs_expr_value_build_function(
    const ExprValue* self,
    FunctionBuilder* builder,
    const StackVariablesAssignment* stackAssignment
) {
    switch(self->tag) {
        case Variable: {
            const ExprValueDst dst = {
                .hasDst = true, 
                .dst = stackAssignment->positions[self->value.variableIndex]};
            return dst;
        } break;
        case BoolLit: {
            const struct ExprValueBoolLiteral value = self->value.boolLiteral;
            const ExprValueDst dst = {.hasDst = true, .dst = stackAssignment->positions[value.variableIndex]};
            const Bytecode loadImmediateBool = operands_make_load_immediate(
                LOAD_IMMEDIATE_BOOL, 
                dst.dst, 
                (int64_t)value.literal
            );
            cubs_function_builder_push_bytecode(builder, loadImmediateBool);
            return dst;
        } break;
        case IntLit: {
            const struct ExprValueIntLiteral value = self->value.intLiteral;
            const ExprValueDst dst = {.hasDst = true, .dst = stackAssignment->positions[value.variableIndex]};
            Bytecode loadImmediateLong[2];
            operands_make_load_immediate_long(
                loadImmediateLong, cubsValueTagInt, dst.dst, *(const size_t*)&value.literal);
            cubs_function_builder_push_bytecode_many(builder, loadImmediateLong, 2);
            return dst;
        } break;
        case FloatLit: {            
            const struct ExprValueFloatLiteral value = self->value.floatLiteral;
            const ExprValueDst dst = {.hasDst = true, .dst = stackAssignment->positions[value.variableIndex]};
            Bytecode loadImmediateLong[2];
            operands_make_load_immediate_long(
                loadImmediateLong, cubsValueTagFloat, dst.dst, *(const size_t*)&value.literal);
            cubs_function_builder_push_bytecode_many(builder, loadImmediateLong, 2);
            return dst;
        } break;
        case Expression: {
            const AstNode node = self->value.expression;
            assert(node.vtable->nodeType == astNodeBinaryExpression);

            ast_node_build_function(&node, builder, stackAssignment);

            const BinaryExprNode* binExpr = (const BinaryExprNode*)node.ptr; 
            const ExprValueDst dst = {.hasDst = true, .dst = stackAssignment->positions[binExpr->outputVariableIndex]};
            return dst;
        } break;
        case FunctionCall: {
            const AstNode node = self->value.functionCall;
            assert(node.vtable->nodeType == astNodeTypeFunctionCall);
            
            ast_node_build_function(&node, builder, stackAssignment);

            const FunctionCallNode* callNode = (const FunctionCallNode*)node.ptr;
            if(callNode->hasReturnVariable) {
                const ExprValueDst dst = {.hasDst = true, .dst = stackAssignment->positions[callNode->returnVariable]};
                return dst;
            } else {
                return (ExprValueDst){0};
            }
        } break;
        default: {
            unreachable();
            return (ExprValueDst){0};
        }
    }
}

void cubs_expr_value_update_destination(ExprValue *self, size_t destinationVariableIndex)
{
    switch(self->tag) {
        case Variable: break;
        case BoolLit: {
            self->value.boolLiteral.variableIndex = destinationVariableIndex;
        } break;
        case IntLit: {
            self->value.intLiteral.variableIndex = destinationVariableIndex;
        } break;
        case FloatLit: {
            self->value.floatLiteral.variableIndex = destinationVariableIndex;
        } break;
        case Expression: {
            AstNode node = self->value.expression;
            assert(node.vtable->nodeType == astNodeBinaryExpression);

            BinaryExprNode* obj = (BinaryExprNode*)node.ptr;
            obj->outputVariableIndex = destinationVariableIndex;
        } break;
        case FunctionCall: {
            AstNode functionCallNode = self->value.functionCall;
            assert(functionCallNode.vtable->nodeType == astNodeTypeFunctionCall);
    
            FunctionCallNode* obj = (FunctionCallNode*)functionCallNode.ptr;
            assert(obj->hasReturnVariable);
            obj->returnVariable = destinationVariableIndex;
        } break;
        default: {
            unreachable();
        }
    }
}
