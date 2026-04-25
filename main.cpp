#include <UIKit/UIKit.h>
#include <objc/runtime.h>

// This is the "Magic Hook" that forces a label onto the Roblox screen
__attribute__((constructor))
static void initialize() {
    // We wait 10 seconds to make sure Roblox is fully loaded
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene* scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    keyWindow = ((UIWindowScene*)scene).windows.firstObject;
                    break;
                }
            }
        } else {
            keyWindow = [UIApplication sharedApplication].keyWindow;
        }

        // Create a simple Floating Button
        UIButton *logoButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [logoButton setFrame:CGRectMake(100, 100, 60, 60)];
        [logoButton setTitle:@"GOLD" forState:UIControlStateNormal];
        [logoButton setBackgroundColor:[UIColor goldColor]];
        [logoButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
        logoButton.layer.cornerRadius = 30; // Makes it a circle
        
        [keyWindow addSubview:logoButton];
    });
}
