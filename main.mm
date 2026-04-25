#import <UIKit/UIKit.h>
#include <stdio.h>

@interface MenuButton : UIButton
@end

@implementation MenuButton
// This makes the button draggable later if you want!
@end

__attribute__((constructor))
static void initialize() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }

        UIButton *goldButton = [UIButton buttonWithType:UIButtonTypeCustom];
        goldButton.frame = CGRectMake(100, 100, 60, 60);
        goldButton.backgroundColor = [UIColor orangeColor]; // Gold-ish
        goldButton.layer.cornerRadius = 30;
        [goldButton setTitle:@"G" forState:UIControlStateNormal];
        goldButton.layer.zPosition = 10000;
        
        [keyWindow addSubview:goldButton];
        printf("Gold Menu Button Injected! ✅\n");
    });
}
