#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/CAMetalLayer.h>
#include "imgui.h"
#include "imgui_impl_metal.h"

static bool g_initialized = false;
static id<MTLDevice> g_device = nil;
static id<MTLCommandQueue> g_commandQueue = nil;
static CAMetalLayer *g_metalLayer = nil;
static MTLRenderPassDescriptor *g_renderPassDescriptor = nil;

static void SetupImGuiStyle() {
    ImGuiStyle &style = ImGui::GetStyle();
    style.WindowRounding = 8.0f;
    style.FrameRounding = 4.0f;
    style.GrabRounding = 4.0f;
    style.Colors[ImGuiCol_WindowBg] = ImVec4(0.1f, 0.1f, 0.1f, 0.95f);
    style.Colors[ImGuiCol_TitleBg] = ImVec4(0.8f, 0.5f, 0.0f, 1.0f);
    style.Colors[ImGuiCol_TitleBgActive] = ImVec4(1.0f, 0.6f, 0.0f, 1.0f);
    style.Colors[ImGuiCol_Button] = ImVec4(0.8f, 0.5f, 0.0f, 0.8f);
    style.Colors[ImGuiCol_ButtonHovered] = ImVec4(1.0f, 0.6f, 0.0f, 1.0f);
    style.Colors[ImGuiCol_ButtonActive] = ImVec4(0.9f, 0.4f, 0.0f, 1.0f);
    style.Colors[ImGuiCol_FrameBg] = ImVec4(0.2f, 0.2f, 0.2f, 0.8f);
    style.Colors[ImGuiCol_Tab] = ImVec4(0.8f, 0.5f, 0.0f, 0.6f);
    style.Colors[ImGuiCol_TabSelected] = ImVec4(1.0f, 0.6f, 0.0f, 1.0f);
}

static UIWindow *GetKeyWindow() {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow)
            return window;
    }
    return nil;
}

static void InitImGui() {
    if (g_initialized)
        return;

    g_device = MTLCreateSystemDefaultDevice();
    if (!g_device)
        return;

    g_commandQueue = [g_device newCommandQueue];

    UIWindow *window = GetKeyWindow();
    if (!window)
        return;

    g_metalLayer = [CAMetalLayer layer];
    g_metalLayer.device = g_device;
    g_metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    g_metalLayer.framebufferOnly = YES;
    g_metalLayer.frame = window.bounds;
    g_metalLayer.opaque = NO;
    [window.rootViewController.view.layer addSublayer:g_metalLayer];

    g_renderPassDescriptor = [MTLRenderPassDescriptor new];

    ImGui::CreateContext();
    ImGuiIO &io = ImGui::GetIO();
    io.DisplaySize = ImVec2(window.bounds.size.width, window.bounds.size.height);
    io.DisplayFramebufferScale = ImVec2(
        (float)[UIScreen mainScreen].scale,
        (float)[UIScreen mainScreen].scale
    );

    ImGui_ImplMetal_Init(g_device);
    SetupImGuiStyle();

    g_initialized = true;
}

static void DrawMenu() {
    ImGui::SetNextWindowSize(ImVec2(320, 400), ImGuiCond_FirstUseEver);
    ImGui::Begin("GOLD Executor", nullptr,
                 ImGuiWindowFlags_NoCollapse);

    if (ImGui::BeginTabBar("MainTabs")) {
        if (ImGui::BeginTabItem("Execute")) {
            static char scriptBuf[4096] = "";
            ImGui::Text("Script:");
            ImGui::InputTextMultiline("##script", scriptBuf, sizeof(scriptBuf),
                                      ImVec2(-1, 200));
            if (ImGui::Button("Execute", ImVec2(-1, 30))) {
                // Execute script callback
            }
            if (ImGui::Button("Clear", ImVec2(-1, 30))) {
                scriptBuf[0] = '\0';
            }
            ImGui::EndTabItem();
        }

        if (ImGui::BeginTabItem("Settings")) {
            static bool espEnabled = false;
            static bool speedHack = false;
            static float walkSpeed = 16.0f;
            static float jumpPower = 50.0f;

            ImGui::Checkbox("ESP", &espEnabled);
            ImGui::Checkbox("Speed Hack", &speedHack);
            ImGui::SliderFloat("Walk Speed", &walkSpeed, 0.0f, 200.0f);
            ImGui::SliderFloat("Jump Power", &jumpPower, 0.0f, 500.0f);
            ImGui::EndTabItem();
        }

        if (ImGui::BeginTabItem("Info")) {
            ImGui::Text("GOLD Executor");
            ImGui::Separator();
            ImGui::Text("Built with Dear ImGui + Metal");
            ImGui::EndTabItem();
        }

        ImGui::EndTabBar();
    }

    ImGui::End();
}

static void RenderFrame() {
    id<CAMetalDrawable> drawable = [g_metalLayer nextDrawable];
    if (!drawable)
        return;

    g_renderPassDescriptor.colorAttachments[0].texture = drawable.texture;
    g_renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
    g_renderPassDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
    g_renderPassDescriptor.colorAttachments[0].clearColor =
        MTLClearColorMake(0.0, 0.0, 0.0, 0.0);

    id<MTLCommandBuffer> commandBuffer = [g_commandQueue commandBuffer];
    id<MTLRenderCommandEncoder> encoder =
        [commandBuffer renderCommandEncoderWithDescriptor:g_renderPassDescriptor];

    ImGui_ImplMetal_NewFrame(g_renderPassDescriptor);
    ImGui::NewFrame();

    DrawMenu();

    ImGui::Render();
    ImGui_ImplMetal_RenderDrawData(ImGui::GetDrawData(), commandBuffer, encoder);

    [encoder endEncoding];
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

extern "C" void RenderImGuiMenu(bool visible) {
    if (!visible)
        return;

    dispatch_async(dispatch_get_main_queue(), ^{
        InitImGui();
        if (g_initialized)
            RenderFrame();
    });
}
