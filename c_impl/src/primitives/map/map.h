#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "../script_value.h"

CubsMap cubs_map_init(CubsValueTag keyTag, CubsValueTag valueTag);

void cubs_map_deinit(CubsMap* self);

CubsValueTag cubs_map_key_tag(const CubsMap* self);

CubsValueTag cubs_map_value_tag(const CubsMap* self);

size_t cubs_map_size(const CubsMap* self);

/// Find `key` within the map `self`. If it doesn't exist, returns `NULL`, otherwise
/// returns an immutable reference to the value in the key/value pair.
/// Mutation operations on this map may make the returned memory invalid.
/// Will not check that `key` is using the correct active union.
const CubsRawValue* cubs_map_find_unchecked(const CubsMap* self, const CubsRawValue* key);

/// Find `key` within the map `self`. If it doesn't exist, returns `NULL`, otherwise
/// returns an immutable reference to the value in the key/value pair.
/// Mutation operations on this map may make the returned memory invalid.
/// Asserts that `key->tag == cubs_map_key_tag(self)`.
const CubsRawValue* cubs_map_find(const CubsMap* self, const CubsTaggedValue* key);

/// Find `key` within the map `self`. If it doesn't exist, returns `NULL`, otherwise
/// returns a mutable reference to the value in the key/value pair.
/// Mutation operations on this map may make the returned memory invalid.
/// Will not check that `key` is using the correct active union.
CubsRawValue* cubs_map_find_mut_unchecked(CubsMap* self, const CubsRawValue* key);

/// Find `key` within the map `self`. If it doesn't exist, returns `NULL`, otherwise
/// returns a mutable reference to the value in the key/value pair.
/// Mutation operations on this map may make the returned memory invalid.
/// Asserts that `key->tag == cubs_map_key_tag(self)`.
CubsRawValue* cubs_map_find_mut(CubsMap* self, const CubsTaggedValue* key);

void cubs_map_insert_unchecked(CubsMap* self, CubsRawValue key, CubsRawValue value);

void cubs_map_insert(CubsMap* self, CubsTaggedValue key, CubsTaggedValue value);

/// Returns true if the entry `key` exists, and thus was successfully deleted and cleaned up,
/// and returns false if the entry doesn't exist.
bool cubs_map_erase_unchecked(CubsMap* self, const CubsRawValue* key);

/// Returns true if the entry `key` exists, and thus was successfully deleted and cleaned up,
/// and returns false if the entry doesn't exist.
bool cubs_map_erase(CubsMap* self, const CubsTaggedValue* key);