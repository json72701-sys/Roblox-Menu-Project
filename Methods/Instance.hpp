#ifndef INSTANCE_H
#define INSTANCE_H

#include "../offsets.hpp"
#include "../Include/mem.hpp"
#include <string>
#include <vector>

namespace Instance {
    inline std::string GetName(uintptr_t instance) {
        if (!instance) return "";
        uintptr_t namePtr = mem::read<uintptr_t>(instance + offsets::Name);
        if (!namePtr) return "";
        uint32_t len = mem::read<uint32_t>(instance + offsets::Name + offsets::NameSize);
        if (len == 0 || len > 256) return "";

        std::string name(len, '\0');
        vm_size_t outsize = len;
        vm_read_overwrite(mach_task_self(), namePtr, len, (pointer_t)name.data(), &outsize);
        return name;
    }

    inline std::string GetClassName(uintptr_t instance) {
        if (!instance) return "";
        uintptr_t classDesc = mem::read<uintptr_t>(instance + offsets::ClassDescriptor);
        if (!classDesc) return "";
        uintptr_t classNamePtr = mem::read<uintptr_t>(classDesc + offsets::ClassDescriptorToClassName);
        if (!classNamePtr) return "";
        uint32_t len = mem::read<uint32_t>(classDesc + offsets::ClassDescriptorToClassName + offsets::NameSize);
        if (len == 0 || len > 256) return "";

        std::string name(len, '\0');
        vm_size_t outsize = len;
        vm_read_overwrite(mach_task_self(), classNamePtr, len, (pointer_t)name.data(), &outsize);
        return name;
    }

    inline std::vector<uintptr_t> GetChildren(uintptr_t instance) {
        std::vector<uintptr_t> children;
        if (!instance) return children;

        uintptr_t start = mem::read<uintptr_t>(instance + offsets::Children);
        uintptr_t end = mem::read<uintptr_t>(instance + offsets::Children + offsets::ChildrenEnd);
        if (!start || !end || end <= start) return children;

        size_t count = (end - start) / sizeof(uintptr_t);
        if (count > 10000) return children;

        for (size_t i = 0; i < count; i++) {
            uintptr_t child = mem::read<uintptr_t>(start + i * sizeof(uintptr_t));
            if (child) children.push_back(child);
        }
        return children;
    }

    inline uintptr_t FindFirstChild(uintptr_t instance, const std::string& name) {
        for (uintptr_t child : GetChildren(instance)) {
            if (GetName(child) == name) return child;
        }
        return 0;
    }

    inline uintptr_t FindFirstChildOfClass(uintptr_t instance, const std::string& className) {
        for (uintptr_t child : GetChildren(instance)) {
            if (GetClassName(child) == className) return child;
        }
        return 0;
    }
}

#endif
