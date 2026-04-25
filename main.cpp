#include <iostream>
#include <vector>
#include "imgui.h"

// This is the "Constructor" - it runs the moment the dylib is loaded
__attribute__((constructor))
static void initialize() {
    std::cout << "Executor Loaded Successfully!" << std::endl;
    // Your initialization logic for the menu goes here
}

void DrawMenu() {
    ImGui::Begin("My Custom Executor");
    ImGui::Text("Status: Active");
    
    if (ImGui::Button("Execute Script")) {
        // Script execution logic
    }
    
    if (ImGui::Button("Clear Log")) {
        // Clear logic
    }
    
    ImGui::End();
}
