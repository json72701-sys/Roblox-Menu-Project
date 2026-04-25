#include "imgui.h"
#include <UIKit/UIKit.h>

// This is the "Magic Hook" for iOS
__attribute__((constructor))
static void initialize() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // This waits 5 seconds after the game starts to pop the menu
        // It gives Roblox time to finish loading its own screen first
        
        UIWindow *keyWindow = [[UIApplication sharedApplication] keyWindow];
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(50, 50, 100, 50)];
        label.text = @"LOADED ✅";
        label.backgroundColor = [UIColor goldColor];
        [keyWindow addSubview:label];
    });
}
