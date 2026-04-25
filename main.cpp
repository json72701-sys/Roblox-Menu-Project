#include <UIKit/UIKit.h>
#include <objc/runtime.h>

// This is the "Gold Hook" 
// It waits for the game to load, then creates a window on top of EVERYTHING
__attribute__((constructor))
static void initialize() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // 1. Get the main screen of the iPad
        UIWindow *window = [[UIApplication sharedApplication] keyWindow];
        
        // 2. Create a "Floating Logo" button
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setFrame:CGRectMake(100, 100, 60, 60)];
        [button setTitle:@"GOLD" forState:UIControlStateNormal];
        [button setBackgroundColor:[UIColor colorWithRed:1.0 green:0.84 blue:0.0 alpha:1.0]]; // Gold Color
        button.layer.cornerRadius = 30; // Makes it a circle
        
        // 3. Add a shadow so you can see it
        button.layer.shadowColor = [[UIColor blackColor] CGColor];
        button.layer.shadowOffset = CGSizeMake(0, 2);
        button.layer.shadowRadius = 5;
        button.layer.shadowOpacity = 0.5;

        // 4. Stick it to the screen
        [window addSubview:button];
        
        printf("GOLD MENU INJECTED SUCCESSFULLY! ✅\n");
    });
}
