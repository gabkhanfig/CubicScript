#include "build_options.h"
#include "../platform/mem.h"
#include <string.h>

CubsModule cubs_module_clone(const CubsModule *self)
{
    const CubsModule newModule = {.name = cubs_string_clone(&self->name), .rootSource = self->rootSource};
    return newModule;
}

void cubs_module_deinit(CubsModule *self)
{
    cubs_string_deinit(&self->name);
}

void cubs_build_options_add_module(CubsBuildOptions *self, const CubsModule *module)
{
    if(self->modulesLen >= self->_modulesCapacity) {
        const size_t newCapacity = (self->modulesLen + 1) * 2;
        CubsModule* newModules = cubs_malloc(newCapacity * sizeof(CubsModule), _Alignof(CubsModule));
        if(self->modules != NULL) {
            memcpy((void*)newModules, (const void*)self->modules, self->modulesLen * sizeof(CubsModule));
            cubs_free((void*)self->modules, self->_modulesCapacity * sizeof(CubsModule), _Alignof(CubsModule));
        }
        self->modules = newModules;
    }
    self->modules[self->modulesLen] = cubs_module_clone(module);
    self->modulesLen += 1;
}

void cubs_build_options_deinit(CubsBuildOptions *self)
{
    for(size_t i = 0; i < self->modulesLen; i++) {
        cubs_module_deinit(&self->modules[i]);
    }
    if(self->modules != NULL) {
        cubs_free((void*)self->modules, self->_modulesCapacity * sizeof(CubsModule), _Alignof(CubsModule));
    }
}
