#ifndef MEM_H
#define MEM_H

#include <mach/mach.h>
#include <vector>

namespace mem {
    inline uintptr_t BaseAddress = 0;

    template <typename T>
    T read(uintptr_t address) {
        T buffer{};
        mach_msg_type_number_t sz = 0;
        if (vm_read_overwrite(mach_task_self(), address, sizeof(T),
                              (pointer_t)&buffer, &sz) == KERN_SUCCESS) {
            return buffer;
        }
        return T{};
    }

    template <typename T>
    bool write(uintptr_t address, T value) {
        return vm_write(mach_task_self(), address, (vm_offset_t)&value,
                        sizeof(T)) == KERN_SUCCESS;
    }
}

#endif
