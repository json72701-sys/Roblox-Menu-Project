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

// Script execution hook — connect your script engine here
typedef void (*ScriptExecFunc)(const char *script);
static ScriptExecFunc g_scriptExecCallback = nullptr;

extern "C" void ElxrScriptz_SetExecuteCallback(ScriptExecFunc callback) {
    g_scriptExecCallback = callback;
}

static void SetupImGuiStyle() {
    ImGuiStyle &style = ImGui::GetStyle();

    style.WindowRounding = 10.0f;
    style.FrameRounding = 6.0f;
    style.GrabRounding = 6.0f;
    style.TabRounding = 6.0f;
    style.ChildRounding = 6.0f;
    style.PopupRounding = 6.0f;
    style.ScrollbarRounding = 6.0f;
    style.WindowPadding = ImVec2(12, 12);
    style.FramePadding = ImVec2(8, 5);
    style.ItemSpacing = ImVec2(8, 8);
    style.WindowBorderSize = 1.0f;
    style.FrameBorderSize = 0.0f;
    style.WindowTitleAlign = ImVec2(0.5f, 0.5f);

    ImVec4 *c = style.Colors;

    // Background
    c[ImGuiCol_WindowBg]   = ImVec4(0.06f, 0.06f, 0.12f, 0.97f);
    c[ImGuiCol_ChildBg]    = ImVec4(0.08f, 0.08f, 0.14f, 0.90f);
    c[ImGuiCol_PopupBg]    = ImVec4(0.08f, 0.08f, 0.14f, 0.97f);

    // Title bar
    c[ImGuiCol_TitleBg]       = ImVec4(0.10f, 0.20f, 0.40f, 1.00f);
    c[ImGuiCol_TitleBgActive] = ImVec4(0.15f, 0.35f, 0.65f, 1.00f);

    // Borders
    c[ImGuiCol_Border]        = ImVec4(0.25f, 0.50f, 0.85f, 0.40f);
    c[ImGuiCol_BorderShadow]  = ImVec4(0.00f, 0.00f, 0.00f, 0.00f);

    // Buttons
    c[ImGuiCol_Button]        = ImVec4(0.15f, 0.35f, 0.65f, 0.85f);
    c[ImGuiCol_ButtonHovered]  = ImVec4(0.25f, 0.50f, 0.85f, 1.00f);
    c[ImGuiCol_ButtonActive]   = ImVec4(0.10f, 0.30f, 0.55f, 1.00f);

    // Frames (input fields)
    c[ImGuiCol_FrameBg]        = ImVec4(0.10f, 0.10f, 0.18f, 0.90f);
    c[ImGuiCol_FrameBgHovered] = ImVec4(0.15f, 0.15f, 0.25f, 1.00f);
    c[ImGuiCol_FrameBgActive]  = ImVec4(0.12f, 0.12f, 0.22f, 1.00f);

    // Tabs
    c[ImGuiCol_Tab]                = ImVec4(0.12f, 0.25f, 0.45f, 0.80f);
    c[ImGuiCol_TabSelected]        = ImVec4(0.20f, 0.45f, 0.80f, 1.00f);
    c[ImGuiCol_TabHovered]         = ImVec4(0.25f, 0.50f, 0.85f, 0.90f);
    c[ImGuiCol_TabDimmed]          = ImVec4(0.08f, 0.15f, 0.30f, 0.70f);
    c[ImGuiCol_TabDimmedSelected]  = ImVec4(0.15f, 0.30f, 0.55f, 1.00f);

    // Sliders / Grabs
    c[ImGuiCol_SliderGrab]       = ImVec4(0.30f, 0.55f, 0.90f, 1.00f);
    c[ImGuiCol_SliderGrabActive] = ImVec4(0.40f, 0.65f, 1.00f, 1.00f);

    // Checkmark
    c[ImGuiCol_CheckMark] = ImVec4(0.40f, 0.75f, 1.00f, 1.00f);

    // Scrollbar
    c[ImGuiCol_ScrollbarBg]          = ImVec4(0.05f, 0.05f, 0.10f, 0.50f);
    c[ImGuiCol_ScrollbarGrab]        = ImVec4(0.20f, 0.40f, 0.70f, 0.60f);
    c[ImGuiCol_ScrollbarGrabHovered] = ImVec4(0.25f, 0.50f, 0.85f, 0.80f);
    c[ImGuiCol_ScrollbarGrabActive]  = ImVec4(0.30f, 0.55f, 0.90f, 1.00f);

    // Header (collapsing headers, selectable)
    c[ImGuiCol_Header]        = ImVec4(0.15f, 0.30f, 0.55f, 0.70f);
    c[ImGuiCol_HeaderHovered] = ImVec4(0.20f, 0.40f, 0.70f, 0.80f);
    c[ImGuiCol_HeaderActive]  = ImVec4(0.25f, 0.50f, 0.85f, 1.00f);

    // Separator
    c[ImGuiCol_Separator]        = ImVec4(0.20f, 0.40f, 0.70f, 0.40f);
    c[ImGuiCol_SeparatorHovered] = ImVec4(0.25f, 0.50f, 0.85f, 0.70f);
    c[ImGuiCol_SeparatorActive]  = ImVec4(0.30f, 0.55f, 0.90f, 1.00f);

    // Text
    c[ImGuiCol_Text]         = ImVec4(0.90f, 0.93f, 1.00f, 1.00f);
    c[ImGuiCol_TextDisabled] = ImVec4(0.45f, 0.50f, 0.60f, 1.00f);
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

static bool g_needsCenter = true;

static void DrawMenu() {
    ImVec2 display = ImGui::GetIO().DisplaySize;
    float winW = display.x * 0.85f;
    if (winW > 340.0f) winW = 340.0f;
    float winH = display.y * 0.65f;
    if (winH > 440.0f) winH = 440.0f;

    if (g_needsCenter) {
        ImGui::SetNextWindowPos(
            ImVec2((display.x - winW) * 0.5f, (display.y - winH) * 0.5f),
            ImGuiCond_Always
        );
        ImGui::SetNextWindowSize(ImVec2(winW, winH), ImGuiCond_Always);
        g_needsCenter = false;
    }

    ImGui::Begin("ElxrScriptz Executor", nullptr,
                 ImGuiWindowFlags_NoCollapse);

    static char scriptBuf[16384] = "";
    static char statusMsg[256] = "";
    static float statusTimer = 0.0f;

    if (ImGui::BeginTabBar("##Tabs", ImGuiTabBarFlags_FittingPolicyResizeDown)) {

        // --- Execute Tab ---
        if (ImGui::BeginTabItem("Execute")) {
            ImGui::Spacing();
            ImGui::TextColored(ImVec4(0.4f, 0.8f, 1.0f, 1.0f), "Paste or type your script:");
            ImGui::Spacing();

            ImGui::InputTextMultiline("##scriptbox", scriptBuf, sizeof(scriptBuf),
                                      ImVec2(-1, 220),
                                      ImGuiInputTextFlags_AllowTabInput);

            ImGui::Spacing();

            float btnWidth = (ImGui::GetContentRegionAvail().x - 16) / 3.0f;

            if (ImGui::Button("Execute", ImVec2(btnWidth, 32))) {
                if (scriptBuf[0] != '\0') {
                    if (g_scriptExecCallback) {
                        g_scriptExecCallback(scriptBuf);
                        snprintf(statusMsg, sizeof(statusMsg), "Script executed.");
                    } else {
                        snprintf(statusMsg, sizeof(statusMsg),
                                 "No script engine connected.");
                    }
                } else {
                    snprintf(statusMsg, sizeof(statusMsg), "Script box is empty.");
                }
                statusTimer = 3.0f;
            }

            ImGui::SameLine();
            if (ImGui::Button("Clear", ImVec2(btnWidth, 32))) {
                scriptBuf[0] = '\0';
                snprintf(statusMsg, sizeof(statusMsg), "Cleared.");
                statusTimer = 2.0f;
            }

            ImGui::SameLine();
            if (ImGui::Button("Paste", ImVec2(btnWidth, 32))) {
                UIPasteboard *pb = [UIPasteboard generalPasteboard];
                if (pb.string) {
                    const char *clip = [pb.string UTF8String];
                    size_t len = strlen(clip);
                    if (len >= sizeof(scriptBuf))
                        len = sizeof(scriptBuf) - 1;
                    memcpy(scriptBuf, clip, len);
                    scriptBuf[len] = '\0';
                    snprintf(statusMsg, sizeof(statusMsg), "Pasted from clipboard.");
                } else {
                    snprintf(statusMsg, sizeof(statusMsg), "Clipboard is empty.");
                }
                statusTimer = 2.0f;
            }

            if (statusTimer > 0.0f) {
                ImGui::Spacing();
                ImGui::TextColored(ImVec4(0.5f, 0.9f, 0.5f, statusTimer / 3.0f),
                                   "%s", statusMsg);
                statusTimer -= ImGui::GetIO().DeltaTime;
            }

            ImGui::EndTabItem();
        }

        // --- Settings Tab ---
        if (ImGui::BeginTabItem("Settings")) {
            ImGui::Spacing();
            ImGui::TextColored(ImVec4(0.4f, 0.8f, 1.0f, 1.0f), "Player Settings");
            ImGui::Separator();
            ImGui::Spacing();

            static float walkSpeed = 16.0f;
            static float jumpPower = 50.0f;
            static float gravity = 196.2f;

            ImGui::SliderFloat("Walk Speed", &walkSpeed, 0.0f, 500.0f, "%.0f");
            ImGui::SliderFloat("Jump Power", &jumpPower, 0.0f, 500.0f, "%.0f");
            ImGui::SliderFloat("Gravity", &gravity, 0.0f, 1000.0f, "%.1f");

            ImGui::Spacing();
            ImGui::TextColored(ImVec4(0.4f, 0.8f, 1.0f, 1.0f), "Visual Settings");
            ImGui::Separator();
            ImGui::Spacing();

            static bool espEnabled = false;
            static bool fullbright = false;
            static bool noclip = false;
            static bool infiniteJump = false;

            ImGui::Checkbox("ESP", &espEnabled);
            ImGui::Checkbox("Fullbright", &fullbright);
            ImGui::Checkbox("Noclip", &noclip);
            ImGui::Checkbox("Infinite Jump", &infiniteJump);

            ImGui::Spacing();
            if (ImGui::Button("Apply Settings", ImVec2(-1, 32))) {
                snprintf(statusMsg, sizeof(statusMsg), "Settings applied.");
                statusTimer = 2.0f;
            }

            ImGui::EndTabItem();
        }

        // --- Info Tab ---
        if (ImGui::BeginTabItem("Info")) {
            ImGui::Spacing();

            ImGui::TextColored(ImVec4(0.4f, 0.8f, 1.0f, 1.0f), "ElxrScriptz Executor");
            ImGui::Separator();
            ImGui::Spacing();

            ImGui::Text("Version:  1.0.0");
            ImGui::Text("Platform: iOS (arm64)");
            ImGui::Text("Renderer: Metal + Dear ImGui");
            ImGui::Spacing();
            ImGui::Separator();
            ImGui::Spacing();
            ImGui::TextWrapped(
                "Tap the floating ElxrScriptz button to toggle this menu. "
                "Drag it to reposition. Use the Execute tab to run scripts "
                "and the Settings tab to configure options."
            );

            ImGui::EndTabItem();
        }

        ImGui::EndTabBar();
    }

    ImGui::End();
}

static void RenderFrame() {
    UIWindow *window = GetKeyWindow();
    if (window) {
        CGRect bounds = [UIScreen mainScreen].bounds;
        g_metalLayer.frame = bounds;
        ImGuiIO &io = ImGui::GetIO();
        io.DisplaySize = ImVec2(bounds.size.width, bounds.size.height);
        io.DisplayFramebufferScale = ImVec2(
            (float)[UIScreen mainScreen].scale,
            (float)[UIScreen mainScreen].scale
        );
    }

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
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!visible) {
            if (g_metalLayer)
                g_metalLayer.hidden = YES;
            return;
        }

        InitImGui();
        if (g_initialized) {
            g_metalLayer.hidden = NO;
            g_needsCenter = true;
            RenderFrame();
        }
    });
}
