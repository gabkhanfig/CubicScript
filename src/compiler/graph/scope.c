#include "scope.h"
#include "../../util/unreachable.h"
#include "../../util/hash.h"
#include "../../platform/mem.h"
#include <assert.h>

static bool string_slice_eql(CubsStringSlice lhs, CubsStringSlice rhs) {
    if(lhs.len != rhs.len) {
        return false;
    }

    for(size_t i = 0; i < lhs.len; i++) {
        if(lhs.str[i] != rhs.str[i]) {
            return false;
        }
    }

    return true;
}

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
                const bool equalName = string_slice_eql(symbol->data.variable, symbolName);
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

void cubs_scope_add_symbol(Scope *self, ScopeSymbol symbol)
{
    size_t hash = 0;
    switch(symbol.symbolType) {
        case scopeSymbolTypeVariable: {       
            assert(symbol.data.variable.str != NULL);
            assert(symbol.data.variable.len > 0);
            hash = bytes_hash(symbol.data.variable.str, symbol.data.variable.len);
        } break;
        default: {
            unreachable();
        } 
    }

    add_one_capacity_to_scope(self);
    self->symbols[self->len] = symbol;
    self->hashCodes[self->len] = hash;
    self->len += 1;
}

FoundScopeSymbol cubs_scope_find_symbol(const Scope *self, CubsStringSlice symbolName)
{
    assert(symbolName.len > 0);
    assert(symbolName.str != NULL);

    const Scope* checking = self;
    const size_t hash = bytes_hash(symbolName.str, symbolName.len);
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
