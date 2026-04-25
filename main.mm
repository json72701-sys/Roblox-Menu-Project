#import <UIKit/UIKit.h>

// --- CONNECTING YOUR UD LOGIC ---
#include "offsets.hpp"
#include "Methods/DataModel.cpp"
#include "Methods/Executor.hpp"
// --------------------------------

static bool isMenuVisible = false;
static UIView *menuPanel = nil;
static UITextView *scriptInput = nil;
static UILabel *statusLabel = nil;

#pragma mark - Script Execution

static void ExecuteCurrentScript() {
    NSString *scriptText = scriptInput.text;
    if (scriptText.length == 0) {
        statusLabel.text = @"No script to run";
        statusLabel.textColor = [UIColor orangeColor];
        return;
    }

    uintptr_t dm = GetDataModel();
    if (!dm) {
        statusLabel.text = @"DataModel not found";
        statusLabel.textColor = [UIColor redColor];
        return;
    }

    std::string source = std::string([scriptText UTF8String]);
    std::string error;

    // First just compile to verify the script is valid
    std::string bytecode = Executor::CompileScript(source, error);
    if (bytecode.empty()) {
        NSString *errStr = [NSString stringWithUTF8String:error.c_str()];
        statusLabel.text = [NSString stringWithFormat:@"Error: %@", errStr];
        statusLabel.textColor = [UIColor redColor];
        NSLog(@"[ElxrScriptz] Compile error: %@", errStr);
        return;
    }

    // Now execute (compile + inject)
    bool success = Executor::ExecuteScript(dm, source, error);
    if (success) {
        statusLabel.text = @"Script executed!";
        statusLabel.textColor = [UIColor greenColor];
        NSLog(@"[ElxrScriptz] Script executed successfully (%zu bytes bytecode)", bytecode.size());
    } else {
        NSString *errStr = [NSString stringWithUTF8String:error.c_str()];
        statusLabel.text = [NSString stringWithFormat:@"Error: %@", errStr];
        statusLabel.textColor = [UIColor redColor];
        NSLog(@"[ElxrScriptz] Execution error: %@", errStr);
    }
}

#pragma mark - Draggable Logo Button

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

        if (menuPanel) {
            menuPanel.hidden = !isMenuVisible;
        }

        uintptr_t dm = GetDataModel();
        NSLog(@"[ElxrScriptz] DataModel: %p | Menu: %s", (void*)dm, isMenuVisible ? "ON" : "OFF");
    }
}
@end

#pragma mark - Execute Button

@interface ExecuteButton : UIButton
@end

@implementation ExecuteButton
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    UITouch *touch = [touches anyObject];
    CGPoint loc = [touch locationInView:self];
    if ([self pointInside:loc withEvent:event]) {
        ExecuteCurrentScript();
    }
}
@end

#pragma mark - Clear Button

@interface ClearButton : UIButton
@end

@implementation ClearButton
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesEnded:touches withEvent:event];
    UITouch *touch = [touches anyObject];
    CGPoint loc = [touch locationInView:self];
    if ([self pointInside:loc withEvent:event]) {
        scriptInput.text = @"";
        statusLabel.text = @"Cleared";
        statusLabel.textColor = [UIColor lightGrayColor];
    }
}
@end

#pragma mark - UI Setup

static void CreateMenuPanel(UIWindow *win) {
    CGFloat screenW = win.bounds.size.width;
    CGFloat screenH = win.bounds.size.height;
    CGFloat panelW = screenW * 0.85;
    CGFloat panelH = screenH * 0.5;
    CGFloat panelX = (screenW - panelW) / 2;
    CGFloat panelY = (screenH - panelH) / 2;

    // Main panel
    menuPanel = [[UIView alloc] initWithFrame:CGRectMake(panelX, panelY, panelW, panelH)];
    menuPanel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.9];
    menuPanel.layer.cornerRadius = 12;
    menuPanel.layer.borderColor = [UIColor blueColor].CGColor;
    menuPanel.layer.borderWidth = 2;
    menuPanel.layer.zPosition = 9999;
    menuPanel.hidden = YES;
    menuPanel.clipsToBounds = YES;

    // Title bar
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, panelW, 36)];
    title.text = @"  ElxrScriptz - Script Executor";
    title.textColor = [UIColor cyanColor];
    title.font = [UIFont boldSystemFontOfSize:15];
    title.backgroundColor = [[UIColor darkGrayColor] colorWithAlphaComponent:0.6];
    [menuPanel addSubview:title];

    // Script text input
    CGFloat inputY = 40;
    CGFloat inputH = panelH - 120;
    scriptInput = [[UITextView alloc] initWithFrame:CGRectMake(8, inputY, panelW - 16, inputH)];
    scriptInput.backgroundColor = [[UIColor darkGrayColor] colorWithAlphaComponent:0.5];
    scriptInput.textColor = [UIColor whiteColor];
    scriptInput.font = [UIFont fontWithName:@"Menlo" size:13];
    scriptInput.layer.cornerRadius = 6;
    scriptInput.text = @"-- Paste your Luau script here\nprint('Hello from ElxrScriptz!')";
    scriptInput.autocorrectionType = UITextAutocorrectionTypeNo;
    scriptInput.autocapitalizationType = UITextAutocapitalizationTypeNone;
    scriptInput.keyboardAppearance = UIKeyboardAppearanceDark;
    [menuPanel addSubview:scriptInput];

    // Button row
    CGFloat btnY = inputY + inputH + 8;
    CGFloat btnW = (panelW - 24) / 2;
    CGFloat btnH = 36;

    // Execute button
    ExecuteButton *execBtn = [ExecuteButton buttonWithType:UIButtonTypeCustom];
    execBtn.frame = CGRectMake(8, btnY, btnW, btnH);
    [execBtn setTitle:@"Execute" forState:UIControlStateNormal];
    [execBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    execBtn.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
    execBtn.layer.cornerRadius = 6;
    execBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [menuPanel addSubview:execBtn];

    // Clear button
    ClearButton *clearBtn = [ClearButton buttonWithType:UIButtonTypeCustom];
    clearBtn.frame = CGRectMake(16 + btnW, btnY, btnW, btnH);
    [clearBtn setTitle:@"Clear" forState:UIControlStateNormal];
    [clearBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    clearBtn.backgroundColor = [UIColor darkGrayColor];
    clearBtn.layer.cornerRadius = 6;
    clearBtn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [menuPanel addSubview:clearBtn];

    // Status label
    statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(8, btnY + btnH + 4, panelW - 16, 20)];
    statusLabel.text = @"Ready";
    statusLabel.textColor = [UIColor lightGrayColor];
    statusLabel.font = [UIFont systemFontOfSize:12];
    [menuPanel addSubview:statusLabel];

    [win addSubview:menuPanel];
}

#pragma mark - Entry Point

__attribute__((constructor))
static void initialize() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIWindow *win = nil;
        for (UIWindow *window in [UIApplication sharedApplication].windows) {
            if (window.isKeyWindow) { win = window; break; }
        }

        if (win) {
            // Create the script executor panel
            CreateMenuPanel(win);

            // Create the draggable toggle button
            DraggableLogo *btn = [DraggableLogo buttonWithType:UIButtonTypeCustom];
            [btn setFrame:CGRectMake(100, 100, 60, 60)];
            [btn setTitle:@"ELXR" forState:UIControlStateNormal];
            [btn setBackgroundColor:[UIColor blueColor]];
            btn.layer.cornerRadius = 30;
            btn.layer.zPosition = 10000;
            [win addSubview:btn];

            NSLog(@"[ElxrScriptz] Initialized with Luau compiler");
        }
    });
}
