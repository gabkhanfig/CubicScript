#ifndef TYPE_RESOLUTION_INFO_H
#define TYPE_RESOLUTION_INFO_H

#include "../../primitives/string/string_slice.h"
#include <stdbool.h>

struct CubsTypeContext;
struct TokenIter;
struct TypeResolutionInfo;
struct CubsProgram;

/// Unused type. Only used due to C requirements for unions.
typedef void* _type_resolution_info_unused_t;

enum TypeResolutionInfoTag {
    TypeInfoUnknown,
    TypeInfoBool,
    TypeInfoInt,
    TypeInfoFloat,
    TypeInfoChar,
    TypeInfoString,
    TypeInfoStruct,
    TypeInfoReference,
    TypeInfoUnique,
    TypeInfoShared,
    TypeInfoWeak,
    TypeInfoKnownContext,
};

typedef struct TypeInfoStructData {
    CubsStringSlice typeName;
} TypeInfoStructData;

typedef struct TypeInfoReferenceData {
    bool isMutable;
    struct TypeResolutionInfo* child;
} TypeInfoReferenceData;

typedef struct TypeInfoUniqueData {
    struct TypeResolutionInfo* child;
} TypeInfoUniqueData;

typedef struct TypeInfoSharedData {
    struct TypeResolutionInfo* child;
} TypeInfoSharedData;

typedef struct TypeInfoWeakData {
    struct TypeResolutionInfo* child;
} TypeInfoWeakData;

union TypeResolutionInfoData {
    _type_resolution_info_unused_t  _unknown;
    _type_resolution_info_unused_t  _bool;
    _type_resolution_info_unused_t  _int;
    _type_resolution_info_unused_t  _float;
    _type_resolution_info_unused_t  _char;
    _type_resolution_info_unused_t  _string;
    TypeInfoStructData              structType;
    TypeInfoReferenceData           reference;
    TypeInfoUniqueData              unique;
    TypeInfoSharedData              shared;
    TypeInfoWeakData                weak;
    const struct CubsTypeContext*   knownContext;
};

typedef struct TypeResolutionInfo {
    enum TypeResolutionInfoTag tag;
    union TypeResolutionInfoData value;

    // /// Will always be a valid string slice
    // CubsStringSlice typeName;
    // /// If the parser encounters a type name like `int`, we can automatically
    // /// deduce the context of the type.
    // const struct CubsTypeContext* knownContext;
} TypeResolutionInfo;

void cubs_type_resolution_info_deinit(TypeResolutionInfo* self);

TypeResolutionInfo cubs_type_resolution_info_clone(const TypeResolutionInfo* self);

/// Parses a type such as `int`, `string`, or a struct.
/// Expects the parser to be at where the type info should be parsed from.
/// After calling, the parser will point to after the type info.
/// If the context cannot be immediately determined, as in the type is not
/// a primitive type, `knownContext` in the return value will be NULL,
/// and it will need to be resolved later.
TypeResolutionInfo cubs_parse_type_resolution_info(struct TokenIter* iter);

const struct CubsTypeContext* cubs_type_resolution_info_get_context(
    const TypeResolutionInfo* self,
    const struct CubsProgram* program
);

static inline bool cubs_type_resolution_info_is_reference_type(const TypeResolutionInfo* self) {
    return  self->tag == TypeInfoReference || 
            self->tag == TypeInfoUnique ||
            self->tag == TypeInfoShared ||
            self->tag == TypeInfoWeak;
}

//TypeResolutionInfo cubs_type_resolution_info_from_context(const struct CubsTypeContext* context);

#endif