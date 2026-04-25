#include "imgui.h"
#include <string>

// Variables to track the menu state
bool show_menu = false;
static char script_buffer[99999] = ""; // This holds your pasted script

void RenderUI() {
    // 1. THE FLOATING BUTTON [G]
    ImGui::SetNextWindowPos(ImVec2(50, 50), ImGuiCond_FirstUseEver);
    ImGui::Begin("Toggle", nullptr, ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoBackground);
    if (ImGui::Button("[G]", ImVec2(50, 50))) {
        show_menu = !show_menu; // Clicking the G opens/closes the menu
    }
    ImGui::End();

    // 2. THE MAIN EXECUTOR MENU
    if (show_menu) {
        ImGui::SetNextWindowSize(ImVec2(400, 300), ImGuiCond_FirstUseEver);
        ImGui::Begin("Gold Executor v1.0", &show_menu);

        ImGui::Text("Paste your script below:");
        
        // The Script Input Box
        ImGui::InputTextMultiline("##ScriptBox", script_buffer, IM_ARRAYSIZE(script_buffer), ImVec2(-FLT_MIN, 180));

        ImGui::Separator();

        // The Execute Button
        if (ImGui::Button("EXECUTE", ImVec2(120, 40))) {
            // This is where the Lua injection happens
            // For now, it will just clear the box to show it "sent"
            printf("Executing: %s\n", script_buffer);
        }

        ImGui::SameLine();

        if (ImGui::Button("Clear", ImVec2(80, 40))) {
            memset(script_buffer, 0, sizeof(script_buffer));
        }

        ImGui::End();
    }
}
