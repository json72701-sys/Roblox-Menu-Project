#include <stdbool.h>
#include <stdio.h>

// This satisfies the "Undefined symbol" error
extern "C" void RenderImGuiMenu(bool visible) {
    if (visible) {
        printf("ElxrScriptz Menu is now visible!\n");
        // Later, we will put the real ImGui code here
    }
}
