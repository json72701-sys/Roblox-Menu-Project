#import <UIKit/UIKit.h>

@interface ExecutorMenu : UIView
@property (nonatomic, strong) UITextView *scriptBox;
@end

@implementation ExecutorMenu
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.95];
        self.layer.cornerRadius = 15;
        self.clipsToBounds = YES;

        // Title
        UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 10, frame.size.width, 30)];
        title.text = @"EXECUTOR MENU";
        title.textColor = [UIColor orangeColor];
        title.textAlignment = NSTextAlignmentCenter;
        title.font = [UIFont boldSystemFontOfSize:18];
        [self addSubview:title];

        // Script Input Box (Detailed)
        self.scriptBox = [[UITextView alloc] initWithFrame:CGRectMake(10, 50, frame.size.width - 20, 150)];
        self.scriptBox.backgroundColor = [UIColor blackColor];
        self.scriptBox.textColor = [UIColor greenColor];
        self.scriptBox.font = [UIFont fontWithName:@"Courier" size:14];
        self.scriptBox.layer.borderWidth = 1;
        self.scriptBox.layer.borderColor = [UIColor orangeColor].CGColor;
        [self addSubview:self.scriptBox];

        // Execute Button
        UIButton *execBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        execBtn.frame = CGRectMake(10, 210, frame.size.width - 20, 40);
        [execBtn setTitle:@"EXECUTE" forState:UIControlStateNormal];
        [execBtn setBackgroundColor:[UIColor orangeColor]];
        execBtn.layer.cornerRadius = 10;
        [execBtn addTarget:self action:@selector(runScript) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:execBtn];
        
        // Close Button
        UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        closeBtn.frame = CGRectMake(frame.size.width - 40, 5, 30, 30);
        [closeBtn setTitle:@"X" forState:UIControlStateNormal];
        [closeBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [closeBtn addTarget:self action:@selector(hideMenu) forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:closeBtn];
    }
    return self;
}

- (void)runScript {
    // Logic to bridge your C++ executor to this string
    NSLog(@"Executing: %@", self.scriptBox.text);
}

- (void)hideMenu {
    self.hidden = YES;
}
@end

// --- Draggable Logic ---
@interface DraggableButton : UIButton
@end

@implementation DraggableButton
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentLocation = [touch locationInView:self.superview];
    self.center = currentLocation; // Makes the logo follow your finger
}
@end

static ExecutorMenu *menu;

__attribute__((constructor))
static void initialize() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = [[UIApplication sharedApplication] keyWindow];

        // Create the detailed menu (hidden by default)
        menu = [[ExecutorMenu alloc] initWithFrame:CGRectMake(win.frame.size.width/2 - 150, win.frame.size.height/2 - 130, 300, 260)];
        menu.hidden = YES;
        menu.layer.zPosition = 10001;
        [win addSubview:menu];

        // Create Draggable Logo Button
        DraggableButton *btn = [DraggableButton buttonWithType:UIButtonTypeCustom];
        [btn setFrame:CGRectMake(50, 100, 60, 60)];
        [btn setTitle:@"GOLD" forState:UIControlStateNormal];
        [btn setBackgroundColor:[UIColor orangeColor]];
        btn.layer.cornerRadius = 30;
        btn.layer.zPosition = 10000;
        
        // Open menu on tap
        [btn addTarget:menu action:@selector(setHidden:) forControlEvents:UIControlEventTouchUpInside];
        [[btn valueForKey:@"target"] setValue:@NO forKey:@"hidden"]; // Simple toggle trick
        
        [win addSubview:btn];
    });
}
