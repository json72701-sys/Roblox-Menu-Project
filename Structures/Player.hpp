#ifndef PLAYER_H
#define PLAYER_H

#include "../offsets.hpp"

// This tells the engine what a 'Player' looks like in memory
namespace Player {
    inline uintptr_t GetLocalPlayer(uintptr_t playersService) {
        // 0x130 is the offset for LocalPlayer from your list!
        return *(uintptr_t*)(playersService + 0x130); 
    }
}

#endif
