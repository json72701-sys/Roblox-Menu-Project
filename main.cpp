#include "imgui.h"
#include <stdio.h>

// This is the variable that keeps the menu open
bool open = true;

// This is the actual Menu Function
void RenderMenu() {
    if (open) {
        ImGui::SetNextWindowSize(ImVec2(400, 250), ImGuiCond_FirstUseEver);
        ImGui::Begin("Gold Executor v1.0", &open);
        
        ImGui::Text("Welcome to the Menu!");
        ImGui::Separator();
        
        if (ImGui::Button("Speed Hack (Active)")) {
            // Logic goes here later
        }
        
        if (ImGui::Button("Close Menu")) {
            open = false;
        }
        
        ImGui::End();
    }
}

// This tells the iPad to wake up the code
__attribute__((constructor))
static void initialize() {
    printf("GOLD EXECUTOR: Initialized and Ready ✅\n");
}
