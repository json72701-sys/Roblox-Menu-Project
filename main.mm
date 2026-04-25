#import <UIKit/UIKit.h>
// Assuming your ImGui setup has a toggle function
extern void RenderImGuiMenu(bool visible); 
static bool isMenuVisible = false;

@interface DraggableLogo : UIButton
@end

@implementation DraggableLogo {
    CGPoint lastPoint;
}

// Makes the logo draggable across the screen
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentLocation = [touch locationInView:self.superview];
    self.center = currentLocation;
}

// Detects the tap to open ImGui
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    if (touch.tapCount == 1) {
        isMenuVisible = !isMenuVisible;
        RenderImGuiMenu(isMenuVisible); // This triggers your ImGui files
    }
}
@end

__attribute__((constructor))
static void initialize() {
    // Shorter delay, but we use a recursive check to find the window
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        // Search for the actual active window
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                win = window;
                break;
            }
        }

        if (win) {
            DraggableLogo *btn = [DraggableLogo buttonWithType:UIButtonTypeCustom];
            btn.frame = CGRectMake(100, 100, 55, 55);
            
            // Set your logo image here
            [btn setBackgroundColor:[UIColor orangeColor]];
            btn.layer.cornerRadius = 27.5;
            btn.layer.zPosition = 9999;
            
            [win addSubview:btn];
        }
    });
}
