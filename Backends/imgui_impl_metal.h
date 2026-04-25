#ifndef IMGUI_IMPL_METAL_H
#define IMGUI_IMPL_METAL_H

#include "../imgui.h"

#ifdef __OBJC__
@protocol MTLDevice, MTLRenderCommandEncoder, MTLCommandBuffer;

bool     ImGui_ImplMetal_Init(id<MTLDevice> device);
void     ImGui_ImplMetal_Shutdown();
void     ImGui_ImplMetal_NewFrame(MTLRenderPassDescriptor* renderPassDescriptor);
void     ImGui_ImplMetal_RenderDrawData(ImDrawData* drawData,
                                         id<MTLCommandBuffer> commandBuffer,
                                         id<MTLRenderCommandEncoder> commandEncoder);

bool     ImGui_ImplMetal_CreateFontsTexture(id<MTLDevice> device);
void     ImGui_ImplMetal_DestroyFontsTexture();
bool     ImGui_ImplMetal_CreateDeviceObjects(id<MTLDevice> device);
void     ImGui_ImplMetal_DestroyDeviceObjects();
#endif

#endif
