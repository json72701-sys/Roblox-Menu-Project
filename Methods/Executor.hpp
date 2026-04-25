#ifndef EXECUTOR_H
#define EXECUTOR_H

#include <string>
#include <cstdint>

namespace Executor {
    // Compiles raw Luau source text into bytecode using the embedded Luau compiler.
    // Returns the bytecode blob on success, or an empty string on failure.
    // On failure, `errorOut` is set to the error message.
    std::string CompileScript(const std::string& source, std::string& errorOut);

    // Compiles and injects script bytecode into memory at a target LocalScript instance.
    // Sets up elevated identity, full capabilities, and disables sandboxing before injection.
    // `dataModel` - the DataModel pointer obtained from GetDataModel()
    // `source`    - the raw Luau script text
    // Returns true on success, false on failure (with error in `errorOut`).
    bool ExecuteScript(uintptr_t dataModel, const std::string& source, std::string& errorOut);

    // Elevates identity level on a script instance's thread to allow access to restricted APIs.
    // `identityLevel` - the target identity (8 = max/plugin level)
    bool SetIdentity(uintptr_t scriptInstance, int identityLevel);

    // Sets full capabilities on a script instance to unlock all API access.
    bool SetCapabilities(uintptr_t scriptInstance);

    // Disables the Sandboxed flag on a script instance so it can access all services.
    bool SetSandboxed(uintptr_t scriptInstance, bool sandboxed);

    // Invalidates the script hash to force Roblox to re-deserialize the bytecode.
    bool InvalidateHash(uintptr_t scriptInstance);

    // Initializes loadstring support by resolving Luau VM function pointers.
    // Call once at startup with the Roblox binary's base address.
    // Returns true if loadstring will be available (all VM offsets non-zero).
    bool InitLoadstring(uintptr_t robloxBase);

    // Whether loadstring support is active (VM hooks resolved).
    bool IsLoadstringAvailable();
}

#endif
