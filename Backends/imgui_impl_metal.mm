#import "imgui_impl_metal.h"
#import "../imgui.h"

#import <Metal/Metal.h>
#import <time.h>

#pragma mark - Metal rendering state

static id<MTLDevice>              g_Device             = nil;
static id<MTLDepthStencilState>   g_DepthStencilState  = nil;
static id<MTLRenderPipelineState> g_PipelineState      = nil;
static id<MTLTexture>             g_FontTexture        = nil;
static id<MTLBuffer>              g_VertexBuffer       = nil;
static id<MTLBuffer>              g_IndexBuffer        = nil;
static int                        g_VertexBufferSize   = 0;
static int                        g_IndexBufferSize    = 0;
static CFTimeInterval             g_Time               = 0;

#pragma mark - Shader source

static NSString* const g_ShaderSource = @""
"#include <metal_stdlib>\n"
"using namespace metal;\n"
"\n"
"struct Uniforms {\n"
"    float4x4 projectionMatrix;\n"
"};\n"
"\n"
"struct VertexIn {\n"
"    float2 position  [[attribute(0)]];\n"
"    float2 texCoords [[attribute(1)]];\n"
"    uchar4 color     [[attribute(2)]];\n"
"};\n"
"\n"
"struct VertexOut {\n"
"    float4 position [[position]];\n"
"    float2 texCoords;\n"
"    float4 color;\n"
"};\n"
"\n"
"vertex VertexOut vertex_main(VertexIn in [[stage_in]],\n"
"                             constant Uniforms &uniforms [[buffer(1)]]) {\n"
"    VertexOut out;\n"
"    out.position = uniforms.projectionMatrix * float4(in.position, 0, 1);\n"
"    out.texCoords = in.texCoords;\n"
"    out.color = float4(in.color) / float4(255.0);\n"
"    return out;\n"
"}\n"
"\n"
"fragment half4 fragment_main(VertexOut in [[stage_in]],\n"
"                             texture2d<half, access::sample> texture [[texture(0)]]) {\n"
"    constexpr sampler linearSampler(coord::normalized, min_filter::linear,\n"
"                                    mag_filter::linear, mip_filter::linear);\n"
"    half4 texColor = texture.sample(linearSampler, in.texCoords);\n"
"    return half4(in.color) * texColor;\n"
"}\n";

#pragma mark - Setup / Teardown

bool ImGui_ImplMetal_Init(id<MTLDevice> device) {
    g_Device = device;
    g_Time = CACurrentMediaTime();
    ImGui_ImplMetal_CreateDeviceObjects(device);
    return true;
}

void ImGui_ImplMetal_Shutdown() {
    ImGui_ImplMetal_DestroyDeviceObjects();
    g_Device = nil;
}

void ImGui_ImplMetal_NewFrame(MTLRenderPassDescriptor* renderPassDescriptor) {
    (void)renderPassDescriptor;
    CFTimeInterval currentTime = CACurrentMediaTime();
    ImGuiIO& io = ImGui::GetIO();
    io.DeltaTime = (float)(currentTime - g_Time);
    if (io.DeltaTime <= 0.0f) io.DeltaTime = 1.0f / 60.0f;
    g_Time = currentTime;
}

#pragma mark - Rendering

