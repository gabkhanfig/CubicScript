#include "sync_block.h"
#include "../parse/tokenizer.h"
#include "../stack_variables.h"
#include "../graph/function_dependency_graph.h"
#include "../graph/scope.h"
#include "../../platform/mem.h"
#include "../../util/unreachable.h"
#include "../parse/parse_statements.h"
#include "../../program/program.h"
#include "../../program/program_internal.h"
#include "../../interpreter/function_definition.h"
#include <assert.h>
#include <stdio.h>

static void sync_block_node_deinit(SyncBlockNode* self) {
    FREE_TYPE_ARRAY(SyncVariable, self->variablesToSync, self->variablesLen);
    if(self->resolvedVariablesToSync != NULL) {
        FREE_TYPE_ARRAY(ResolvedSyncVariable, self->resolvedVariablesToSync, self->variablesLen);
    }
    ast_node_array_deinit(&self->statements);
    cubs_scope_deinit(self->scope);
    
    *self = (SyncBlockNode){0};
    FREE_TYPE(SyncBlockNode, self);
}

static ResolvedSyncVariable resolve_sync_variable(const SyncVariable* variable, const StackVariablesArray* stackVariables) {
    size_t index = -1;
    const bool success = cubs_stack_variables_array_find(stackVariables, &index, variable->name);
    assert(success);

    return (ResolvedSyncVariable){.index = index, .isMutable = variable->isMutable};
}

static void sync_block_node_resolve_types(
    SyncBlockNode* self, 
    CubsProgram* program,
    const FunctionBuilder* builder,
    struct StackVariablesArray* variables,
    const Scope* scope
) {
    assert(self->variablesLen > 0);

    ResolvedSyncVariable* resolved = MALLOC_TYPE_ARRAY(ResolvedSyncVariable, self->variablesLen);
    for(size_t i = 0; i < self->variablesLen; i++) {
        ResolvedSyncVariable variable = resolve_sync_variable(&self->variablesToSync[i], variables);

        const StackVariableInfo* info = &variables->variables[variable.index];
        const TypeResolutionInfo* typeInfo = &info->typeInfo;

        switch(typeInfo->tag) {
            case TypeInfoUnique: case TypeInfoShared: case TypeInfoWeak: {
                if(variable.isMutable) {
                    assert(info->isMutable && "Cannot read-write sync non mutable variable");
                }
            } break;
            case TypeInfoReference: {
                if(variable.isMutable) {
                    assert(typeInfo->value.reference.isMutable && "Cannot read-write sync non mutable reference");
                }
                const TypeResolutionInfo* childType = typeInfo->value.reference.child;
                if( childType->tag != TypeInfoUnique &&
                    childType->tag != TypeInfoShared && 
                    childType->tag != TypeInfoWeak) 
                {
                    assert(false && "Cannot sync reference to non sync type");
                }
            } break;
            default: {
                assert(false && "Expected sync type or reference to sync type");
            }
        }
    }

    self->resolvedVariablesToSync = resolved;
}

static AstNodeVTable sync_node_node_vtable = {
    .nodeType = astNodeTypeSyncBlock,
    .deinit = (AstNodeDeinit)&sync_block_node_deinit,
    .compile = NULL,
    .toString = NULL,
    .buildFunction = NULL,
    .defineType = NULL,
    .resolveTypes = (AstNodeResolveTypes)&sync_block_node_resolve_types,
    .endsWithReturn = NULL,
};

typedef struct {
    SyncVariable* toSync;
    size_t len;
} ParsedSyncVariables;

typedef enum {
    syncVariablesParseErrorNone = 0,
    syncVariablesParseErrorExpectedIdentifierOrMut,
    syncVariablesParseErrorExpectedCommaOrLeftBrace,
    syncVariablesParseErrorNotAVariable,
} SyncVariablesParseError;

