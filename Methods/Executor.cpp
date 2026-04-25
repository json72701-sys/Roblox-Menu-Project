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

    if (bytecode.empty()) {
        errorOut = "Compilation returned empty output";
        return "";
    }

    // First byte: 0 = error (rest is message), non-zero = valid bytecode
    if (bytecode[0] == 0) {
        errorOut = "Compile error: " + bytecode.substr(1);
        return "";
    }

    errorOut.clear();
    return bytecode;
}

static bool WriteMemory(uintptr_t address, const void* data, size_t size) {
    kern_return_t kr = vm_write(
        mach_task_self(),
        (vm_address_t)address,
        (vm_offset_t)data,
        (mach_msg_type_number_t)size
    );
    return kr == KERN_SUCCESS;
}

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

static bool ReadClassName(uintptr_t instance, char* outBuf, size_t bufSize) {
    uintptr_t classDesc = mem::read<uintptr_t>(instance + offsets::ClassDescriptor);
    if (!classDesc) return false;

    uintptr_t namePtr = mem::read<uintptr_t>(classDesc + offsets::ClassDescriptorToClassName);
    if (!namePtr) return false;

    memset(outBuf, 0, bufSize);
    vm_size_t outSize = bufSize - 1;
    return vm_read_overwrite(mach_task_self(), namePtr, bufSize - 1,
                             (pointer_t)outBuf, &outSize) == KERN_SUCCESS;
}

// Recursively search for a child of the given class name
static uintptr_t FindChildOfClass(uintptr_t instance, const char* className, int depth) {
    if (depth <= 0 || !instance) return 0;

    uintptr_t childrenPtr = mem::read<uintptr_t>(instance + offsets::Children);
    if (!childrenPtr) return 0;

    uintptr_t childrenEnd = mem::read<uintptr_t>(childrenPtr + offsets::ChildrenEnd);
    uintptr_t current = mem::read<uintptr_t>(childrenPtr);

    while (current < childrenEnd) {
        uintptr_t child = mem::read<uintptr_t>(current);
        if (child) {
            char nameBuf[64] = {0};
            if (ReadClassName(child, nameBuf, sizeof(nameBuf))) {
                if (strcmp(nameBuf, className) == 0)
                    return child;
            }

            // Recurse into children (limit depth to avoid infinite loops)
            uintptr_t found = FindChildOfClass(child, className, depth - 1);
            if (found) return found;
        }
        current += sizeof(uintptr_t);
    }
    return 0;
}

// Search for a service by class name directly under DataModel
static uintptr_t FindService(uintptr_t dataModel, const char* serviceName) {
    uintptr_t childrenPtr = mem::read<uintptr_t>(dataModel + offsets::Children);
    if (!childrenPtr) return 0;

    uintptr_t childrenEnd = mem::read<uintptr_t>(childrenPtr + offsets::ChildrenEnd);
    uintptr_t current = mem::read<uintptr_t>(childrenPtr);

    while (current < childrenEnd) {
        uintptr_t child = mem::read<uintptr_t>(current);
        if (child) {
            char nameBuf[64] = {0};
            if (ReadClassName(child, nameBuf, sizeof(nameBuf))) {
                if (strcmp(nameBuf, serviceName) == 0)
                    return child;
            }
        }
        current += sizeof(uintptr_t);
    }
    return 0;
}

bool SetIdentity(uintptr_t scriptInstance, int identityLevel) {
    if (!scriptInstance) return false;

    // Read the script's extra space pointer which contains the thread state
    uintptr_t extraSpace = mem::read<uintptr_t>(scriptInstance + offsets::ScriptExtraSpace);
    if (!extraSpace) return false;

    // Write the identity level into the extra space identity slot
    int32_t identity = identityLevel;
    return WriteMemory(extraSpace + offsets::Identity, &identity, sizeof(identity));
}

bool SetCapabilities(uintptr_t scriptInstance) {
    if (!scriptInstance) return false;

    // Set full capabilities bitmask on the instance
    uint64_t caps = offsets::FullCapabilities;
    return WriteMemory(scriptInstance + offsets::InstanceCapabilities, &caps, sizeof(caps));
}

bool SetSandboxed(uintptr_t scriptInstance, bool sandboxed) {
    if (!scriptInstance) return false;

    // Read the current byte at the Sandboxed offset
    uint8_t currentByte = mem::read<uint8_t>(scriptInstance + offsets::Sandboxed);

    if (sandboxed) {
        currentByte |= 0x1;
    } else {
        currentByte &= ~0x1;
    }

    return WriteMemory(scriptInstance + offsets::Sandboxed, &currentByte, sizeof(currentByte));
}

bool InvalidateHash(uintptr_t scriptInstance) {
    if (!scriptInstance) return false;

    // Zero out the bytecode hash so Roblox re-reads the bytecode
    uint32_t zeroHash = 0;
    return WriteMemory(scriptInstance + offsets::LocalScriptHash, &zeroHash, sizeof(zeroHash));
}

