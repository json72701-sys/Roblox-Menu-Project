#include "imgui.h"
#include <stdio.h>

// This is a "Constructor" - it runs the SECOND the dylib is loaded
__attribute__((constructor))
static void initialize() {
    // This sends a message to the iPad's system log so we know it worked
    printf("!!! GOLD EXECUTOR LOADED !!!\n");
}

// This is a simple flag to show the menu
bool visible = true;

void Render() {
    if (visible) {
        ImGui::Begin("Gold Executor", &visible);
        ImGui::Text("Menu is Running!");
        if (ImGui::Button("Close")) {
            visible = false;
        }
        ImGui::End();
    }
}
