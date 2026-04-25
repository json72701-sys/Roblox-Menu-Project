#ifndef ENGINE_H
#define ENGINE_H

#include <cstdint>
#include <string>
#include "../Methods/DataModel.hpp"
#include "../Methods/Instance.hpp"
#include "../Structures/Player.hpp"
#include "../offsets.hpp"
#include "../Include/mem.hpp"

namespace Engine {

    struct GameState {
        uintptr_t dataModel       = 0;
        uintptr_t workspace       = 0;
        uintptr_t players         = 0;
        uintptr_t lighting        = 0;
        uintptr_t localPlayer     = 0;
        uintptr_t character       = 0;
        uintptr_t humanoid        = 0;
        uintptr_t rootPart        = 0;
        uintptr_t camera          = 0;
        uintptr_t scriptContext   = 0;
        bool      initialized     = false;
    };

    inline GameState g_State;

    inline bool Initialize() {
        g_State.dataModel = GetDataModel();
        if (!g_State.dataModel) return false;

        g_State.workspace   = Instance::FindFirstChild(g_State.dataModel, "Workspace");
        g_State.players     = Instance::FindFirstChild(g_State.dataModel, "Players");
        g_State.lighting    = Instance::FindFirstChild(g_State.dataModel, "Lighting");

        if (g_State.players) {
            g_State.localPlayer = Player::GetLocalPlayer(g_State.players);
        }

        // ScriptContext lives inside DataModel
        g_State.scriptContext = Instance::FindFirstChildOfClass(g_State.dataModel, "ScriptContext");

        if (g_State.workspace) {
            g_State.camera = mem::read<uintptr_t>(g_State.workspace + offsets::Camera);
        }

        g_State.initialized = (g_State.dataModel != 0);
        return g_State.initialized;
    }

    inline void RefreshPlayer() {
        if (!g_State.players) return;

        g_State.localPlayer = Player::GetLocalPlayer(g_State.players);
        if (!g_State.localPlayer) return;

        g_State.character = Player::GetCharacter(g_State.localPlayer);
        if (!g_State.character) return;

        g_State.humanoid = Player::GetHumanoid(g_State.character);
        g_State.rootPart = Player::GetRootPart(g_State.character);
    }

    inline float GetGravity() {
        if (!g_State.workspace) return 196.2f;
        return mem::read<float>(g_State.workspace + offsets::Gravity);
    }

    inline float GetFOV() {
        if (!g_State.camera) return 70.0f;
        return mem::read<float>(g_State.camera + offsets::FOV);
    }
}

#endif
