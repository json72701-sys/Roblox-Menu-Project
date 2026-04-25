#import <UIKit/UIKit.h>

// This "extern" fixes the "Undefined Symbol" error by linking to your C++ code
extern "C" void RenderImGuiMenu(bool visible);

static bool isMenuVisible = false;

@interface DraggableLogo : UIButton
@end

@implementation DraggableLogo {
    CGPoint lastPoint;
}

// Logic to make the logo draggable
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentLocation = [touch locationInView:self.superview];
    self.center = currentLocation;
}

// Logic to toggle your ImGui menu when tapped
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
    // Wait for game window to load (reduced to 10 seconds for speed)
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                win = window;
                break;
            }
        }

        if (win) {
            DraggableLogo *btn = [DraggableLogo buttonWithType:UIButtonTypeCustom];
            btn.frame = CGRectMake(100, 100, 60, 60);
            
            [btn setBackgroundColor:[UIColor orangeColor]];
            [btn setTitle:@"GOLD" forState:UIControlStateNormal];
            btn.layer.cornerRadius = 30;
            btn.layer.borderWidth = 2;
            btn.layer.borderColor = [UIColor whiteColor].CGColor;
            btn.layer.zPosition = 10000;
            
            [win addSubview:btn];
        }
    });
}
