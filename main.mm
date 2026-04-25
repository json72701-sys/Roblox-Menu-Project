#include <UIKit/UIKit.h>

__attribute__((constructor))
static void initialize() {
    // This waits for the game to actually exist before popping the UI
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = [[UIApplication sharedApplication] keyWindow];
        
        // Create a Gold Button to open the menu
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setFrame:CGRectMake(20, 40, 60, 60)];
        [btn setTitle:@"GOLD" forState:UIControlStateNormal];
        [btn setBackgroundColor:[UIColor orangeColor]];
        btn.layer.cornerRadius = 30;
        btn.layer.zPosition = 10000;
        
        [win addSubview:btn];
    });
}
