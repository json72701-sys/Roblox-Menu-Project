#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/CAMetalLayer.h>
#include "imgui.h"
#include "imgui_impl_metal.h"

#include "lua.h"
#include "lualib.h"
#include "luacode.h"

static bool g_initialized = false;
static bool g_menuVisible = false;
static id<MTLDevice> g_device = nil;
static id<MTLCommandQueue> g_commandQueue = nil;
static CAMetalLayer *g_metalLayer = nil;
static MTLRenderPassDescriptor *g_renderPassDescriptor = nil;
static CADisplayLink *g_displayLink = nil;

// Keyboard support
static UITextField *g_hiddenTextField = nil;
static bool g_wantKeyboard = false;
static bool g_keyboardOpen = false;

// Luau VM
static lua_State *g_luauState = nullptr;

// Output log for script results
static char g_outputLog[8192] = "";
static int g_outputLen = 0;

static void AppendOutput(const char *text) {
    int len = (int)strlen(text);
    if (g_outputLen + len + 1 >= (int)sizeof(g_outputLog)) {
        // Shift buffer: keep last half
        int keep = (int)sizeof(g_outputLog) / 2;
        memmove(g_outputLog, g_outputLog + g_outputLen - keep, keep);
        g_outputLen = keep;
    }
    memcpy(g_outputLog + g_outputLen, text, len);
    g_outputLen += len;
    g_outputLog[g_outputLen] = '\0';
}

static int LuauPrint(lua_State *L) {
    int n = lua_gettop(L);
    for (int i = 1; i <= n; i++) {
        size_t len;
        const char *s = luaL_tolstring(L, i, &len);
        if (s) {
            if (i > 1) AppendOutput("\t");
            AppendOutput(s);
        }
        lua_pop(L, 1);
    }
    AppendOutput("\n");
    return 0;
}

static int LuauWarn(lua_State *L) {
    const char *msg = luaL_checkstring(L, 1);
    AppendOutput("[warn] ");
    AppendOutput(msg);
    AppendOutput("\n");
    return 0;
}

static void InitLuau() {
    if (g_luauState) return;
    g_luauState = luaL_newstate();
    luaL_openlibs(g_luauState);

    // Register custom print
    lua_pushcfunction(g_luauState, LuauPrint, "print");
    lua_setglobal(g_luauState, "print");

    lua_pushcfunction(g_luauState, LuauWarn, "warn");
    lua_setglobal(g_luauState, "warn");
}

static void ExecuteLuauScript(const char *script) {
    if (!g_luauState) InitLuau();

    lua_CompileOptions opts = {};
    opts.optimizationLevel = 1;
    opts.debugLevel = 1;

    size_t bytecodeSize = 0;
    char *bytecode = luau_compile(script, strlen(script), &opts, &bytecodeSize);

    if (!bytecode) {
        AppendOutput("[error] Compilation failed\n");
        return;
    }

    int loadResult = luau_load(g_luauState, "=ElxrScriptz", bytecode, bytecodeSize, 0);
    free(bytecode);

    if (loadResult != 0) {
        const char *err = lua_tostring(g_luauState, -1);
        AppendOutput("[error] ");
        AppendOutput(err ? err : "Unknown load error");
        AppendOutput("\n");
        lua_pop(g_luauState, 1);
        return;
    }

    int status = lua_pcall(g_luauState, 0, 0, 0);
    if (status != 0) {
        const char *err = lua_tostring(g_luauState, -1);
        AppendOutput("[error] ");
        AppendOutput(err ? err : "Unknown runtime error");
        AppendOutput("\n");
        lua_pop(g_luauState, 1);
    }
}

// Color customization (user-editable from Settings tab)
static ImVec4 g_colText       = ImVec4(0.90f, 0.93f, 1.00f, 1.00f);
static ImVec4 g_colWindowBg   = ImVec4(0.06f, 0.06f, 0.12f, 0.97f);
static ImVec4 g_colButton     = ImVec4(0.15f, 0.35f, 0.65f, 0.85f);
static ImVec4 g_colBorder     = ImVec4(0.25f, 0.50f, 0.85f, 0.40f);
static ImVec4 g_colTitleBg    = ImVec4(0.15f, 0.35f, 0.65f, 1.00f);
static ImVec4 g_colTab        = ImVec4(0.20f, 0.45f, 0.80f, 1.00f);
static ImVec4 g_colFrameBg    = ImVec4(0.10f, 0.10f, 0.18f, 0.90f);
static ImVec4 g_colAccent     = ImVec4(0.40f, 0.80f, 1.00f, 1.00f);

