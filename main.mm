#import <UIKit/UIKit.h>

// --- CONNECTING YOUR UD LOGIC ---
// These lines tell the compiler to look inside your folders
#include "offsets.hpp"
#include "Methods/DataModel.cpp"
// --------------------------------

static bool isMenuVisible = false;

// This is the "Fix" for the Red X error.
// It creates the function the compiler was looking for.
extern "C" void RenderImGuiMenu(bool visible) {
    if (visible) {
        // This is your new EXECUTE functionality.
        // It runs your UD logic the moment you tap the logo!
        uintptr_t dm = GetDataModel(); 
        NSLog(@"[ElxrScriptz] DataModel found at: %p", (void*)dm);
    }
}

@interface DraggableLogo : UIButton
@end

@implementation DraggableLogo
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentLocation = [touch locationInView:self.superview];
    self.center = currentLocation; // Keeps your dragging logic exactly the same
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    if (touch.tapCount == 1) {
        isMenuVisible = !isMenuVisible;
        RenderImGuiMenu(isMenuVisible); // Toggles the menu and runs the UD logic
    }
}
@end

__attribute__((constructor))
static void initialize() {
    // Waits 10 seconds after the game starts to show your logo
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) { win = window; break; }
        }

        if (win) {
            DraggableLogo *btn = [DraggableLogo buttonWithType:UIButtonTypeCustom];
            [btn setFrame:CGRectMake(100, 100, 60, 60)];
            
            // ELXR Title with the Blue background
            [btn setTitle:@"ELXR" forState:UIControlStateNormal];
            [btn setBackgroundColor:[UIColor blueColor]]; 
            
            btn.layer.cornerRadius = 30;
            btn.layer.zPosition = 10000;
            [win addSubview:btn];
        }
    });
}
