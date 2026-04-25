#include <UIKit/UIKit.h>

// This is the "Automatic Trigger"
__attribute__((constructor))
static void initialize() {
    // We wait 5 seconds to make sure Roblox is fully open
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // This creates a standard iPad Alert box
        UIViewController *root = [UIApplication sharedApplication].keyWindow.rootViewController;
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Gold Executor" 
                                    message:@"Menu Loaded Successfully! ✅" 
                                    preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [root presentViewController:alert animated:YES completion:nil];
    });
}
