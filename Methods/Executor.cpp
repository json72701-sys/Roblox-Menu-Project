#include "Executor.hpp"
#include "../offsets.hpp"
#include "../Include/mem.hpp"
#include "Luau/Compiler.h"

#include <cstdlib>
#include <cstring>
#include <mach/mach.h>

namespace Executor {

std::string CompileScript(const std::string& source, std::string& errorOut) {
    Luau::CompileOptions options;
    options.optimizationLevel = 1;
    options.debugLevel = 1;

    std::string bytecode = Luau::compile(source, options);

    // The first byte of the compiled output indicates success/failure:
    // 0 = error (rest of string is the error message)
    // non-zero = valid bytecode
    if (bytecode.empty()) {
        errorOut = "Compilation returned empty output";
        return "";
    }

    if (bytecode[0] == 0) {
        errorOut = "Compile error: " + bytecode.substr(1);
        return "";
    }

    errorOut.clear();
    return bytecode;
}

// Write raw bytes into another process/self memory
static bool WriteMemory(uintptr_t address, const void* data, size_t size) {
    kern_return_t kr = vm_write(
        mach_task_self(),
        (vm_address_t)address,
        (vm_offset_t)data,
        (mach_msg_type_number_t)size
    );
    return kr == KERN_SUCCESS;
}

// Allocate memory in the target task for our bytecode
static uintptr_t AllocateMemory(size_t size) {
    vm_address_t addr = 0;
    kern_return_t kr = vm_allocate(
        mach_task_self(),
        &addr,
        size,
        VM_FLAGS_ANYWHERE
    );
    if (kr != KERN_SUCCESS)
        return 0;
    return (uintptr_t)addr;
}

// Traverse children of an instance to find a child by class name
static uintptr_t FindFirstChildOfClass(uintptr_t instance, const char* className) {
    uintptr_t childrenPtr = mem::read<uintptr_t>(instance + offsets::Children);
    if (!childrenPtr) return 0;

    uintptr_t childrenEnd = mem::read<uintptr_t>(childrenPtr + offsets::ChildrenEnd);
    uintptr_t current = mem::read<uintptr_t>(childrenPtr);

    while (current < childrenEnd) {
        uintptr_t child = mem::read<uintptr_t>(current);
        if (child) {
            uintptr_t classDesc = mem::read<uintptr_t>(child + offsets::ClassDescriptor);
            if (classDesc) {
                uintptr_t namePtr = mem::read<uintptr_t>(classDesc + offsets::ClassDescriptorToClassName);
                if (namePtr) {
                    char nameBuf[64] = {0};
                    vm_size_t outSize = sizeof(nameBuf) - 1;
                    vm_read_overwrite(mach_task_self(), namePtr, sizeof(nameBuf) - 1,
                                      (pointer_t)nameBuf, &outSize);
                    if (strcmp(nameBuf, className) == 0)
                        return child;
                }
            }
        }
        current += sizeof(uintptr_t);
    }
    return 0;
}

bool ExecuteScript(uintptr_t dataModel, const std::string& source, std::string& errorOut) {
    // Step 1: Compile the script
    std::string bytecode = CompileScript(source, errorOut);
    if (bytecode.empty())
        return false;

    // Step 2: Find a LocalScript to hijack for execution
    // Traverse: DataModel -> Workspace -> find a LocalScript
    // Or: DataModel -> ScriptContext path
    uintptr_t scriptContext = mem::read<uintptr_t>(dataModel + offsets::ScriptContext);
    if (!scriptContext) {
        errorOut = "Could not find ScriptContext";
        return false;
    }

    // Try to find an existing LocalScript through the Players service
    uintptr_t workspace = mem::read<uintptr_t>(dataModel + offsets::Workspace);
    if (!workspace) {
        errorOut = "Could not find Workspace";
        return false;
    }

    uintptr_t localScript = FindFirstChildOfClass(workspace, "LocalScript");
    if (!localScript) {
        errorOut = "Could not find a LocalScript instance to inject into";
        return false;
    }

    // Step 3: Allocate memory for the bytecode and write it
    uintptr_t bytecodeAddr = AllocateMemory(bytecode.size());
    if (!bytecodeAddr) {
        errorOut = "Failed to allocate memory for bytecode";
        return false;
    }

    if (!WriteMemory(bytecodeAddr, bytecode.data(), bytecode.size())) {
        errorOut = "Failed to write bytecode to memory";
        return false;
    }

    // Step 4: Inject the bytecode pointer into the LocalScript
    uintptr_t bytecodeSlot = localScript + offsets::LocalScriptByteCode;
    uintptr_t bytecodeStructPtr = mem::read<uintptr_t>(bytecodeSlot);

    if (bytecodeStructPtr) {
        // Write our bytecode pointer into the struct
        WriteMemory(bytecodeStructPtr + offsets::LocalScriptBytecodePointer,
                    &bytecodeAddr, sizeof(uintptr_t));
    } else {
        errorOut = "LocalScript bytecode struct pointer is null";
        return false;
    }

    errorOut.clear();
    return true;
}

} // namespace Executor
