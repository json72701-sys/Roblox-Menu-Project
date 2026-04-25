#import <UIKit/UIKit.h>

#include "offsets.hpp"
#include "Include/mem.hpp"
#include "Include/base.hpp"
#include "Methods/DataModel.hpp"
#include "Methods/Instance.hpp"
#include "Methods/Executor.hpp"
#include "Structures/Player.hpp"

static bool isMenuVisible = false;
static bool isInitialized = false;

static void InitializeBase() {
    if (isInitialized) return;
    mem::BaseAddress = base::GetRobloxBase();
    if (mem::BaseAddress) {
        NSLog(@"[ElxrScriptz] Base address: %p", (void*)mem::BaseAddress);
        isInitialized = true;
    } else {
        NSLog(@"[ElxrScriptz] Failed to find Roblox base address");
    }
}

extern "C" void RenderImGuiMenu(bool visible) {
    if (!visible) return;

    InitializeBase();
    if (!isInitialized) return;

    uintptr_t dm = GetDataModel();
    if (!dm) {
        NSLog(@"[ElxrScriptz] DataModel not found");
        return;
    }
    NSLog(@"[ElxrScriptz] DataModel: %p", (void*)dm);

    uintptr_t players = Instance::FindFirstChild(dm, "Players");
    if (players) {
        uintptr_t localPlayer = Player::GetLocalPlayer(players);
        NSLog(@"[ElxrScriptz] LocalPlayer: %p", (void*)localPlayer);

        if (localPlayer) {
            std::string playerName = Instance::GetName(localPlayer);
            NSLog(@"[ElxrScriptz] Player: %s", playerName.c_str());
        }
    }

    uintptr_t workspace = Instance::FindFirstChild(dm, "Workspace");
    if (workspace) {
        NSLog(@"[ElxrScriptz] Workspace: %p", (void*)workspace);
    }

    uintptr_t script = Executor::FindLocalScript(dm);
    if (script) {
        NSLog(@"[ElxrScriptz] Found LocalScript: %s", Instance::GetName(script).c_str());
        NSLog(@"[ElxrScriptz] Executor ready");
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        InitializeBase();
    });

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
            NSLog(@"[ElxrScriptz] Menu loaded");
        }
    });
}
