#include "DataModel.hpp"
#include "../Include/mem.hpp"
#include "../offsets.hpp"

uintptr_t GetDataModel() {
    uintptr_t visualEngine = mem::read<uintptr_t>(0x100000000 + offsets::VisualEnginePointer);
    if (!visualEngine) return 0;

    uintptr_t dataModelPtr = mem::read<uintptr_t>(visualEngine + offsets::VisualEngineToDataModel1);
    if (!dataModelPtr) return 0;

    uintptr_t dataModel = mem::read<uintptr_t>(dataModelPtr + offsets::VisualEngineToDataModel2);
    return dataModel;
}