void ImGui_ImplMetal_RenderDrawData(ImDrawData* drawData,
                                     id<MTLCommandBuffer> commandBuffer,
                                     id<MTLRenderCommandEncoder> commandEncoder) {
    if (drawData->CmdListsCount == 0) return;
    (void)commandBuffer;

    // Grow vertex / index buffers if needed
    size_t vertexSize = (size_t)drawData->TotalVtxCount * sizeof(ImDrawVert);
    size_t indexSize  = (size_t)drawData->TotalIdxCount * sizeof(ImDrawIdx);

    if (!g_VertexBuffer || (int)vertexSize > g_VertexBufferSize) {
        g_VertexBufferSize = (int)vertexSize + 5000;
        g_VertexBuffer = [g_Device newBufferWithLength:(NSUInteger)g_VertexBufferSize
                                               options:MTLResourceStorageModeShared];
    }
    if (!g_IndexBuffer || (int)indexSize > g_IndexBufferSize) {
        g_IndexBufferSize = (int)indexSize + 5000;
        g_IndexBuffer = [g_Device newBufferWithLength:(NSUInteger)g_IndexBufferSize
                                              options:MTLResourceStorageModeShared];
    }

    // Upload vertex / index data
    ImDrawVert* vtxDst = (ImDrawVert*)[g_VertexBuffer contents];
    ImDrawIdx*  idxDst = (ImDrawIdx*)[g_IndexBuffer  contents];
    for (int n = 0; n < drawData->CmdListsCount; n++) {
        const ImDrawList* cmdList = drawData->CmdLists[n];
        memcpy(vtxDst, cmdList->VtxBuffer.Data, (size_t)cmdList->VtxBuffer.Size * sizeof(ImDrawVert));
        memcpy(idxDst, cmdList->IdxBuffer.Data, (size_t)cmdList->IdxBuffer.Size * sizeof(ImDrawIdx));
        vtxDst += cmdList->VtxBuffer.Size;
        idxDst += cmdList->IdxBuffer.Size;
    }

    // Setup orthographic projection
    float L = drawData->DisplayPos.x;
    float R = drawData->DisplayPos.x + drawData->DisplaySize.x;
    float T = drawData->DisplayPos.y;
    float B = drawData->DisplayPos.y + drawData->DisplaySize.y;
    float proj[4][4] = {
        { 2.0f/(R-L),   0.0f,          0.0f, 0.0f },
        { 0.0f,         2.0f/(T-B),    0.0f, 0.0f },
        { 0.0f,         0.0f,         -1.0f, 0.0f },
        { (R+L)/(L-R),  (T+B)/(B-T),   0.0f, 1.0f },
    };

    [commandEncoder setRenderPipelineState:g_PipelineState];
    [commandEncoder setVertexBuffer:g_VertexBuffer offset:0 atIndex:0];
    [commandEncoder setVertexBytes:&proj length:sizeof(proj) atIndex:1];
    [commandEncoder setDepthStencilState:g_DepthStencilState];

    // Render command lists
    ImVec2 clipOff = drawData->DisplayPos;
    size_t vtxOffset = 0;
    size_t idxOffset = 0;
    for (int n = 0; n < drawData->CmdListsCount; n++) {
        const ImDrawList* cmdList = drawData->CmdLists[n];
        for (int ci = 0; ci < cmdList->CmdBuffer.Size; ci++) {
            const ImDrawCmd* pcmd = &cmdList->CmdBuffer[ci];
            if (pcmd->UserCallback) {
                pcmd->UserCallback(cmdList, pcmd);
            } else {
                float cx = pcmd->ClipRect.x - clipOff.x;
                float cy = pcmd->ClipRect.y - clipOff.y;
                float cw = pcmd->ClipRect.z - clipOff.x;
                float ch = pcmd->ClipRect.w - clipOff.y;
                if (cw <= cx || ch <= cy) continue;

                MTLScissorRect scissor;
                scissor.x      = (NSUInteger)cx;
                scissor.y      = (NSUInteger)cy;
                scissor.width  = (NSUInteger)(cw - cx);
                scissor.height = (NSUInteger)(ch - cy);
                [commandEncoder setScissorRect:scissor];

                if (pcmd->TextureId) {
                    [commandEncoder setFragmentTexture:(__bridge id<MTLTexture>)(pcmd->TextureId)
                                               atIndex:0];
                }
                [commandEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle
                                           indexCount:pcmd->ElemCount
                                            indexType:sizeof(ImDrawIdx) == 2 ? MTLIndexTypeUInt16 : MTLIndexTypeUInt32
                                          indexBuffer:g_IndexBuffer
                                    indexBufferOffset:idxOffset * sizeof(ImDrawIdx)];
            }
            idxOffset += pcmd->ElemCount;
        }
        vtxOffset += cmdList->VtxBuffer.Size;
    }
}

#pragma mark - Device Objects