// Touch overlay view that forwards touch events to ImGui
@interface ImGuiTouchView : UIView <UITextFieldDelegate>
@end

@implementation ImGuiTouchView

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint loc = [touch locationInView:self];
    ImGuiIO &io = ImGui::GetIO();
    io.AddMousePosEvent(loc.x, loc.y);
    io.AddMouseButtonEvent(0, true);
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint loc = [touch locationInView:self];
    ImGuiIO &io = ImGui::GetIO();
    io.AddMousePosEvent(loc.x, loc.y);
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint loc = [touch locationInView:self];
    ImGuiIO &io = ImGui::GetIO();
    io.AddMousePosEvent(loc.x, loc.y);
    io.AddMouseButtonEvent(0, false);

    // Check if ImGui wants keyboard (user tapped an input field)
    if (io.WantTextInput && !g_keyboardOpen) {
        g_wantKeyboard = true;
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    ImGuiIO &io = ImGui::GetIO();
    io.AddMouseButtonEvent(0, false);
}

- (BOOL)canBecomeFirstResponder { return YES; }

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range
    replacementString:(NSString *)string {
    ImGuiIO &io = ImGui::GetIO();
    if ([string length] > 0) {
        const char *utf8 = [string UTF8String];
        io.AddInputCharactersUTF8(utf8);
    } else if (range.length > 0) {
        io.AddKeyEvent(ImGuiKey_Backspace, true);
        io.AddKeyEvent(ImGuiKey_Backspace, false);
    }
    return NO;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    ImGuiIO &io = ImGui::GetIO();
    io.AddKeyEvent(ImGuiKey_Enter, true);
    io.AddKeyEvent(ImGuiKey_Enter, false);
    return NO;
}

@end

static ImGuiTouchView *g_touchView = nil;

typedef void (*ScriptExecFunc)(const char *script);
static ScriptExecFunc g_scriptExecCallback = nullptr;

extern "C" void ElxrScriptz_SetExecuteCallback(ScriptExecFunc callback) {
    g_scriptExecCallback = callback;
}

