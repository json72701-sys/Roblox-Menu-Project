#include "imgui.h"
#include <iostream>

bool show_menu = false;

// This draws the actual floating icon
void DrawFloatingLogo() {
    ImGui::SetNextWindowPos(ImVec2(50, 50), ImGuiCond_FirstUseEver);
    ImGui::Begin("Logo", nullptr, ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoBackground);
    
    // This creates a simple button that looks like a [G] for Gold
    if (ImGui::Button("[G]", ImVec2(50, 50))) {
        show_menu = !show_menu; // Toggles the menu on and off
    }
    
    ImGui::End();
}

// This draws the main executor window when you click the logo
void DrawMainUI() {
    if (show_menu) {
        ImGui::Begin("Gold Executor", &show_menu);
        ImGui::Text("Status: Active ✅");
        if (ImGui::Button("Speed Hack")) { /* Logic here */ }
        ImGui::End();
    }
}

// This is the "Hook" that Roblox uses to draw frames
void RenderLoop() {
    DrawFloatingLogo();
    DrawMainUI();
}