// Set the RunContext on a script instance (0=Legacy, 1=Server, 2=Client, 3=Plugin)
static bool SetRunContext(uintptr_t scriptInstance, uint8_t context) {
    return WriteMemory(scriptInstance + offsets::RunContext, &context, sizeof(context));
}

// Try to find a LocalScript across multiple locations in the game hierarchy
static uintptr_t FindLocalScript(uintptr_t dataModel) {
    // 1. Try Workspace first (most common)
    uintptr_t workspace = mem::read<uintptr_t>(dataModel + offsets::Workspace);
    if (workspace) {
        uintptr_t ls = FindChildOfClass(workspace, "LocalScript", 4);
        if (ls) return ls;
    }

    // 2. Try Players -> LocalPlayer -> PlayerGui
    uintptr_t players = FindService(dataModel, "Players");
    if (players) {
        uintptr_t localPlayer = mem::read<uintptr_t>(players + offsets::LocalPlayer);
        if (localPlayer) {
            uintptr_t ls = FindChildOfClass(localPlayer, "LocalScript", 5);
            if (ls) return ls;
        }
    }

    // 3. Try ReplicatedFirst (scripts here run early)
    uintptr_t replicatedFirst = FindService(dataModel, "ReplicatedFirst");
    if (replicatedFirst) {
        uintptr_t ls = FindChildOfClass(replicatedFirst, "LocalScript", 3);
        if (ls) return ls;
    }

    // 4. Try StarterPlayerScripts / StarterCharacterScripts via StarterPlayer
    uintptr_t starterPlayer = FindService(dataModel, "StarterPlayer");
    if (starterPlayer) {
        uintptr_t ls = FindChildOfClass(starterPlayer, "LocalScript", 4);
        if (ls) return ls;
    }

    // 5. Try CoreGui for maximum privilege
    uintptr_t coreGui = FindService(dataModel, "CoreGui");
    if (coreGui) {
        uintptr_t ls = FindChildOfClass(coreGui, "LocalScript", 5);
        if (ls) return ls;
    }

    return 0;
}

bool ExecuteScript(uintptr_t dataModel, const std::string& source, std::string& errorOut) {
    // Step 1: Compile the script
    std::string bytecode = CompileScript(source, errorOut);
    if (bytecode.empty())
        return false;

    // Step 2: Get ScriptContext (needed for identity operations)
    uintptr_t scriptContext = mem::read<uintptr_t>(dataModel + offsets::ScriptContext);
    if (!scriptContext) {
        errorOut = "Could not find ScriptContext";
        return false;
    }

    // Step 3: Find a LocalScript to hijack — search across multiple services
    uintptr_t localScript = FindLocalScript(dataModel);
    if (!localScript) {
        errorOut = "Could not find a LocalScript instance to inject into";
        return false;
    }

    // Step 4: Elevate the execution environment before injection
    //   a) Set identity to level 8 (CoreScript/Plugin level — full API access)
    SetIdentity(localScript, 8);

    //   b) Set full capabilities bitmask so all APIs are unlocked
    SetCapabilities(localScript);

    //   c) Disable sandboxing so the script can access all services freely
    SetSandboxed(localScript, false);

    //   d) Set RunContext to Client (2) for proper execution context
    SetRunContext(localScript, 2);

    // Step 5: Allocate memory for the bytecode and write it
    uintptr_t bytecodeAddr = AllocateMemory(bytecode.size());
    if (!bytecodeAddr) {
        errorOut = "Failed to allocate memory for bytecode";
        return false;
    }

    if (!WriteMemory(bytecodeAddr, bytecode.data(), bytecode.size())) {
        errorOut = "Failed to write bytecode to memory";
        return false;
    }

    // Step 6: Inject the bytecode pointer into the LocalScript
    uintptr_t bytecodeSlot = localScript + offsets::LocalScriptByteCode;
    uintptr_t bytecodeStructPtr = mem::read<uintptr_t>(bytecodeSlot);

    if (bytecodeStructPtr) {
        WriteMemory(bytecodeStructPtr + offsets::LocalScriptBytecodePointer,
                    &bytecodeAddr, sizeof(uintptr_t));

        // Write the size of the bytecode after the pointer
        uint64_t bcSize = bytecode.size();
        WriteMemory(bytecodeStructPtr + offsets::LocalScriptBytecodePointer + sizeof(uintptr_t),
                    &bcSize, sizeof(bcSize));
    } else {
        errorOut = "LocalScript bytecode struct pointer is null";
        return false;
    }

    // Step 7: Invalidate the hash to force Roblox to re-deserialize our bytecode
    InvalidateHash(localScript);

    errorOut.clear();
    return true;
}

} // namespace Executor
