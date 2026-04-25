#import "../imgui.h"
#include "../Engine/Engine.hpp"
#include "../Engine/ScriptEngine.hpp"
#include "../Structures/Player.hpp"
#include "../Methods/Instance.hpp"
#include "../Include/mem.hpp"
#include "../offsets.hpp"

#include <string>

static bool  s_EngineInitialized = false;
static int   s_CurrentTab        = 0;
static char  s_ScriptBuffer[4096] = "";

// Player modification values
static float s_WalkSpeed  = 16.0f;
static float s_JumpPower  = 50.0f;
static float s_Gravity    = 196.2f;
static float s_FOV        = 70.0f;

static bool  s_GodMode    = false;
static bool  s_NoClip     = false;

static char  s_StatusMsg[256] = "Waiting for initialization...";

static void TryInitEngine() {
    if (!s_EngineInitialized) {
        if (Engine::Initialize()) {
            s_EngineInitialized = true;
            Engine::RefreshPlayer();
            snprintf(s_StatusMsg, sizeof(s_StatusMsg), "Engine connected");
        } else {
            snprintf(s_StatusMsg, sizeof(s_StatusMsg), "DataModel not found — retrying...");
        }
    } else {
        Engine::RefreshPlayer();
    }
}

static void DrawPlayerTab() {
    ImGui::TextColored(ImVec4(1, 0.85f, 0, 1), "Player Modifications");
    ImGui::Separator();

    if (!Engine::g_State.humanoid) {
        ImGui::TextColored(ImVec4(1, 0.3f, 0.3f, 1), "Humanoid not found");
        return;
    }

    float currentSpeed = Player::GetWalkSpeed(Engine::g_State.humanoid);
    float currentJump  = Player::GetJumpPower(Engine::g_State.humanoid);

    ImGui::Text("Current WalkSpeed: %.1f", currentSpeed);
    ImGui::SliderFloat("WalkSpeed", &s_WalkSpeed, 0.0f, 500.0f);
    if (ImGui::Button("Set WalkSpeed")) {
        mem::write<float>(Engine::g_State.humanoid + offsets::WalkSpeed, s_WalkSpeed);
    }

    ImGui::Spacing();
    ImGui::Text("Current JumpPower: %.1f", currentJump);
    ImGui::SliderFloat("JumpPower", &s_JumpPower, 0.0f, 500.0f);
    if (ImGui::Button("Set JumpPower")) {
        mem::write<float>(Engine::g_State.humanoid + offsets::JumpPower, s_JumpPower);
    }

    ImGui::Spacing();
    if (ImGui::Checkbox("God Mode", &s_GodMode)) {
        if (s_GodMode && Engine::g_State.humanoid) {
            float maxHp = Player::GetMaxHealth(Engine::g_State.humanoid);
            mem::write<float>(Engine::g_State.humanoid + offsets::Health, maxHp > 0 ? maxHp : 100000.0f);
        }
    }

    if (ImGui::Checkbox("NoClip", &s_NoClip)) {
        if (Engine::g_State.rootPart) {
            uint8_t flags = mem::read<uint8_t>(Engine::g_State.rootPart + offsets::CanCollide);
            if (s_NoClip) {
                flags &= ~offsets::CanCollideMask;
            } else {
                flags |= offsets::CanCollideMask;
            }
            mem::write<uint8_t>(Engine::g_State.rootPart + offsets::CanCollide, flags);
        }
    }

    ImGui::Spacing();
    ImGui::Separator();
    float hp    = Player::GetHealth(Engine::g_State.humanoid);
    float maxHp = Player::GetMaxHealth(Engine::g_State.humanoid);
    ImGui::Text("Health: %.0f / %.0f", hp, maxHp);

    // Health bar
    float fraction = (maxHp > 0) ? (hp / maxHp) : 0.0f;
    ImGui::ProgressBar(fraction, ImVec2(-1, 0));
}

static void DrawWorldTab() {
    ImGui::TextColored(ImVec4(0, 0.85f, 1, 1), "World Settings");
    ImGui::Separator();

    if (!Engine::g_State.workspace) {
        ImGui::TextColored(ImVec4(1, 0.3f, 0.3f, 1), "Workspace not found");
        return;
    }

    float currentGravity = Engine::GetGravity();
    ImGui::Text("Current Gravity: %.1f", currentGravity);
    ImGui::SliderFloat("Gravity", &s_Gravity, 0.0f, 1000.0f);
    if (ImGui::Button("Set Gravity")) {
        mem::write<float>(Engine::g_State.workspace + offsets::Gravity, s_Gravity);
    }

    ImGui::Spacing();
    if (Engine::g_State.camera) {
        float currentFOV = Engine::GetFOV();
        ImGui::Text("Current FOV: %.1f", currentFOV);
        ImGui::SliderFloat("FOV", &s_FOV, 1.0f, 120.0f);
        if (ImGui::Button("Set FOV")) {
            mem::write<float>(Engine::g_State.camera + offsets::FOV, s_FOV);
        }
    }

    ImGui::Spacing();
    ImGui::Separator();
    if (Engine::g_State.lighting) {
        float clockTime = mem::read<float>(Engine::g_State.lighting + offsets::ClockTime);
        ImGui::Text("Time of Day: %.2f", clockTime);
        static float newTime = 14.0f;
        ImGui::SliderFloat("Clock Time", &newTime, 0.0f, 24.0f);
        if (ImGui::Button("Set Time")) {
            mem::write<float>(Engine::g_State.lighting + offsets::ClockTime, newTime);
        }
    }
}