static void ApplyCustomColors() {
    ImVec4 *c = ImGui::GetStyle().Colors;

    c[ImGuiCol_Text]         = g_colText;
    c[ImGuiCol_TextDisabled] = ImVec4(g_colText.x * 0.5f, g_colText.y * 0.5f,
                                       g_colText.z * 0.5f, 1.0f);

    c[ImGuiCol_WindowBg] = g_colWindowBg;
    c[ImGuiCol_ChildBg]  = ImVec4(g_colWindowBg.x + 0.02f, g_colWindowBg.y + 0.02f,
                                   g_colWindowBg.z + 0.02f, 0.90f);
    c[ImGuiCol_PopupBg]  = g_colWindowBg;

    c[ImGuiCol_TitleBg]       = ImVec4(g_colTitleBg.x * 0.65f, g_colTitleBg.y * 0.65f,
                                        g_colTitleBg.z * 0.65f, 1.0f);
    c[ImGuiCol_TitleBgActive] = g_colTitleBg;

    c[ImGuiCol_Border]       = g_colBorder;
    c[ImGuiCol_BorderShadow] = ImVec4(0, 0, 0, 0);

    c[ImGuiCol_Button]        = g_colButton;
    c[ImGuiCol_ButtonHovered] = ImVec4(g_colButton.x + 0.10f, g_colButton.y + 0.15f,
                                        g_colButton.z + 0.20f, 1.0f);
    c[ImGuiCol_ButtonActive]  = ImVec4(g_colButton.x - 0.05f, g_colButton.y - 0.05f,
                                        g_colButton.z - 0.10f, 1.0f);

    c[ImGuiCol_FrameBg]        = g_colFrameBg;
    c[ImGuiCol_FrameBgHovered] = ImVec4(g_colFrameBg.x + 0.05f, g_colFrameBg.y + 0.05f,
                                         g_colFrameBg.z + 0.07f, 1.0f);
    c[ImGuiCol_FrameBgActive]  = ImVec4(g_colFrameBg.x + 0.02f, g_colFrameBg.y + 0.02f,
                                         g_colFrameBg.z + 0.04f, 1.0f);

    c[ImGuiCol_Tab]               = ImVec4(g_colTab.x * 0.6f, g_colTab.y * 0.6f,
                                            g_colTab.z * 0.6f, 0.80f);
    c[ImGuiCol_TabSelected]       = g_colTab;
    c[ImGuiCol_TabHovered]        = ImVec4(g_colTab.x + 0.05f, g_colTab.y + 0.05f,
                                            g_colTab.z + 0.05f, 0.90f);
    c[ImGuiCol_TabDimmed]         = ImVec4(g_colTab.x * 0.4f, g_colTab.y * 0.4f,
                                            g_colTab.z * 0.4f, 0.70f);
    c[ImGuiCol_TabDimmedSelected] = ImVec4(g_colTab.x * 0.75f, g_colTab.y * 0.75f,
                                            g_colTab.z * 0.75f, 1.0f);

    c[ImGuiCol_SliderGrab]       = g_colAccent;
    c[ImGuiCol_SliderGrabActive] = ImVec4(g_colAccent.x + 0.1f, g_colAccent.y + 0.1f,
                                           g_colAccent.z + 0.1f, 1.0f);
    c[ImGuiCol_CheckMark]        = g_colAccent;

    c[ImGuiCol_ScrollbarBg]          = ImVec4(g_colWindowBg.x, g_colWindowBg.y,
                                               g_colWindowBg.z, 0.50f);
    c[ImGuiCol_ScrollbarGrab]        = ImVec4(g_colAccent.x * 0.5f, g_colAccent.y * 0.5f,
                                               g_colAccent.z * 0.5f, 0.60f);
    c[ImGuiCol_ScrollbarGrabHovered] = ImVec4(g_colAccent.x * 0.6f, g_colAccent.y * 0.6f,
                                               g_colAccent.z * 0.6f, 0.80f);
    c[ImGuiCol_ScrollbarGrabActive]  = g_colAccent;

    c[ImGuiCol_Header]        = ImVec4(g_colButton.x, g_colButton.y, g_colButton.z, 0.70f);
    c[ImGuiCol_HeaderHovered] = ImVec4(g_colButton.x + 0.05f, g_colButton.y + 0.05f,
                                        g_colButton.z + 0.05f, 0.80f);
    c[ImGuiCol_HeaderActive]  = ImVec4(g_colButton.x + 0.10f, g_colButton.y + 0.15f,
                                        g_colButton.z + 0.20f, 1.0f);

    c[ImGuiCol_Separator]        = g_colBorder;
    c[ImGuiCol_SeparatorHovered] = ImVec4(g_colBorder.x + 0.05f, g_colBorder.y + 0.1f,
                                           g_colBorder.z + 0.15f, 0.70f);
    c[ImGuiCol_SeparatorActive]  = g_colAccent;
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

    ApplyCustomColors();
}

static UIWindow *GetKeyWindow() {
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow)
            return window;
    }
    return nil;
}

