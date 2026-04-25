#include <stdio.h>

// This is the absolute simplest way to see if your file works
__attribute__((constructor))
static void initialize() {
    // This doesn't draw a menu, but it proves the file is "alive"
    printf("--- EXECUTOR INITIALIZED ---");
}
