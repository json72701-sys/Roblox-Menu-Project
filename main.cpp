#include <UIKit/UIKit.h>
#include <stdio.h>

// This is the "Force Start" command for iOS
__attribute__((constructor))
static void initialize() {
    // We use a dispatch_after to wait 10 seconds. 
    // This ensures Roblox is fully loaded before we try to show our menu.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // This creates a bright red test box on your screen
        // If you see this, the executor is WORKING!
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        UIView *testView = [[UIView alloc] initWithFrame:CGRectMake(100, 100, 50, 50)];
        testView.backgroundColor = [UIColor redColor];
        testView.layer.zPosition = 9999; // Put it on top of everything
        [window addSubview:testView];
        
        printf("GOLD EXECUTOR: UI INJECTED ✅\n");
    });
}
