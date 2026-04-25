#import <UIKit/UIKit.h>

// This links your Objective-C button to your C++ ImGui menu
extern "C" void RenderImGuiMenu(bool visible);

static bool isMenuVisible = false;

// This class handles the "Draggable" logic you requested
@interface DraggableLogo : UIButton
@end

@implementation DraggableLogo {
    CGPoint lastPoint;
}

// Moves the logo when you drag your finger
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentLocation = [touch locationInView:self.superview];
    self.center = currentLocation;
}

// Opens the menu when you tap the logo
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
    // Waits 10 seconds for the game to load
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        
        // Find the active window to place the button on
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                win = window;
                break;
            }
        }

        if (win) {
            DraggableLogo *btn = [DraggableLogo buttonWithType:UIButtonTypeCustom];
            btn.frame = CGRectMake(100, 100, 60, 60);
            
            // Setting the "Gold" theme
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
