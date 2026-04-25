#import <UIKit/UIKit.h>

#include "offsets.hpp"
#include "Include/mem.hpp"
#include "Methods/DataModel.hpp"
#include "Structures/Player.hpp"

static bool isMenuVisible = false;

extern "C" void RenderImGuiMenu(bool visible) {
    if (!visible) return;

    uintptr_t dm = GetDataModel();
    NSLog(@"[ElxrScriptz] DataModel: %p", (void*)dm);

    uintptr_t players = mem::read<uintptr_t>(dm + offsets::Children);
    uintptr_t localPlayer = Player::GetLocalPlayer(players);
    NSLog(@"[ElxrScriptz] LocalPlayer: %p", (void*)localPlayer);
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
            [btn setTitle:@"ELXR" forState:UIControlStateNormal];
            [btn setBackgroundColor:[UIColor blueColor]];
            btn.layer.cornerRadius = 30;
            btn.layer.zPosition = 10000;
            [win addSubview:btn];
        }
    });
}
