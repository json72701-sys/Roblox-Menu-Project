#import <UIKit/UIKit.h>

// --- CONNECTING YOUR UD LOGIC ---
#include "offsets.hpp"
#include "Methods/DataModel.cpp"
// --------------------------------

static bool isMenuVisible = false;

// THIS WAS MISSING: This is the actual function the compiler was looking for
extern "C" void RenderImGuiMenu(bool visible) {
    if (visible) {
        // This is where the menu appears. 
        // For now, it will trigger your UD logic in the background
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
    self.center = currentLocation;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    if (touch.tapCount == 1) {
        isMenuVisible = !isMenuVisible;
        RenderImGuiMenu(isMenuVisible); 
    }
}
@end

__attribute__((constructor))
static void initialize() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) { win = window; break; }
        }

        if (win) {
            DraggableLogo *btn = [DraggableLogo buttonWithType:UIButtonTypeCustom];
            [btn setFrame:CGRectMake(100, 100, 60, 60)];
            
            // Updated your Executor Name
            [btn setTitle:@"ELXR" forState:UIControlStateNormal];
            [btn setBackgroundColor:[UIColor orangeColor]];
            btn.layer.cornerRadius = 30;
            btn.layer.zPosition = 10000;
            [win addSubview:btn];
        }
    });
}
