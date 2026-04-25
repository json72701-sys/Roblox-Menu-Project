#include "Loadstring.hpp"
#include "../offsets.hpp"
#include "Luau/Compiler.h"

#include <cstring>
#include <string>

namespace Loadstring {

static fn_luau_load         s_luauLoad        = nullptr;
static fn_lua_pushcclosurek s_pushCClosure    = nullptr;
static fn_lua_setfield      s_setField        = nullptr;
static fn_lua_tolstring     s_toLString       = nullptr;
static fn_lua_pushstring    s_pushString      = nullptr;
static fn_lua_gettop        s_getTop          = nullptr;
static fn_lua_settop        s_setTop          = nullptr;
static fn_lua_pcall         s_pcall           = nullptr;
static fn_lua_getfield      s_getField        = nullptr;

static bool s_resolved = false;

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
    "loadstring",
    nullptr
};

bool IsAvailable() {
    return s_resolved;
}

bool ResolveVMFunctions(uintptr_t robloxBase) {
    if (offsets::LuauLoad == 0 || offsets::LuaPushCClosure == 0 ||
        offsets::LuaSetField == 0 || offsets::LuaToLString == 0 ||
        offsets::LuaPushString == 0 || offsets::LuaGetTop == 0 ||
        offsets::LuaSetTop == 0) {
        s_resolved = false;
        return false;
    }

    s_luauLoad     = reinterpret_cast<fn_luau_load>(robloxBase + offsets::LuauLoad);
    s_pushCClosure = reinterpret_cast<fn_lua_pushcclosurek>(robloxBase + offsets::LuaPushCClosure);
    s_setField     = reinterpret_cast<fn_lua_setfield>(robloxBase + offsets::LuaSetField);
    s_toLString    = reinterpret_cast<fn_lua_tolstring>(robloxBase + offsets::LuaToLString);
    s_pushString   = reinterpret_cast<fn_lua_pushstring>(robloxBase + offsets::LuaPushString);
    s_getTop       = reinterpret_cast<fn_lua_gettop>(robloxBase + offsets::LuaGetTop);
    s_setTop       = reinterpret_cast<fn_lua_settop>(robloxBase + offsets::LuaSetTop);

    if (offsets::LuaPCall != 0)
        s_pcall = reinterpret_cast<fn_lua_pcall>(robloxBase + offsets::LuaPCall);
    if (offsets::LuaGetField != 0)
        s_getField = reinterpret_cast<fn_lua_getfield>(robloxBase + offsets::LuaGetField);

    s_resolved = true;
    return true;
}

int CompileAndLoad(lua_State* L, const char* source, size_t len, const char* chunkname) {
    if (!s_resolved) return -1;

    Luau::CompileOptions options;
    options.optimizationLevel = 1;
    options.debugLevel = 1;
    options.mutableGlobals = sMutableGlobals;

    std::string src(source, len);
    std::string bytecode = Luau::compile(src, options);

    if (bytecode.empty()) {
        s_pushString(L, "loadstring: compilation returned empty output");
        return -1;
    }

    if (bytecode[0] == 0) {
        std::string errMsg = "loadstring: " + bytecode.substr(1);
        s_pushString(L, errMsg.c_str());
        return -1;
    }

    int result = s_luauLoad(L, chunkname, bytecode.data(), bytecode.size(), 0);
    if (result != 0) {
        return -1;
    }

    return 0;
}

// C callback registered as "loadstring" in the Luau global table.
// Signature: loadstring(source [, chunkname]) -> function | (nil, error)
static int LoadstringCallback(lua_State* L) {
    size_t sourceLen = 0;
    const char* source = s_toLString(L, 1, &sourceLen);
    if (!source) {
        s_setTop(L, 0);
        s_pushString(L, "nil");  // push nil equivalent
        s_pushString(L, "loadstring: expected string argument");
        return 2;
    }

    const char* chunkname = "=loadstring";
    size_t nameLen = 0;
    const char* customName = s_toLString(L, 2, &nameLen);
    if (customName && nameLen > 0)
        chunkname = customName;

    Luau::CompileOptions options;
    options.optimizationLevel = 1;
    options.debugLevel = 1;
    options.mutableGlobals = sMutableGlobals;

    std::string src(source, sourceLen);
    std::string bytecode = Luau::compile(src, options);

    if (bytecode.empty() || bytecode[0] == 0) {
        std::string errMsg;
        if (bytecode.empty())
            errMsg = "loadstring: compilation failed";
        else
            errMsg = bytecode.substr(1);

        s_setTop(L, 0);
        s_pushString(L, "nil");
        s_pushString(L, errMsg.c_str());
        return 2;
    }

    s_setTop(L, 0);

    int loadResult = s_luauLoad(L, chunkname, bytecode.data(), bytecode.size(), 0);
    if (loadResult != 0) {
        s_pushString(L, "nil");
        s_pushString(L, "loadstring: failed to load compiled bytecode");
        return 2;
    }

    return 1;
}

bool RegisterGlobal(lua_State* L) {
    if (!s_resolved) return false;

    // Push our C callback as a closure with debugname "loadstring"
    s_pushCClosure(L, LoadstringCallback, "loadstring", 0, nullptr);

    // LUA_GLOBALSINDEX is typically -10002 in Luau
    s_setField(L, -10002, "loadstring");

    return true;
}

} // namespace Loadstring
