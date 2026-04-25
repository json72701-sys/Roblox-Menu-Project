#import <UIKit/UIKit.h>

// --- CONNECTING YOUR UD LOGIC ---
#include "offsets.hpp"
#include "Methods/DataModel.cpp" 
// --------------------------------

static bool isMenuVisible = false;

// Defining this here so it's only in ONE place
extern "C" void RenderImGuiMenu(bool visible) {
    if (visible) {
        uintptr_t dm = GetDataModel(); 
        NSLog(@"[ElxrScriptz] DataModel found: %p", (void*)dm);
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
            
            // Your Blue ELXR Logo
            [btn setTitle:@"ELXR" forState:UIControlStateNormal];
            [btn setBackgroundColor:[UIColor blueColor]]; 
            
            btn.layer.cornerRadius = 30;
            btn.layer.zPosition = 10000;
            [win addSubview:btn];
        }
    });
}
