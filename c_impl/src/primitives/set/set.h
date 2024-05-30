#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "../script_value.h"

CubsSet cubs_set_init(CubsValueTag tag);

void cubs_set_deinit(CubsSet* self);

CubsValueTag cubs_set_tag(const CubsSet* self);

size_t cubs_set_size_of_key(const CubsSet* self);

bool cubs_set_contains_unchecked(const CubsSet* self, const void* key);

bool cubs_set_contains_raw_unchecked(const CubsSet* self, const CubsRawValue* key);

bool cubs_set_contains(const CubsSet* self, const CubsTaggedValue* key);

void cubs_set_insert_unchecked(CubsSet* self, void* key);

void cubs_set_insert_raw_unchecked(CubsSet* self, CubsRawValue key);

void cubs_set_insert(CubsSet* self, CubsTaggedValue key);

/// Returns true if the entry `key` exists, and thus was successfully deleted and cleaned up,
/// and returns false if the entry doesn't exist.
bool cubs_set_erase_unchecked(CubsSet* self, const void* key);

/// Returns true if the entry `key` exists, and thus was successfully deleted and cleaned up,
/// and returns false if the entry doesn't exist.
bool cubs_set_erase_raw_unchecked(CubsSet* self, const CubsRawValue* key);

/// Returns true if the entry `key` exists, and thus was successfully deleted and cleaned up,
/// and returns false if the entry doesn't exist.
bool cubs_set_erase(CubsSet* self, const CubsTaggedValue* key);