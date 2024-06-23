#pragma once

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include "../script_value.h"

CubsMap cubs_map_init_primitives(CubsValueTag keyTag, CubsValueTag valueTag);

CubsMap cubs_map_init_user_struct(const CubsStructContext* keyContext, const CubsStructContext* valueContext);

void cubs_map_deinit(CubsMap* self);

/// Find `key` within the map `self`. If it doesn't exist, returns `NULL`, otherwise
/// returns an immutable reference to the value in the key/value pair.
/// Assumes that `key` is the correct type that this map holds.
/// The return type must be cast to the appropriate type.
/// Mutation operations on this map may make the returned memory invalid.
const void* cubs_map_find(const CubsMap* self, const void* key);

/// Find `key` within the map `self`. If it doesn't exist, returns `NULL`, otherwise
/// returns a mutable reference to the value in the key/value pair.
/// Assumes that `key` is the correct type that this map holds.
/// The return type must be cast to the appropriate type.
/// Mutation operations on this map may make the returned memory invalid.
void* cubs_map_find_mut(CubsMap* self, const void* key);

void cubs_map_insert(CubsMap* self, void* key, void* value);

/// Returns true if the entry `key` exists, and thus was successfully deleted and cleaned up,
/// and returns false if the entry doesn't exist.
/// Assumes that `key` is the correct type that this map holds.
bool cubs_map_erase(CubsMap* self, const void* key);