static void RenderFrame();

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

    CGFloat scale = [UIScreen mainScreen].scale;
    CGRect screenBounds = [UIScreen mainScreen].bounds;

    g_metalLayer = [CAMetalLayer layer];
    g_metalLayer.device = g_device;
    g_metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    g_metalLayer.framebufferOnly = YES;
    g_metalLayer.frame = screenBounds;
    g_metalLayer.contentsScale = scale;
    g_metalLayer.drawableSize = CGSizeMake(
        screenBounds.size.width * scale,
        screenBounds.size.height * scale
    );
    g_metalLayer.opaque = NO;
    g_metalLayer.hidden = YES;

    UIView *rootView = window.rootViewController.view;
    [rootView.layer addSublayer:g_metalLayer];

    g_touchView = [[ImGuiTouchView alloc] initWithFrame:screenBounds];
    g_touchView.backgroundColor = [UIColor clearColor];
    g_touchView.multipleTouchEnabled = YES;
    g_touchView.userInteractionEnabled = YES;
    g_touchView.hidden = YES;
    [rootView addSubview:g_touchView];

    // Hidden text field for keyboard input
    g_hiddenTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, -100, 1, 1)];
    g_hiddenTextField.autocorrectionType = UITextAutocorrectionTypeNo;
    g_hiddenTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    g_hiddenTextField.spellCheckingType = UITextSpellCheckingTypeNo;
    g_hiddenTextField.delegate = g_touchView;
    g_hiddenTextField.text = @" ";
    [g_touchView addSubview:g_hiddenTextField];

    g_renderPassDescriptor = [MTLRenderPassDescriptor new];

    ImGui::CreateContext();
    ImGuiIO &io = ImGui::GetIO();
    io.IniFilename = nullptr;
    io.DisplaySize = ImVec2(screenBounds.size.width, screenBounds.size.height);
    io.DisplayFramebufferScale = ImVec2((float)scale, (float)scale);

    ImGui_ImplMetal_Init(g_device);
    SetupImGuiStyle();

    g_displayLink = [CADisplayLink displayLinkWithTarget:[NSBlockOperation blockOperationWithBlock:^{
        if (g_menuVisible)
            RenderFrame();
    }] selector:@selector(main)];
    [g_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

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
        float posX = (display.x - winW) * 0.5f;
        float posY = (display.y - winH) * 0.5f;
        if (posX < 0) posX = 10;
        if (posY < 0) posY = 10;
        ImGui::SetNextWindowPos(ImVec2(posX, posY), ImGuiCond_Always);
        ImGui::SetNextWindowSize(ImVec2(winW, winH), ImGuiCond_Always);
        g_needsCenter = false;
    }

    // Apply user color choices every frame
    ApplyCustomColors();

    ImGui::Begin("ElxrScriptz Executor", nullptr,
                 ImGuiWindowFlags_NoCollapse);

    static char scriptBuf[16384] = "";
    static char statusMsg[256] = "";
    static float statusTimer = 0.0f;

    if (ImGui::BeginTabBar("##Tabs", ImGuiTabBarFlags_FittingPolicyResizeDown)) {

        // --- Execute Tab ---
        if (ImGui::BeginTabItem("Execute")) {
            ImGui::Spacing();
            ImGui::TextColored(g_colAccent, "Paste or type your script:");
            ImGui::Spacing();

            float textBoxH = ImGui::GetContentRegionAvail().y - 80;
            if (textBoxH < 100) textBoxH = 100;
            ImGui::InputTextMultiline("##scriptbox", scriptBuf, sizeof(scriptBuf),
                                      ImVec2(-1, textBoxH),
                                      ImGuiInputTextFlags_AllowTabInput);

            // Show keyboard when text input is active
            if (ImGui::IsItemActive() && !g_keyboardOpen) {
                g_wantKeyboard = true;
            }

            ImGui::Spacing();

            float btnWidth = (ImGui::GetContentRegionAvail().x - 16) / 3.0f;

            if (ImGui::Button("Execute", ImVec2(btnWidth, 32))) {
                if (scriptBuf[0] != '\0') {
                    if (g_scriptExecCallback) {
                        g_scriptExecCallback(scriptBuf);
                    } else {
                        ExecuteLuauScript(scriptBuf);
                    }
                    snprintf(statusMsg, sizeof(statusMsg), "Script executed.");
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

            // Output log
            if (g_outputLen > 0) {
                ImGui::Spacing();
                ImGui::TextColored(g_colAccent, "Output:");
                ImGui::BeginChild("##output", ImVec2(-1, 80), true);
                ImGui::TextWrapped("%s", g_outputLog);
                ImGui::SetScrollHereY(1.0f);
                ImGui::EndChild();
                if (ImGui::Button("Clear Output", ImVec2(-1, 24))) {
                    g_outputLog[0] = '\0';
                    g_outputLen = 0;
                }
            }

            ImGui::EndTabItem();
        }

        // --- Settings Tab (Color Customizer) ---
        if (ImGui::BeginTabItem("Settings")) {
            ImGui::Spacing();
            ImGui::TextColored(g_colAccent, "Color Customizer");
            ImGui::Separator();
            ImGui::Spacing();

            ImGui::ColorEdit4("Text Color",         (float *)&g_colText,
                              ImGuiColorEditFlags_NoInputs);
            ImGui::ColorEdit4("Background",          (float *)&g_colWindowBg,
                              ImGuiColorEditFlags_NoInputs);
            ImGui::ColorEdit4("Buttons",             (float *)&g_colButton,
                              ImGuiColorEditFlags_NoInputs);
            ImGui::ColorEdit4("Borders",             (float *)&g_colBorder,
                              ImGuiColorEditFlags_NoInputs);
            ImGui::ColorEdit4("Title Bar",           (float *)&g_colTitleBg,
                              ImGuiColorEditFlags_NoInputs);
            ImGui::ColorEdit4("Tabs",                (float *)&g_colTab,
                              ImGuiColorEditFlags_NoInputs);
            ImGui::ColorEdit4("Input Fields",        (float *)&g_colFrameBg,
                              ImGuiColorEditFlags_NoInputs);
            ImGui::ColorEdit4("Accent / Highlights", (float *)&g_colAccent,
                              ImGuiColorEditFlags_NoInputs);

            ImGui::Spacing();
            ImGui::Separator();
            ImGui::Spacing();

            if (ImGui::Button("Reset to Default", ImVec2(-1, 32))) {
                g_colText     = ImVec4(0.90f, 0.93f, 1.00f, 1.00f);
                g_colWindowBg = ImVec4(0.06f, 0.06f, 0.12f, 0.97f);
                g_colButton   = ImVec4(0.15f, 0.35f, 0.65f, 0.85f);
                g_colBorder   = ImVec4(0.25f, 0.50f, 0.85f, 0.40f);
                g_colTitleBg  = ImVec4(0.15f, 0.35f, 0.65f, 1.00f);
                g_colTab      = ImVec4(0.20f, 0.45f, 0.80f, 1.00f);
                g_colFrameBg  = ImVec4(0.10f, 0.10f, 0.18f, 0.90f);
                g_colAccent   = ImVec4(0.40f, 0.80f, 1.00f, 1.00f);
            }

            ImGui::EndTabItem();
        }

        // --- Info Tab ---
        if (ImGui::BeginTabItem("Info")) {
            ImGui::Spacing();

            ImGui::TextColored(g_colAccent, "ElxrScriptz Executor");
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
                "Drag the title bar to reposition. Use the Execute tab to "
                "run scripts and Settings to customize colors."
            );

            ImGui::EndTabItem();
        }

        ImGui::EndTabBar();
    }

    ImGui::End();

    // Handle keyboard show/hide
    if (g_wantKeyboard) {
        g_hiddenTextField.text = @" ";
        [g_hiddenTextField becomeFirstResponder];
        g_keyboardOpen = true;
        g_wantKeyboard = false;
    }
    if (!ImGui::GetIO().WantTextInput && g_keyboardOpen) {
        [g_hiddenTextField resignFirstResponder];
        g_keyboardOpen = false;
    }
}

static void RenderFrame() {
    CGFloat scale = [UIScreen mainScreen].scale;
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    g_metalLayer.frame = screenBounds;
    g_metalLayer.contentsScale = scale;
    g_metalLayer.drawableSize = CGSizeMake(
        screenBounds.size.width * scale,
        screenBounds.size.height * scale
    );
    g_touchView.frame = screenBounds;
    ImGuiIO &io = ImGui::GetIO();
    io.DisplaySize = ImVec2(screenBounds.size.width, screenBounds.size.height);
    io.DisplayFramebufferScale = ImVec2((float)scale, (float)scale);

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
        InitImGui();
        g_menuVisible = visible;
        if (g_initialized) {
            if (visible) {
                g_metalLayer.hidden = NO;
                g_touchView.hidden = NO;
                g_needsCenter = true;
            } else {
                g_metalLayer.hidden = YES;
                g_touchView.hidden = YES;
                if (g_keyboardOpen) {
                    [g_hiddenTextField resignFirstResponder];
                    g_keyboardOpen = false;
                }
            }
        }
    });
}
