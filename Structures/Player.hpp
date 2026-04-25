#ifndef PLAYER_H
#define PLAYER_H

#include <cstdint>
#include <string>
#include "../Include/mem.hpp"
#include "../offsets.hpp"
#include "../Methods/Instance.hpp"

namespace Player {

    inline uintptr_t GetLocalPlayer(uintptr_t playersService) {
        if (!playersService) return 0;
        return mem::read<uintptr_t>(playersService + offsets::LocalPlayer);
    }

    inline uintptr_t GetCharacter(uintptr_t player) {
        if (!player) return 0;
        return mem::read<uintptr_t>(player + offsets::ModelInstance);
    }

    inline uintptr_t GetHumanoid(uintptr_t character) {
        if (!character) return 0;
        return Instance::FindFirstChildOfClass(character, "Humanoid");
    }

    inline uintptr_t GetRootPart(uintptr_t character) {
        if (!character) return 0;
        uintptr_t part = Instance::FindFirstChild(character, "HumanoidRootPart");
        return part;
    }

    inline float GetHealth(uintptr_t humanoid) {
        if (!humanoid) return 0.0f;
        return mem::read<float>(humanoid + offsets::Health);
    }

    inline float GetMaxHealth(uintptr_t humanoid) {
        if (!humanoid) return 0.0f;
        return mem::read<float>(humanoid + offsets::MaxHealth);
    }

    inline float GetWalkSpeed(uintptr_t humanoid) {
        if (!humanoid) return 0.0f;
        return mem::read<float>(humanoid + offsets::WalkSpeed);
    }

    inline float GetJumpPower(uintptr_t humanoid) {
        if (!humanoid) return 0.0f;
        return mem::read<float>(humanoid + offsets::JumpPower);
    }

    inline std::string GetDisplayName(uintptr_t player) {
        if (!player) return "";
        return Instance::GetName(player);
    }

    inline int64_t GetUserId(uintptr_t player) {
        if (!player) return 0;
        return mem::read<int64_t>(player + offsets::UserId);
    }
}

#endif
