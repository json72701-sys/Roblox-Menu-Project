#include "Executor.hpp"
#include "Loadstring.hpp"
#include "../offsets.hpp"
#include "../Include/mem.hpp"
#include "Luau/Compiler.h"

#include <cstdlib>
#include <cstring>
#include <mach/mach.h>
#include <vector>
#include <string>

namespace Executor {

// Track previously used script instances so we pick a fresh one each execution
static std::vector<uintptr_t> usedScripts;

// Globals that scripts commonly access — tell compiler these are mutable
// so it doesn't optimize away repeated reads through these names
static const char* sMutableGlobals[] = {
    "game", "workspace", "script", "plugin",
    "shared", "Instance", "Vector3", "CFrame",
    "Color3", "BrickColor", "UDim2", "UDim",
    "Enum", "tick", "wait", "spawn", "delay",
    "warn", "typeof", "type", "newproxy",
    "select", "unpack", "rawget", "rawset",
    "setmetatable", "getmetatable",
    "pcall", "xpcall", "coroutine",
    "string", "table", "math", "os", "debug",
    nullptr
};

// Wraps user script to ensure globals are explicitly available and
// errors are caught with a traceback so the script never silently dies.
static std::string WrapScript(const std::string& source) {
    std::string wrapped;
    wrapped.reserve(source.size() + 512);

    // Establish local references to critical globals so they survive
    // even if the environment is sandboxed or the global table is modified.
    wrapped +=
        "local game = game\n"
        "local workspace = workspace or game:GetService('Workspace')\n"
        "local Players = game:GetService('Players')\n"
        "local ReplicatedStorage = game:GetService('ReplicatedStorage')\n"
        "local Lighting = game:GetService('Lighting')\n"
        "local RunService = game:GetService('RunService')\n"
        "local UserInputService = game:GetService('UserInputService')\n"
        "local TweenService = game:GetService('TweenService')\n"
        "local HttpService = game:GetService('HttpService')\n"
        "local StarterGui = game:GetService('StarterGui')\n"
        "local CoreGui = game:GetService('CoreGui')\n"
        "local LocalPlayer = Players.LocalPlayer\n"
        "\n";

    // Wrap the user's code in a protected call so runtime errors
    // are caught and printed instead of crashing the LocalScript.
    wrapped += "local ok, err = pcall(function()\n";
    wrapped += source;
    wrapped += "\nend)\n";
    wrapped += "if not ok then warn('[ElxrScriptz] Runtime error: ' .. tostring(err)) end\n";

    return wrapped;
}

std::string CompileScript(const std::string& source, std::string& errorOut) {
    Luau::CompileOptions options;
    options.optimizationLevel = 1;
    options.debugLevel = 1;
    options.mutableGlobals = sMutableGlobals;

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

// Check whether a script address was already used in a previous execution
static bool WasAlreadyUsed(uintptr_t addr) {
    for (size_t i = 0; i < usedScripts.size(); ++i) {
        if (usedScripts[i] == addr) return true;
    }
    return false;
}

// Collect ALL instances of a class under a parent (depth-limited recursive)
static void CollectChildrenOfClass(uintptr_t instance, const char* className,
                                   int depth, std::vector<uintptr_t>& results) {
    if (depth <= 0 || !instance) return;

    uintptr_t childrenPtr = mem::read<uintptr_t>(instance + offsets::Children);
    if (!childrenPtr) return;

    uintptr_t childrenEnd = mem::read<uintptr_t>(childrenPtr + offsets::ChildrenEnd);
    uintptr_t current = mem::read<uintptr_t>(childrenPtr);

    while (current < childrenEnd) {
        uintptr_t child = mem::read<uintptr_t>(current);
        if (child) {
            char nameBuf[64] = {0};
            if (ReadClassName(child, nameBuf, sizeof(nameBuf))) {
                if (strcmp(nameBuf, className) == 0)
                    results.push_back(child);
            }
            CollectChildrenOfClass(child, className, depth - 1, results);
        }
        current += sizeof(uintptr_t);
    }
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

    uintptr_t extraSpace = mem::read<uintptr_t>(scriptInstance + offsets::ScriptExtraSpace);
    if (!extraSpace) return false;

    int32_t identity = identityLevel;
    return WriteMemory(extraSpace + offsets::Identity, &identity, sizeof(identity));
}

bool SetCapabilities(uintptr_t scriptInstance) {
    if (!scriptInstance) return false;

    uint64_t caps = offsets::FullCapabilities;
    return WriteMemory(scriptInstance + offsets::InstanceCapabilities, &caps, sizeof(caps));
}

bool SetSandboxed(uintptr_t scriptInstance, bool sandboxed) {
    if (!scriptInstance) return false;

    uint8_t currentByte = mem::read<uint8_t>(scriptInstance + offsets::Sandboxed);
    if (sandboxed)
        currentByte |= 0x1;
    else
        currentByte &= ~0x1;

    return WriteMemory(scriptInstance + offsets::Sandboxed, &currentByte, sizeof(currentByte));
}

bool InvalidateHash(uintptr_t scriptInstance) {
    if (!scriptInstance) return false;

    uint32_t zeroHash = 0;
    return WriteMemory(scriptInstance + offsets::LocalScriptHash, &zeroHash, sizeof(zeroHash));
}

static bool SetRunContext(uintptr_t scriptInstance, uint8_t context) {
    return WriteMemory(scriptInstance + offsets::RunContext, &context, sizeof(context));
}

// Collect LocalScripts from every major service, preferring ones not yet used
static uintptr_t FindFreshLocalScript(uintptr_t dataModel) {
    std::vector<uintptr_t> candidates;

    // Workspace
    uintptr_t workspace = mem::read<uintptr_t>(dataModel + offsets::Workspace);
    if (workspace)
        CollectChildrenOfClass(workspace, "LocalScript", 5, candidates);

    // Players → LocalPlayer subtree
    uintptr_t players = FindService(dataModel, "Players");
    if (players) {
        uintptr_t lp = mem::read<uintptr_t>(players + offsets::LocalPlayer);
        if (lp)
            CollectChildrenOfClass(lp, "LocalScript", 6, candidates);
    }

    // ReplicatedFirst
    uintptr_t rf = FindService(dataModel, "ReplicatedFirst");
    if (rf) CollectChildrenOfClass(rf, "LocalScript", 4, candidates);

    // StarterPlayer
    uintptr_t sp = FindService(dataModel, "StarterPlayer");
    if (sp) CollectChildrenOfClass(sp, "LocalScript", 5, candidates);

    // CoreGui
    uintptr_t cg = FindService(dataModel, "CoreGui");
    if (cg) CollectChildrenOfClass(cg, "LocalScript", 6, candidates);

    // StarterGui
    uintptr_t sg = FindService(dataModel, "StarterGui");
    if (sg) CollectChildrenOfClass(sg, "LocalScript", 5, candidates);

    // Pick the first candidate that hasn't been used yet
    for (size_t i = 0; i < candidates.size(); ++i) {
        if (!WasAlreadyUsed(candidates[i]))
            return candidates[i];
    }

    // All exhausted — reuse the first candidate (wrap around)
    if (!candidates.empty()) {
        usedScripts.clear();
        return candidates[0];
    }

    return 0;
}

// Fallback: try to find a ModuleScript and inject into it instead
static uintptr_t FindFreshModuleScript(uintptr_t dataModel) {
    std::vector<uintptr_t> candidates;

    uintptr_t workspace = mem::read<uintptr_t>(dataModel + offsets::Workspace);
    if (workspace)
        CollectChildrenOfClass(workspace, "ModuleScript", 5, candidates);

    uintptr_t rs = FindService(dataModel, "ReplicatedStorage");
    if (rs) CollectChildrenOfClass(rs, "ModuleScript", 5, candidates);

    uintptr_t sp = FindService(dataModel, "StarterPlayer");
    if (sp) CollectChildrenOfClass(sp, "ModuleScript", 5, candidates);

    for (size_t i = 0; i < candidates.size(); ++i) {
        if (!WasAlreadyUsed(candidates[i]))
            return candidates[i];
    }

    if (!candidates.empty())
        return candidates[0];

    return 0;
}

// Inject bytecode into a script instance (works for both LocalScript and ModuleScript)
static bool InjectBytecode(uintptr_t scriptInstance, bool isModule,
                           const std::string& bytecode, std::string& errorOut) {

    // Elevate execution environment
    SetIdentity(scriptInstance, 8);
    SetCapabilities(scriptInstance);
    SetSandboxed(scriptInstance, false);
    SetRunContext(scriptInstance, 2);

    // Allocate and write bytecode
    uintptr_t bytecodeAddr = AllocateMemory(bytecode.size());
    if (!bytecodeAddr) {
        errorOut = "Failed to allocate memory for bytecode";
        return false;
    }

    if (!WriteMemory(bytecodeAddr, bytecode.data(), bytecode.size())) {
        errorOut = "Failed to write bytecode to memory";
        return false;
    }

    // Determine the right offsets based on script type
    uintptr_t bcSlotOffset = isModule ? offsets::ModuleScriptByteCode : offsets::LocalScriptByteCode;
    uintptr_t bcPtrOffset  = isModule ? offsets::ModuleScriptBytecodePointer : offsets::LocalScriptBytecodePointer;
    uintptr_t hashOffset   = isModule ? offsets::ModuleScriptHash : offsets::LocalScriptHash;

    uintptr_t bytecodeSlot = scriptInstance + bcSlotOffset;
    uintptr_t bytecodeStructPtr = mem::read<uintptr_t>(bytecodeSlot);

    if (bytecodeStructPtr) {
        // Write bytecode pointer
        WriteMemory(bytecodeStructPtr + bcPtrOffset, &bytecodeAddr, sizeof(uintptr_t));

        // Write bytecode size
        uint64_t bcSize = bytecode.size();
        WriteMemory(bytecodeStructPtr + bcPtrOffset + sizeof(uintptr_t), &bcSize, sizeof(bcSize));
    } else {
        errorOut = "Script bytecode struct pointer is null";
        return false;
    }

    // Invalidate hash to force re-deserialization
    uint32_t zeroHash = 0;
    WriteMemory(scriptInstance + hashOffset, &zeroHash, sizeof(zeroHash));

    // Mark this script as used
    usedScripts.push_back(scriptInstance);

    return true;
}

bool InitLoadstring(uintptr_t robloxBase) {
    return Loadstring::ResolveVMFunctions(robloxBase);
}

bool IsLoadstringAvailable() {
    return Loadstring::IsAvailable();
}

// Retrieves the lua_State* from a script instance's thread via ScriptContext
static void* GetLuaStateFromScript(uintptr_t dataModel, uintptr_t scriptInstance) {
    uintptr_t scriptContext = mem::read<uintptr_t>(dataModel + offsets::ScriptContext);
    if (!scriptContext) return nullptr;

    uintptr_t extraSpace = mem::read<uintptr_t>(scriptInstance + offsets::ScriptExtraSpace);
    if (!extraSpace) return nullptr;

    // The lua_State is typically at the start of the extra space structure
    uintptr_t luaState = mem::read<uintptr_t>(extraSpace);
    return reinterpret_cast<void*>(luaState);
}

bool ExecuteScript(uintptr_t dataModel, const std::string& source, std::string& errorOut) {
    // Step 1: Wrap the user's script with global setup and error handling
    std::string wrappedSource = WrapScript(source);

    // Step 2: Compile the wrapped script
    std::string bytecode = CompileScript(wrappedSource, errorOut);
    if (bytecode.empty()) {
        // If wrapping caused issues, try compiling the raw source
        errorOut.clear();
        bytecode = CompileScript(source, errorOut);
        if (bytecode.empty())
            return false;
    }

    // Step 3: Verify ScriptContext exists
    uintptr_t scriptContext = mem::read<uintptr_t>(dataModel + offsets::ScriptContext);
    if (!scriptContext) {
        errorOut = "Could not find ScriptContext";
        return false;
    }

    // Step 4: Find a fresh LocalScript target
    uintptr_t target = FindFreshLocalScript(dataModel);
    bool isModule = false;
    if (!target) {
        // Step 5: No LocalScript found -- fall back to ModuleScript
        target = FindFreshModuleScript(dataModel);
        isModule = true;
    }

    if (!target) {
        errorOut = "No LocalScript or ModuleScript found to inject into";
        return false;
    }

    // Step 6: Register loadstring on the script's lua_State if VM hooks are available
    if (Loadstring::IsAvailable()) {
        void* L = GetLuaStateFromScript(dataModel, target);
        if (L) {
            Loadstring::RegisterGlobal(reinterpret_cast<Loadstring::lua_State*>(L));
        }
    }

    // Step 7: Inject bytecode
    return InjectBytecode(target, isModule, bytecode, errorOut);
}

} // namespace Executor
