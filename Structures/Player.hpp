#ifndef PLAYER_H
#define PLAYER_H

#include "../offsets.hpp"
#include "../Include/mem.hpp"

// This tells the engine what a 'Player' looks like in memory
namespace Player {
    inline uintptr_t GetLocalPlayer(uintptr_t playersService) {
        return mem::read<uintptr_t>(playersService + offsets::LocalPlayer);
    }
}

#endif
