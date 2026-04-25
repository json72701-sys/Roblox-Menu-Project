#ifndef SCRIPT_ENGINE_H
#define SCRIPT_ENGINE_H

#include <cstdint>
#include <string>
#include "../Include/mem.hpp"
#include "../offsets.hpp"
#include "Engine.hpp"

namespace ScriptEngine {

    inline uintptr_t GetLuaState() {
        uintptr_t sc = Engine::g_State.scriptContext;
        if (!sc) return 0;
        // ScriptContext offset to its internal Lua state
        return mem::read<uintptr_t>(sc + offsets::ScriptContext);
    }

    inline uintptr_t GetScriptContext() {
        return Engine::g_State.scriptContext;
    }

    inline int GetIdentity(uintptr_t luaState) {
        if (!luaState) return 0;
        // Read the identity/security level from the Lua state
        uintptr_t extraSpace = mem::read<uintptr_t>(luaState + 0x48);
        if (!extraSpace) return 0;
        return mem::read<int>(extraSpace + offsets::Sandboxed);
    }

    inline bool IsReady() {
        return GetScriptContext() != 0 && GetLuaState() != 0;
    }

    struct ExecutionResult {
        bool success = false;
        std::string error;
    };

    // Placeholder for future Luau bytecode execution
    // Full implementation requires compiling Luau source to bytecode
    // and calling into the VM through the script context
    inline ExecutionResult Execute(const std::string& script) {
        ExecutionResult result;

        if (!IsReady()) {
            result.error = "Script engine not initialized";
            return result;
        }

        uintptr_t luaState = GetLuaState();
        if (!luaState) {
            result.error = "Failed to get Lua state";
            return result;
        }

        // TODO: Compile Luau source → bytecode, then push & execute
        // This requires linking against Luau compiler or using
        // the game's internal compilation functions
        result.error = "Execution pipeline ready — awaiting Luau compiler integration";
        return result;
    }
}

#endif
