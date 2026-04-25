#include "../offsets.hpp"

// This function follows the pointers to find the game's core
uintptr_t GetDataModel() {
    // mem::BaseAddress is the start of the Roblox app
    uintptr_t VisualEngine = *(uintptr_t*)(0x100000000 + offsets::VisualEnginePointer); 
    uintptr_t DataModelPointer = *(uintptr_t*)(VisualEngine + offsets::VisualEngineToDataModel1);
    uintptr_t DataModel = *(uintptr_t*)(DataModelPointer + offsets::VisualEngineToDataModel2);
    
    return DataModel;
}
