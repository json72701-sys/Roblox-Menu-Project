#import <UIKit/UIKit.h>

// This links your button to your ImGui menu code
extern "C" void RenderImGuiMenu(bool visible);

static bool isMenuVisible = false;

// Custom class to handle dragging
@interface DraggableLogo : UIButton
@end

@implementation DraggableLogo
// Updates position when you drag
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentLocation = [touch locationInView:self.superview];
    self.center = currentLocation;
}

// Toggles the menu when you tap
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
            [btn setTitle:@"GOLD" forState:UIControlStateNormal];
            [btn setBackgroundColor:[UIColor orangeColor]];
            btn.layer.cornerRadius = 30;
            btn.layer.zPosition = 10000;
            [win addSubview:btn];
        }
    });
}
