#include "scope.h"
#include "../../util/unreachable.h"
#include "../../platform/mem.h"
#include <assert.h>

/// Does not check if the symbol is present in the scope's parent scopes.
/// Returns `-1` if cannot find
static size_t find_in_scope_no_parent(const Scope* self, CubsStringSlice symbolName, size_t nameHash) {
    for(size_t i = 0; i < self->len; i++) {
        if(self->hashCodes[i] != nameHash) {
            continue;
        }

        const ScopeSymbol* symbol = &self->symbols[i];
        switch(symbol->symbolType) {
            case scopeSymbolTypeVariable: {
                const bool equalName = cubs_string_slice_eql(symbol->data.variable, symbolName);
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
    CubsStringSlice symbolName = {0};
    switch(symbol.symbolType) {
        case scopeSymbolTypeVariable: {       
            assert(symbol.data.variable.str != NULL);
            assert(symbol.data.variable.len > 0);
            symbolName = symbol.data.variable;
            hash = cubs_string_slice_hash(symbolName);
        } break;
        default: {
            unreachable();
        } 
    }

    { // validate symbol isn't in this scope or any parent scopes
        const Scope* checking = self;
        while(checking != NULL) {
            const size_t foundIndex = find_in_scope_no_parent(self, symbolName, hash);
            if(foundIndex != -1) {
                return false;
            }
            // May set to NULL, stopping the loop
            checking = self->optionalParent;
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

    const Scope* checking = self;
    const size_t hash = cubs_string_slice_hash(symbolName);
    while(checking != NULL) {
        const size_t foundIndex = find_in_scope_no_parent(self, symbolName, hash);
        if(foundIndex != -1) {
            const FoundScopeSymbol found = {
                .didFind = true,
                .symbol = &self->symbols[foundIndex],
                .owningScope = checking
            };
            return found;
        }
        // May set to NULL, stopping the loop
        checking = self->optionalParent;
    }
    return (FoundScopeSymbol){.didFind = false, .symbol = NULL, .owningScope = NULL};
}

bool cubs_scope_symbol_defined_in(const Scope *scope, size_t *outIndex, CubsStringSlice symbolName)
{
    const size_t hash = cubs_string_slice_hash(symbolName);
    const size_t foundIndex = find_in_scope_no_parent(scope, symbolName, hash);
    if(foundIndex == -1) {
        return false;
    }
    *outIndex = foundIndex;
    return true;
}
