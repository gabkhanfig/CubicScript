#include "scope.h"
#include "../../util/unreachable.h"
#include "../../platform/mem.h"
#include <assert.h>
#include <stdio.h>

/// Does not check if the symbol is present in the scope's parent scopes.
/// Returns `-1` if cannot find
static size_t find_in_scope_no_parent(const Scope* self, const CubsString* symbolName, size_t nameHash) {
    for(size_t i = 0; i < self->len; i++) {
        if(self->hashCodes[i] != nameHash) {
            continue;
        }

        const ScopeSymbol* symbol = &self->symbols[i];
        switch(symbol->symbolType) {
            case scopeSymbolTypeVariable: {
                const bool equalName = cubs_string_eql(&symbol->data.variableSymbol, symbolName);
                if(equalName) {
                    return i;
                }
            } break;
            case scopeSymbolTypeFunction: {
                const bool equalName = cubs_string_eql(&symbol->data.functionSymbol, symbolName);
                if(equalName) {
                    return i;
                }
            } break;
            case scopeSymbolTypeStruct: {
                const bool equalName = cubs_string_eql(&symbol->data.structSymbol, symbolName);
                if(equalName) {
                    return i;
                }
            } break;
            default: {
                unreachable();
            }
        }
    }
    return -1;
}

static void add_one_capacity_to_scope(Scope *self) {
    if(self->len < self->capacity) {
        return;
    }

    const size_t newCapacity = self->len == 0 ? 4 : self->len * 2;
    ScopeSymbol* newMem = MALLOC_TYPE_ARRAY(ScopeSymbol, newCapacity);
    size_t* newHash = MALLOC_TYPE_ARRAY(size_t, newCapacity);
    if(self->symbols != NULL) {
        assert(self->hashCodes != NULL);
        for(size_t i = 0; i < self->len; i++) {
            newMem[i] = self->symbols[i];
            newHash[i] = self->hashCodes[i];
        }
        FREE_TYPE_ARRAY(ScopeSymbol, self->symbols, self->capacity);
        FREE_TYPE_ARRAY(size_t, self->hashCodes, self->capacity);
    }
    self->symbols = newMem;
    self->hashCodes = newHash;
    self->capacity = newCapacity;
}

static void print_scope(const Scope* self) {
    const Scope* checking = self;
    int depth = 0;
    while(checking != NULL) {
        fprintf(stderr, "scope depth %d:\n", depth);
        for(size_t i = 0; i < checking->len; i++) {
            const CubsStringSlice slice = cubs_string_as_slice(&self->symbols[i].data.variableSymbol);
            fprintf(stderr, "[%lld] %d %s\n", i, self->symbols[i].symbolType, slice.str);
        }
        checking = checking->optionalParent;
        depth += 1;
    }
}

void cubs_scope_deinit(Scope *self)
{
    if(self->symbols == NULL) {
        assert(self->hashCodes == NULL);
        return;
    }
    FREE_TYPE_ARRAY(ScopeSymbol, self->symbols, self->capacity);
    FREE_TYPE_ARRAY(size_t, self->hashCodes, self->capacity);
    *self = (Scope){0};
}

bool cubs_scope_add_symbol(Scope *self, ScopeSymbol symbol)
{
    size_t hash = 0;
    const CubsString* symbolName = {0};
    switch(symbol.symbolType) {
        case scopeSymbolTypeVariable: {
            assert(symbol.data.variableSymbol.len > 0);
            symbolName = &symbol.data.variableSymbol;
            hash = cubs_string_hash(symbolName);
        } break;
        case scopeSymbolTypeFunction: {
            assert(symbol.data.functionSymbol.len > 0);
            symbolName = &symbol.data.functionSymbol;
            hash = cubs_string_hash(symbolName);
        } break;
        case scopeSymbolTypeStruct: {
            assert(symbol.data.structSymbol.len > 0);
            symbolName = &symbol.data.structSymbol;
            hash = cubs_string_hash(symbolName);
        } break;
        default: {
            unreachable();
        } 
    }

    { // validate symbol isn't in this scope or any parent scopes
        const Scope* checking = self;
        while(checking != NULL) {
            const size_t foundIndex = find_in_scope_no_parent(checking, symbolName, hash);
            if(foundIndex != -1) {
                return false;
            }
            // May set to NULL, stopping the loop
            checking = checking->optionalParent;
        }
    }

    add_one_capacity_to_scope(self);
    self->symbols[self->len] = symbol;
    self->hashCodes[self->len] = hash;
    self->len += 1;
    return true;
}

FoundScopeSymbol cubs_scope_find_symbol(const Scope *self, CubsStringSlice symbolName)
{
    
    assert(symbolName.len > 0);
    assert(symbolName.str != NULL);

    // todo make this not unnecessarily allocate
    const CubsString asString = cubs_string_init_unchecked(symbolName);
    const size_t hash = cubs_string_hash(&asString);

    const Scope* checking = self;
    while(checking != NULL) {
        const size_t foundIndex = find_in_scope_no_parent(checking, &asString, hash);
        if(foundIndex != -1) {
            const FoundScopeSymbol found = {
                .didFind = true,
                .symbol = &checking->symbols[foundIndex],
                .owningScope = checking
            };
            return found;
        }
        // May set to NULL, stopping the loop
        checking = checking->optionalParent;
    }
    return (FoundScopeSymbol){.didFind = false, .symbol = NULL, .owningScope = NULL};
}

bool cubs_scope_symbol_defined_in(const Scope *scope, size_t *outIndex, CubsStringSlice symbolName)
{
    // todo make this not unnecessarily allocate
    const CubsString asString = cubs_string_init_unchecked(symbolName);
    const size_t hash = cubs_string_hash(&asString);
    const size_t foundIndex = find_in_scope_no_parent(scope, &asString, hash);
    if(foundIndex == -1) {
        return false;
    }
    *outIndex = foundIndex;
    return true;
}
