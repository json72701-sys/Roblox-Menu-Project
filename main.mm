#import <UIKit/UIKit.h>

extern "C" void RenderImGuiMenu(bool visible);

static bool isMenuVisible = false;

@interface DraggableLogo : UIButton
@end

@implementation DraggableLogo

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.layer.cornerRadius = frame.size.width / 2.0;
        self.layer.masksToBounds = YES;
        self.layer.zPosition = 10000;
        self.layer.borderWidth = 2.0;
        self.layer.borderColor = [UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:0.8].CGColor;
        self.backgroundColor = [UIColor colorWithRed:0.08 green:0.08 blue:0.15 alpha:0.95];
        self.titleLabel.font = [UIFont boldSystemFontOfSize:11];
        self.titleLabel.numberOfLines = 2;
        self.titleLabel.textAlignment = NSTextAlignmentCenter;

        NSMutableAttributedString *title = [[NSMutableAttributedString alloc]
            initWithString:@"Elxr\nScriptz"
            attributes:@{
                NSFontAttributeName: [UIFont boldSystemFontOfSize:11],
                NSForegroundColorAttributeName: [UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:1.0]
            }];
        [self setAttributedTitle:title forState:UIControlStateNormal];

        self.layer.shadowColor = [UIColor colorWithRed:0.3 green:0.6 blue:1.0 alpha:1.0].CGColor;
        self.layer.shadowOffset = CGSizeZero;
        self.layer.shadowRadius = 8.0;
        self.layer.shadowOpacity = 0.6;
        self.layer.masksToBounds = NO;
    }
    return self;
}

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

        [UIView animateWithDuration:0.15 animations:^{
            self.transform = CGAffineTransformMakeScale(0.85, 0.85);
        } completion:^(BOOL finished) {
            [UIView animateWithDuration:0.15 animations:^{
                self.transform = CGAffineTransformIdentity;
            }];
        }];
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
            DraggableLogo *btn = [[DraggableLogo alloc] initWithFrame:CGRectMake(100, 100, 56, 56)];
            [win addSubview:btn];
        }
    });
}
