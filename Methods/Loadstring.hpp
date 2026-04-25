#ifndef LOADSTRING_H
#define LOADSTRING_H

#include <string>
#include <cstdint>

namespace Loadstring {
    // Luau VM function pointer typedefs (resolved at runtime from Roblox binary)
    using lua_State = void;
    using lua_CFunction = int (*)(lua_State* L);
    using lua_Continuation = int (*)(lua_State* L, int status);

    typedef int    (*fn_luau_load)(lua_State* L, const char* chunkname, const char* data, size_t size, int env);
    typedef void   (*fn_lua_pushcclosurek)(lua_State* L, lua_CFunction fn, const char* debugname, int nup, lua_Continuation cont);
    typedef void   (*fn_lua_setfield)(lua_State* L, int idx, const char* k);
    typedef const char* (*fn_lua_tolstring)(lua_State* L, int idx, size_t* len);
    typedef void   (*fn_lua_pushstring)(lua_State* L, const char* s);
    typedef int    (*fn_lua_gettop)(lua_State* L);
    typedef void   (*fn_lua_settop)(lua_State* L, int idx);
    typedef int    (*fn_lua_pcall)(lua_State* L, int nargs, int nresults, int errfunc);
    typedef void   (*fn_lua_getfield)(lua_State* L, int idx, const char* k);

    // Whether loadstring VM hooks are available (offsets resolved successfully)
    bool IsAvailable();

    // Resolves Luau VM function pointers from offsets + Roblox base address.
    // Must be called once before RegisterGlobal(). Returns true if all resolved.
    bool ResolveVMFunctions(uintptr_t robloxBase);

    // Registers "loadstring" as a global function on the given lua_State.
    // The registered C callback compiles source via the embedded Luau compiler
    // and loads it via luau_load, returning the resulting function or nil+error.
    // Returns true on success.
    bool RegisterGlobal(lua_State* L);

    // Standalone compile-and-load: compiles source to bytecode, then calls
    // luau_load to create a function on the Lua stack.
    // Returns 0 on success, or pushes nil+error and returns 2 on failure.
    int CompileAndLoad(lua_State* L, const char* source, size_t len, const char* chunkname);
}

#endif
