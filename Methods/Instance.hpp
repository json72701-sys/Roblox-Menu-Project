#ifndef INSTANCE_H
#define INSTANCE_H

#include <cstdint>
#include <string>
#include <vector>
#include "../Include/mem.hpp"
#include "../offsets.hpp"

namespace Instance {

    inline std::string GetName(uintptr_t instance) {
        if (!instance) return "";
        uintptr_t namePtr = mem::read<uintptr_t>(instance + offsets::Name);
        if (!namePtr) return "";
        int nameLen = mem::read<int>(namePtr + offsets::NameSize);
        if (nameLen <= 0 || nameLen > 256) return "";

        // Short names are stored inline, long names behind a pointer
        uintptr_t strAddr = (nameLen < 16) ? namePtr : mem::read<uintptr_t>(namePtr);
        if (!strAddr) return "";

        char buf[257] = {};
        vm_size_t outSize = 0;
        if (vm_read_overwrite(mach_task_self(), strAddr, nameLen,
                              (pointer_t)buf, &outSize) != KERN_SUCCESS) {
            return "";
        }
        return std::string(buf, nameLen);
    }

    inline std::string GetClassName(uintptr_t instance) {
        if (!instance) return "";
        uintptr_t descriptor = mem::read<uintptr_t>(instance + offsets::ClassDescriptor);
        if (!descriptor) return "";
        uintptr_t namePtr = mem::read<uintptr_t>(descriptor + offsets::ClassDescriptorToClassName);
        if (!namePtr) return "";
        int nameLen = mem::read<int>(namePtr + offsets::NameSize);
        if (nameLen <= 0 || nameLen > 256) return "";

        uintptr_t strAddr = (nameLen < 16) ? namePtr : mem::read<uintptr_t>(namePtr);
        if (!strAddr) return "";

        char buf[257] = {};
        vm_size_t outSize = 0;
        if (vm_read_overwrite(mach_task_self(), strAddr, nameLen,
                              (pointer_t)buf, &outSize) != KERN_SUCCESS) {
            return "";
        }
        return std::string(buf, nameLen);
    }

    inline std::vector<uintptr_t> GetChildren(uintptr_t instance) {
        std::vector<uintptr_t> children;
        if (!instance) return children;

        uintptr_t childrenStart = mem::read<uintptr_t>(instance + offsets::Children);
        if (!childrenStart) return children;
        uintptr_t childrenEnd = mem::read<uintptr_t>(childrenStart + offsets::ChildrenEnd);
        if (!childrenEnd || childrenEnd <= childrenStart) return children;

        size_t count = (childrenEnd - childrenStart) / sizeof(uintptr_t);
        if (count > 10000) return children;

        for (size_t i = 0; i < count; i++) {
            uintptr_t child = mem::read<uintptr_t>(childrenStart + i * sizeof(uintptr_t));
            if (child) children.push_back(child);
        }
        return children;
    }

    inline uintptr_t FindFirstChild(uintptr_t instance, const std::string& name) {
        auto children = GetChildren(instance);
        for (auto child : children) {
            if (GetName(child) == name) return child;
        }
        return 0;
    }

    inline uintptr_t FindFirstChildOfClass(uintptr_t instance, const std::string& className) {
        auto children = GetChildren(instance);
        for (auto child : children) {
            if (GetClassName(child) == className) return child;
        }
        return 0;
    }

    inline uintptr_t GetParent(uintptr_t instance) {
        if (!instance) return 0;
        return mem::read<uintptr_t>(instance + offsets::Parent);
    }
}

#endif