bool ImGui_ImplMetal_CreateFontsTexture(id<MTLDevice> device) {
    ImGuiIO& io = ImGui::GetIO();
    unsigned char* pixels;
    int width, height;
    io.Fonts->GetTexDataAsRGBA32(&pixels, &width, &height);

    MTLTextureDescriptor* desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                                                                    width:(NSUInteger)width
                                                                                   height:(NSUInteger)height
                                                                                mipmapped:NO];
    desc.usage = MTLTextureUsageShaderRead;
    desc.storageMode = MTLStorageModeShared;
    g_FontTexture = [device newTextureWithDescriptor:desc];
    [g_FontTexture replaceRegion:MTLRegionMake2D(0, 0, (NSUInteger)width, (NSUInteger)height)
                     mipmapLevel:0
                       withBytes:pixels
                     bytesPerRow:(NSUInteger)(width * 4)];
    io.Fonts->SetTexID((__bridge void*)g_FontTexture);
    return true;
}

void ImGui_ImplMetal_DestroyFontsTexture() {
    g_FontTexture = nil;
    ImGui::GetIO().Fonts->SetTexID(nullptr);
}

bool ImGui_ImplMetal_CreateDeviceObjects(id<MTLDevice> device) {
    NSError* error = nil;
    id<MTLLibrary> library = [device newLibraryWithSource:g_ShaderSource options:nil error:&error];
    if (!library) return false;

    id<MTLFunction> vertexFunction   = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"fragment_main"];

    // Vertex descriptor matching ImDrawVert
    MTLVertexDescriptor* vertexDescriptor = [MTLVertexDescriptor vertexDescriptor];
    vertexDescriptor.attributes[0].offset  = offsetof(ImDrawVert, pos);
    vertexDescriptor.attributes[0].format  = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.attributes[1].offset  = offsetof(ImDrawVert, uv);
    vertexDescriptor.attributes[1].format  = MTLVertexFormatFloat2;
    vertexDescriptor.attributes[1].bufferIndex = 0;
    vertexDescriptor.attributes[2].offset  = offsetof(ImDrawVert, col);
    vertexDescriptor.attributes[2].format  = MTLVertexFormatUChar4;
    vertexDescriptor.attributes[2].bufferIndex = 0;
    vertexDescriptor.layouts[0].stride     = sizeof(ImDrawVert);
    vertexDescriptor.layouts[0].stepRate   = 1;
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;

    MTLRenderPipelineDescriptor* pipelineDesc = [[MTLRenderPipelineDescriptor alloc] init];
    pipelineDesc.vertexFunction   = vertexFunction;
    pipelineDesc.fragmentFunction = fragmentFunction;
    pipelineDesc.vertexDescriptor = vertexDescriptor;
    pipelineDesc.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    pipelineDesc.colorAttachments[0].blendingEnabled           = YES;
    pipelineDesc.colorAttachments[0].rgbBlendOperation         = MTLBlendOperationAdd;
    pipelineDesc.colorAttachments[0].alphaBlendOperation       = MTLBlendOperationAdd;
    pipelineDesc.colorAttachments[0].sourceRGBBlendFactor      = MTLBlendFactorSourceAlpha;
    pipelineDesc.colorAttachments[0].sourceAlphaBlendFactor    = MTLBlendFactorSourceAlpha;
    pipelineDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    pipelineDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    pipelineDesc.depthAttachmentPixelFormat = MTLPixelFormatInvalid;

    g_PipelineState = [device newRenderPipelineStateWithDescriptor:pipelineDesc error:&error];
    if (!g_PipelineState) return false;

    MTLDepthStencilDescriptor* dsDesc = [[MTLDepthStencilDescriptor alloc] init];
    dsDesc.depthWriteEnabled = NO;
    dsDesc.depthCompareFunction = MTLCompareFunctionAlways;
    g_DepthStencilState = [device newDepthStencilStateWithDescriptor:dsDesc];

    ImGui_ImplMetal_CreateFontsTexture(device);
    return true;
}

void ImGui_ImplMetal_DestroyDeviceObjects() {
    ImGui_ImplMetal_DestroyFontsTexture();
    g_PipelineState     = nil;
    g_DepthStencilState = nil;
    g_VertexBuffer      = nil;
    g_IndexBuffer       = nil;
}
