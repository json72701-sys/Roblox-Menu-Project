#ifndef DATAMODEL_H
#define DATAMODEL_H

#include "../offsets.hpp"
#include "../Include/mem.hpp"

inline uintptr_t GetDataModel() {
    uintptr_t VisualEngine = mem::read<uintptr_t>(mem::BaseAddress + offsets::VisualEnginePointer);
    uintptr_t DataModelPointer = mem::read<uintptr_t>(VisualEngine + offsets::VisualEngineToDataModel1);
    uintptr_t DataModel = mem::read<uintptr_t>(DataModelPointer + offsets::VisualEngineToDataModel2);
    return DataModel;
}

#endif
