#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>
#include "imgui.h"
#include "Backends/imgui_impl_metal.h"
#include "Engine/Engine.hpp"

extern "C" void RenderImGuiMenu(bool visible);

static bool              isMenuVisible   = false;
static bool              imguiReady      = false;
static id<MTLDevice>     g_MetalDevice   = nil;

#pragma mark - ImGui Initialization

static void SetupImGui() {
    if (imguiReady) return;

    g_MetalDevice = MTLCreateSystemDefaultDevice();
    if (!g_MetalDevice) return;

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();

    ImGuiIO& io = ImGui::GetIO();
    CGRect bounds = [[UIScreen mainScreen] bounds];
    CGFloat scale = [[UIScreen mainScreen] scale];
    io.DisplaySize = ImVec2(bounds.size.width * scale, bounds.size.height * scale);
    io.DisplayFramebufferScale = ImVec2(1.0f, 1.0f);

    // Dark gold theme
    ImGuiStyle& style = ImGui::GetStyle();
    style.WindowRounding    = 8.0f;
    style.FrameRounding     = 4.0f;
    style.GrabRounding      = 4.0f;
    style.ScrollbarRounding = 4.0f;
    style.WindowBorderSize  = 1.0f;

    ImVec4* colors = style.Colors;
    colors[ImGuiCol_WindowBg]           = ImVec4(0.08f, 0.08f, 0.10f, 0.95f);
    colors[ImGuiCol_TitleBg]            = ImVec4(0.50f, 0.35f, 0.00f, 1.00f);
    colors[ImGuiCol_TitleBgActive]      = ImVec4(0.70f, 0.50f, 0.00f, 1.00f);
    colors[ImGuiCol_Button]             = ImVec4(0.45f, 0.30f, 0.00f, 1.00f);
    colors[ImGuiCol_ButtonHovered]      = ImVec4(0.65f, 0.45f, 0.00f, 1.00f);
    colors[ImGuiCol_ButtonActive]       = ImVec4(0.80f, 0.55f, 0.00f, 1.00f);
    colors[ImGuiCol_FrameBg]            = ImVec4(0.15f, 0.15f, 0.18f, 1.00f);
    colors[ImGuiCol_FrameBgHovered]     = ImVec4(0.25f, 0.25f, 0.28f, 1.00f);
    colors[ImGuiCol_FrameBgActive]      = ImVec4(0.35f, 0.30f, 0.10f, 1.00f);
    colors[ImGuiCol_SliderGrab]         = ImVec4(0.70f, 0.50f, 0.00f, 1.00f);
    colors[ImGuiCol_SliderGrabActive]   = ImVec4(0.90f, 0.65f, 0.00f, 1.00f);
    colors[ImGuiCol_CheckMark]          = ImVec4(1.00f, 0.75f, 0.00f, 1.00f);
    colors[ImGuiCol_Separator]          = ImVec4(0.40f, 0.30f, 0.00f, 0.60f);
    colors[ImGuiCol_Text]              = ImVec4(1.00f, 1.00f, 1.00f, 1.00f);

    ImGui_ImplMetal_Init(g_MetalDevice);
    imguiReady = true;
}

#pragma mark - Draggable Logo Button

@interface DraggableLogo : UIButton
@end

@implementation DraggableLogo
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentLocation = [touch locationInView:self.superview];
    self.center = currentLocation;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    if (touch.tapCount == 1) {
        isMenuVisible = !isMenuVisible;
    }
}
@end

#pragma mark - Render Loop

static void RenderLoop() {
    if (!imguiReady) {
        SetupImGui();
        return;
    }

    ImGui_ImplMetal_NewFrame(nil);
    ImGui::NewFrame();

    RenderImGuiMenu(isMenuVisible);

    ImGui::Render();
    // The actual Metal draw calls happen when the host app renders.
    // ImGui_ImplMetal_RenderDrawData is called from the Metal hook.
}

#pragma mark - Entry Point

__attribute__((constructor))
static void initialize() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        // Initialize ImGui on first opportunity
        SetupImGui();

        // Find the key window and add the toggle button
        UIWindow *win = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) { win = window; break; }
        }

        if (win) {
            DraggableLogo *btn = [DraggableLogo buttonWithType:UIButtonTypeCustom];
            [btn setFrame:CGRectMake(100, 100, 60, 60)];
            [btn setTitle:@"GOLD" forState:UIControlStateNormal];
            [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [btn setBackgroundColor:[UIColor colorWithRed:0.7 green:0.5 blue:0.0 alpha:1.0]];
            btn.layer.cornerRadius = 30;
            btn.layer.zPosition = 10000;
            btn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
            [win addSubview:btn];
        }

        // Start the render loop on a display link
        // This pumps ImGui frames in sync with the display
        [NSTimer scheduledTimerWithTimeInterval:1.0/60.0 repeats:YES block:^(NSTimer *timer) {
            RenderLoop();
        }];
    });
}
