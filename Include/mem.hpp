#ifndef MEM_H
#define MEM_H

#include <mach/mach.h>
#include <vector>

namespace mem {
    // This finds where Roblox is sitting in your iPad's RAM
    inline uintptr_t BaseAddress = 0;

    template <typename T>
    T read(uintptr_t address) {
        T buffer;
        vm_size_t outSize = sizeof(T);
        if (vm_read_overwrite(mach_task_self(), address, sizeof(T), (pointer_t)&buffer, &outSize) == KERN_SUCCESS) {
            return buffer;
        }
        return T();
    }
}

#endif
