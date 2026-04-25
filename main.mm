#include "imgui.h"
#include <iostream>

// Use these global variables for state management
bool g_Executor_Menu_Open = false;
char g_Script_Buffer[1024 * 64] = ""; // 64KB for Lua script

// Custom color palette (Onyx & Gold)
#define GOLD_COLOR ImVec4(1.0f, 0.84f, 0.0f, 1.0f)
#define TEXT_GOLD_COLOR ImVec4(1.0f, 0.97f, 0.86f, 1.0f)
#define ONYX_COLOR ImVec4(0.07f, 0.07f, 0.07f, 0.95f)

// Placeholder for actual Lua execution logic (to be linked later)
void ExecuteLua(const char* luaCode) {
    std::cout << "GOLD EXECUTOR: Running script...\n" << luaCode << std::endl;
    // To-Do: Integrate task_defer/task_spawn hooking
}

// Draw the floating rounded logo/toggle
void DrawGoldLogo() {
    ImGui::SetNextWindowPos(ImVec2(50, 50), ImGuiCond_FirstUseEver);
    ImGui::PushStyleVar(ImGuiStyleVar_WindowRounding, 12.0f); // Rounded Corners
    ImGui::SetNextWindowBgAlpha(0.95f);
    
    ImGui::Begin("GLog", nullptr, ImGuiWindowFlags_NoTitleBar | ImGuiWindowFlags_NoResize | ImGuiWindowFlags_AlwaysAutoResize | ImGuiWindowFlags_NoBackground);
    
    // Polished Onyx & Gold button
    ImGui::PushStyleColor(ImGuiGuiCol_Button, ONYX_COLOR);
    ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.2f, 0.2f, 0.2f, 1.0f));
    ImGui::PushStyleColor(ImGuiCol_ButtonActive, ImVec4(0.3f, 0.3f, 0.3f, 1.0f));
    ImGui::PushStyleColor(ImGuiCol_Border, GOLD_COLOR);
    ImGui::PushStyleColor(ImGuiCol_Text, TEXT_GOLD_COLOR);

    if (ImGui::Button("[G]", ImVec2(50, 50))) {
        g_Executor_Menu_Open = !g_Executor_Menu_Open;
    }
    
    ImGui::PopStyleColor(5);
    ImGui::PopStyleVar();
    ImGui::End();
}

// Draw the main polished UI window
void DrawGoldExecutorMenu() {
    if (g_Executor_Menu_Open) {
        ImGui::SetNextWindowSize(ImVec2(600, 400), ImGuiCond_FirstUseEver);
        ImGui::Begin("Gold Executor v1.0", &g_Executor_Menu_Open);
        
        ImGui::PushStyleColor(ImGuiCol_TitleBgActive, ONYX_COLOR);
        ImGui::PopStyleColor();

        // Main tabs
        if (ImGui::BeginTabBar("Main_TabBar")) {
            if (ImGui::BeginTabItem("Executor")) {
                ImGui::Text("Enter Your Script:");
                ImGui::InputTextMultiline("##ScriptInput", g_Script_Buffer, sizeof(g_Script_Buffer), ImVec2(-FLT_MIN, ImGui::GetTextLineHeightWithSpacing() * 16));
                
                if (ImGui::Button("Execute")) {
                    ExecuteLua(g_Script_Buffer);
                }
                
                ImGui::EndTabItem();
            }
            if (ImGui::BeginTabItem("Scripts")) {
                ImGui::Text("Coming Soon...");
                ImGui::EndTabItem();
            }
            if (ImGui::BeginTabItem("Settings")) {
                ImGui::ColorEdit4("UI Color", (float*)&GOLD_COLOR);
                ImGui::EndTabItem();
            }
            ImGui::EndTabBar();
        }
        
        ImGui::End();
    }
}

// Constructor to initialize the executor upon load
__attribute__((constructor))
static void initialize() {
    std::cout << "GOLD EXECUTOR: Initializing...\n" << std::endl;
    // ... Additional setup logic here
}
