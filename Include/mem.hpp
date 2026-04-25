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
        // mach_vm_read is the "stealthy" way to read memory on iOS
        if (vm_read_overwrite(mach_task_self(), address, sizeof(T), (pointer_t)&buffer, new mach_msg_type_number_t()) == KERN_SUCCESS) {
            return buffer;
        }
        return T();
    }
}

#endif
