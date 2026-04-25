#ifndef BASE_H
#define BASE_H

#include <mach-o/dyld.h>
#include <string.h>
#include <cstdint>

namespace base {
    inline uintptr_t GetRobloxBase() {
        uint32_t count = _dyld_image_count();
        for (uint32_t i = 0; i < count; i++) {
            const char* name = _dyld_get_image_name(i);
            if (name && strstr(name, "RobloxPlayer")) {
                return (uintptr_t)_dyld_get_image_header(i);
            }
        }
        return 0;
    }
}

#endif