static void DrawScriptTab() {
    ImGui::TextColored(ImVec4(0.5f, 1, 0.5f, 1), "Script Executor");
    ImGui::Separator();

    bool ready = ScriptEngine::IsReady();
    ImGui::Text("ScriptContext: %s", Engine::g_State.scriptContext ? "Found" : "Not found");
    ImGui::Text("Lua State: %s", ready ? "Ready" : "Not ready");

    ImGui::Spacing();
    ImGui::InputTextMultiline("##script", s_ScriptBuffer, sizeof(s_ScriptBuffer),
                              ImVec2(-1, 200));

    if (ImGui::Button("Execute", ImVec2(120, 30))) {
        auto result = ScriptEngine::Execute(std::string(s_ScriptBuffer));
        if (!result.success) {
            snprintf(s_StatusMsg, sizeof(s_StatusMsg), "%s", result.error.c_str());
        } else {
            snprintf(s_StatusMsg, sizeof(s_StatusMsg), "Script executed");
        }
    }
    ImGui::SameLine();
    if (ImGui::Button("Clear", ImVec2(80, 30))) {
        memset(s_ScriptBuffer, 0, sizeof(s_ScriptBuffer));
    }
}

static void DrawInfoTab() {
    ImGui::TextColored(ImVec4(1, 0.6f, 0, 1), "Game Info");
    ImGui::Separator();

    if (!s_EngineInitialized) {
        ImGui::Text("Engine not initialized");
        return;
    }

    ImGui::Text("DataModel:     0x%llX", (unsigned long long)Engine::g_State.dataModel);
    ImGui::Text("Workspace:     0x%llX", (unsigned long long)Engine::g_State.workspace);
    ImGui::Text("Players:       0x%llX", (unsigned long long)Engine::g_State.players);
    ImGui::Text("LocalPlayer:   0x%llX", (unsigned long long)Engine::g_State.localPlayer);
    ImGui::Text("ScriptContext: 0x%llX", (unsigned long long)Engine::g_State.scriptContext);

    ImGui::Spacing();
    if (Engine::g_State.localPlayer) {
        std::string name = Player::GetDisplayName(Engine::g_State.localPlayer);
        int64_t uid = Player::GetUserId(Engine::g_State.localPlayer);
        ImGui::Text("Player: %s (ID: %lld)", name.c_str(), (long long)uid);
    }

    ImGui::Spacing();
    ImGui::Separator();
    ImGui::Text("Children of DataModel:");
    auto children = Instance::GetChildren(Engine::g_State.dataModel);
    for (auto child : children) {
        std::string cname  = Instance::GetName(child);
        std::string cclass = Instance::GetClassName(child);
        ImGui::BulletText("%s [%s]", cname.c_str(), cclass.c_str());
    }
}

extern "C" void RenderImGuiMenu(bool visible) {
    if (!visible) return;

    TryInitEngine();

    ImGui::SetNextWindowSize(ImVec2(420, 500), ImGuiCond_FirstUseEver);
    ImGui::Begin("GOLD Executor", nullptr,
                 ImGuiWindowFlags_NoCollapse);

    // Status bar
    ImGui::TextColored(ImVec4(0.4f, 1, 0.4f, 1), "%s", s_StatusMsg);
    ImGui::Separator();

    // Tab bar
    const char* tabs[] = { "Player", "World", "Script", "Info" };
    for (int i = 0; i < 4; i++) {
        if (i > 0) ImGui::SameLine();
        bool selected = (s_CurrentTab == i);
        if (selected) ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.8f, 0.6f, 0, 1));
        if (ImGui::Button(tabs[i], ImVec2(90, 30))) s_CurrentTab = i;
        if (selected) ImGui::PopStyleColor();
    }
    ImGui::Separator();

    // Render active tab
    switch (s_CurrentTab) {
        case 0: DrawPlayerTab();  break;
        case 1: DrawWorldTab();   break;
        case 2: DrawScriptTab();  break;
        case 3: DrawInfoTab();    break;
    }

    // Persistent god-mode loop
    if (s_GodMode && Engine::g_State.humanoid) {
        float maxHp = Player::GetMaxHealth(Engine::g_State.humanoid);
        mem::write<float>(Engine::g_State.humanoid + offsets::Health,
                          maxHp > 0 ? maxHp : 100000.0f);
    }

    ImGui::End();
}
