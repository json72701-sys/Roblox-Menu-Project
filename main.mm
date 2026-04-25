#import <UIKit/UIKit.h>

__attribute__((constructor))
static void initialize() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = [[UIApplication sharedApplication] keyWindow];
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setFrame:CGRectMake(100, 100, 60, 60)];
        [btn setBackgroundColor:[UIColor yellowColor]];
        [btn setTitle:@"GOLD" forState:UIControlStateNormal];
        btn.layer.cornerRadius = 30;
        btn.layer.zPosition = 1000;
        [win addSubview:btn];
    });
}
