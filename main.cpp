#include "imgui.h"
#include <iostream>

// This function runs every time the game draws a frame
void DrawMenu() {
    ImGui::Begin("Roblox Executor", nullptr, ImGuiWindowFlags_AlwaysAutoResize);
    ImGui::Text("Status: Active ✅");
    if (ImGui::Button("Speed Hack")) {
        // Your hack logic goes here later
    }
    ImGui::End();
}

// This is the "Hook" that injects into Roblox
__attribute__((constructor))
static void initialize() {
    std::cout << "Executor Loaded!" << std::endl;
}
