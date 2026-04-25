#ifndef EXECUTOR_H
#define EXECUTOR_H

#include "../offsets.hpp"
#include "../Include/mem.hpp"
#include "Instance.hpp"
#include "DataModel.hpp"
#include <string>

namespace Executor {
    inline uintptr_t FindLocalScript(uintptr_t dataModel) {
        uintptr_t players = Instance::FindFirstChild(dataModel, "Players");
        if (!players) return 0;

        uintptr_t localPlayer = mem::read<uintptr_t>(players + offsets::LocalPlayer);
        if (!localPlayer) return 0;

        // Walk: LocalPlayer → Character → look for a LocalScript
        std::string charName = Instance::GetName(localPlayer);
        uintptr_t character = Instance::FindFirstChild(localPlayer, charName);
        if (!character) {
            // Try finding character via direct children
            for (uintptr_t child : Instance::GetChildren(localPlayer)) {
                if (Instance::GetClassName(child) == "Model") {
                    character = child;
                    break;
                }
            }
        }

        // Search for any LocalScript in the character
        if (character) {
            uintptr_t script = Instance::FindFirstChildOfClass(character, "LocalScript");
            if (script) return script;
        }

        // Fallback: search PlayerScripts
        uintptr_t playerScripts = Instance::FindFirstChild(localPlayer, "PlayerScripts");
        if (playerScripts) {
            uintptr_t script = Instance::FindFirstChildOfClass(playerScripts, "LocalScript");
            if (script) return script;
        }

        return 0;
    }

    inline bool SetBytecode(uintptr_t localScript, const void* bytecode, size_t size) {
        if (!localScript || !bytecode || size == 0) return false;

        uintptr_t bytecodeAddr = localScript + offsets::LocalScriptByteCode;
        uintptr_t bytecodePtr = mem::read<uintptr_t>(bytecodeAddr);
        if (!bytecodePtr) return false;

        uintptr_t realBytecode = mem::read<uintptr_t>(bytecodePtr + offsets::LocalScriptBytecodePointer);
        if (!realBytecode) return false;

        kern_return_t kr = vm_write(
            mach_task_self(),
            realBytecode,
            (vm_offset_t)bytecode,
            (mach_msg_type_number_t)size
        );

        return kr == KERN_SUCCESS;
    }

    inline bool Execute(const void* bytecode, size_t size) {
        uintptr_t dm = GetDataModel();
        if (!dm) return false;

        uintptr_t script = FindLocalScript(dm);
        if (!script) return false;

        return SetBytecode(script, bytecode, size);
    }
}

#endif