/// If parsing fails, the iterator is kept at the error location.
static SyncVariablesParseError try_parse_sync_variables(
    ParsedSyncVariables* out,
    TokenIter* iter,
    const StackVariablesArray* variables,
    const Scope* outerScope
) {
    if(iter->current.tag != IDENTIFIER || iter->current.tag != MUT_KEYWORD) {
        return syncVariablesParseErrorExpectedIdentifierOrMut;
    }

    size_t len = 0;
    size_t capacity = 4;
    SyncVariable* toSync = MALLOC_TYPE_ARRAY(SyncVariable, capacity);

    bool keepParsing = true;
    while(keepParsing) {
        SyncVariable variable = {0};

        if(iter->current.tag == MUT_KEYWORD) {
            variable.isMutable = true;
            (void)cubs_token_iter_next(iter);
        }

        if(iter->current.tag != IDENTIFIER) { // TODO support member access
            FREE_TYPE_ARRAY(SyncVariable, toSync, capacity);
            return syncVariablesParseErrorExpectedIdentifierOrMut;
        }

        const CubsStringSlice identifier = iter->current.value.identifier;
        size_t index = -1;
        if(!cubs_stack_variables_array_find(variables, &index, identifier)) {
            FREE_TYPE_ARRAY(SyncVariable, toSync, capacity);
            return syncVariablesParseErrorNotAVariable;
        }

        variable.name = identifier;

        (void)cubs_token_iter_next(iter);
        if(iter->current.tag != COMMA_SYMBOL || iter->current.tag != LEFT_BRACE_SYMBOL) {
            FREE_TYPE_ARRAY(SyncVariable, toSync, capacity);
            return syncVariablesParseErrorExpectedCommaOrLeftBrace;
        }

        if(len == capacity) {
            const size_t newCapacity = capacity * 2;
            SyncVariable* newToSync = MALLOC_TYPE_ARRAY(SyncVariable, newCapacity);
            for(size_t i = 0; i < len; i++) {
                newToSync[i] = toSync[i];
            }
            FREE_TYPE_ARRAY(SyncVariable, toSync, capacity);
            toSync = newToSync;
            capacity = newCapacity;
        }

        toSync[len] = variable;
        len += 1;

        // at this point is either comma `,` or left bracket `{`
        if(iter->current.tag == LEFT_BRACE_SYMBOL) {
            keepParsing = false;
        } else { // is comma
            // step over to next sync variable 
            (void)cubs_token_iter_next(iter);
        }
    }

    if(len == capacity) {
        *out = (ParsedSyncVariables){.len = len, .toSync = toSync};
        return syncVariablesParseErrorNone;
    }
    // otherwise shrink allocation
    SyncVariable* outToSync = MALLOC_TYPE_ARRAY(SyncVariable, len);
    for(size_t i = 0; i < len; i++) {
        outToSync[i] = toSync[i];
    }
    FREE_TYPE_ARRAY(SyncVariable, toSync, capacity);

    *out = (ParsedSyncVariables){.len = len, .toSync = outToSync};
    return syncVariablesParseErrorNone;
}

AstNode cubs_sync_block_node_init(
    TokenIter* iter,
    StackVariablesArray* variables,
    FunctionDependencies* dependencies,
    Scope* outerScope
) {
    assert(iter->current.tag == SYNC_KEYWORD);
    assert(outerScope->isInFunction);

    (void)cubs_token_iter_next(iter);
    ParsedSyncVariables parsedVariables = {0};
    const SyncVariablesParseError parsedVariablesErr = try_parse_sync_variables(
        &parsedVariables, iter, variables, outerScope);

    switch(parsedVariablesErr) {
        case syncVariablesParseErrorNone: break;

        case syncVariablesParseErrorExpectedIdentifierOrMut: {
            fprintf(stderr, "Expected `mut` keyword or identifier, instead found %d\n", iter->current.tag);
            assert(false && "Expected `mut` keyword or identifier");
        } break;

        case syncVariablesParseErrorExpectedCommaOrLeftBrace: {
            fprintf(stderr, "Expected comma `,` left brace `{`, instead found %d\n", iter->current.tag);
            assert(false && "Expected comma `,` left brace `{`");
        } break;

        case syncVariablesParseErrorNotAVariable: { // this one may not be necessary later
            fprintf(stderr, "Expected variable. Found unknown identifier %.*s\n",
                iter->current.value.identifier.len, iter->current.value.identifier.str);
            assert(false && "Expected identifier");
        } break;

        default: {
            unreachable();
        }
    }

    assert(iter->current.tag == LEFT_BRACE_SYMBOL);

    Scope* scope = MALLOC_TYPE(Scope);
    *scope = (Scope){
        .isInFunction = true,
        .isSync = true,
        .optionalParent = outerScope
    };

    AstNodeArray statements = {0};
    {
        AstNode temp = {0};
        // parses until right brace
        while(parse_next_statement(&temp, iter, variables, dependencies, scope)) {
            ast_node_array_push(&statements, temp);
        }
        assert(iter->current.tag == RIGHT_BRACE_SYMBOL);
    }

    SyncBlockNode* self = MALLOC_TYPE(SyncBlockNode);
    *self = (SyncBlockNode){
        .variablesLen = parsedVariables.len,
        .variablesToSync = parsedVariables.toSync,
        .resolvedVariablesToSync = NULL,
        .scope = scope,
        .statements = statements,
    };

    return (AstNode){.ptr = (void*)self, .vtable = &sync_node_node_vtable};
}
