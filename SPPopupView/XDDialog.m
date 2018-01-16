//
//  XDDialog.m
//  SPPopupView
//
//  Created by suxinde on 2018/1/16.
//  Copyright © 2018年 com.su. All rights reserved.
//

#import "XDDialog.h"
#import <QuartzCore/QuartzCore.h>

#define LogSelfFrameSwitcher           0 // 1
#define LogAccessoryViewSwitcher       0 // 1
#define LogTitleRectSwitcher           0 // 1
#define LogSubtitleRectSwitcher        0 // 1
#define LogTextFieldsRectSwitcher      0 // 1
#define LogButtonsRectSwitcher         0 // 1
#define LogAccessoryViewRectSwitcher   0 // 1


#ifndef kApplicationFrame
#define kApplicationFrame [[UIScreen mainScreen] applicationFrame]
#endif

bool isPad()
{
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_3_2
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return true;
    }
#endif
    return false;
}


@interface XDDialogTextField : UITextField
@property (nonatomic, retain) XDDialog *dialog;
@end

@interface XDDialogWindowOverlay : UIWindow
@end


@interface XDDialog ()
@property (nonatomic, retain) XDDialogWindowOverlay *overlay;
@property (nonatomic, retain) UIWindow *hostWindow;
@property (nonatomic, retain) UIView *contentView;
@property (nonatomic, retain) UIView *accessoryView;
@property (nonatomic, retain) NSMutableArray *textFields;
@property (nonatomic, retain) NSMutableArray *buttons;
@property (nonatomic, retain) UIFont *titleFont;
@property (nonatomic, retain) UIFont *subtitleFont;
@property (nonatomic, assign) NSInteger highlightedIndex;
//
- (UIColor *)shadowColor;
- (UIColor *)translucentBlueColor;
- (CGColorSpaceRef)genericRGBSpace;
@end

#define XDDialogSynthesize(x) @synthesize x = x##_
#define XDDialogAssertMQ() NSAssert(dispatch_get_current_queue() == dispatch_get_main_queue(), @"%@ must be called on main queue", NSStringFromSelector(_cmd));


#define kXDDialogAnimationDuration   0.15f
#define kXDDialogPopScale            0.5f
#define kXDDialogPadding             8.0f
#define kXDDialogFrameInset          8.0f
#define kXDDialogButtonHeight        44.0f
#define kXDDialogTextFieldHeight     32.0f

@implementation XDDialog
XDDialogSynthesize(customView);
XDDialogSynthesize(dialogStyle);
XDDialogSynthesize(title);
XDDialogSynthesize(subtitle);
XDDialogSynthesize(batchDelay);
XDDialogSynthesize(overlay);
XDDialogSynthesize(hostWindow);
XDDialogSynthesize(contentView);
XDDialogSynthesize(accessoryView);
XDDialogSynthesize(textFields);
XDDialogSynthesize(buttons);
XDDialogSynthesize(titleFont);
XDDialogSynthesize(subtitleFont);
XDDialogSynthesize(highlightedIndex);
XDDialogSynthesize(delegate);
XDDialogSynthesize(isShowing);

+ (id)dialogWithWindow:(UIWindow *)hostWindow
{
    return [[self alloc] initWithWindow:hostWindow];
}

- (id)initWithWindow:(UIWindow *)hostWindow
{
    isShowing_ = FALSE;
    //CGRect insetFrame = CGRectIntegral(CGRectInset(kApplicationFrame, 20.0f, 20.0f));
    //insetFrame.size.height = 180.0f;
    CGRect insetFrame = CGRectIntegral(CGRectInset(CGRectMake(0.0f, 0.0f, 320.0f, 180.0f), 20.0f, 20.0f));
    
    self = [super initWithFrame:insetFrame];
    if(self){
        
        self.batchDelay = 0.0f;
        self.highlightedIndex = -1;
        self.titleFont = [UIFont boldSystemFontOfSize:18.0f];
        self.subtitleFont = [UIFont systemFontOfSize:14.0f];
        self.hostWindow = hostWindow;
        self.opaque = NO;
        self.alpha = 1.0f;
        self.buttons = [NSMutableArray array];
        self.textFields = [NSMutableArray array];
        
        // Register for keyboard notifications
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
        [nc addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    }
    return self;
}

////////////////////////////////////////////////////////////////////////////////////
//  Background color
///////////////////////////////////////////////////////////////////////////////////
- (UIColor *)shadowColor
{
    static CGColorRef shadowColorRef = NULL;
    if (shadowColorRef == NULL)
    {
        CGFloat values[4] = {0.0, 0.0, 0.0, 0.5};
        shadowColorRef = CGColorCreate([self genericRGBSpace], values);
    }
    UIColor *shadowColor = [UIColor colorWithCGColor:shadowColorRef];
    return shadowColor;
}
- (UIColor *)translucentBlueColor
{
    static CGColorRef translucentBlueRef = NULL;
    if (translucentBlueRef == NULL)
    {
        CGFloat values[4] = {0.13, 0.24, 0.44, 0.7};
        translucentBlueRef = CGColorCreate([self genericRGBSpace], values);
    }
    UIColor *translucentBlue = [UIColor colorWithCGColor:translucentBlueRef];
    return translucentBlue;
}

- (CGColorSpaceRef)genericRGBSpace
{
    static CGColorSpaceRef space = NULL;
    if (space == NULL)
    {
        space = CGColorSpaceCreateDeviceRGB();
    }
    return space;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)adjustToKeyboardBounds:(CGRect)bounds {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    CGFloat height = CGRectGetHeight(screenBounds) - CGRectGetHeight(bounds);
    
    CGRect frame  = self.frame;
    frame.origin.y = (height - CGRectGetHeight(self.bounds)) / 2.0f;
    
    if(CGRectGetMinY(frame) < 0){
        NSLog(@"Warning: Dialog is clipped, origin negative (%f)", CGRectGetMinY(frame));
    }
    
    [UIView animateWithDuration:kXDDialogAnimationDuration delay:0.0f options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        self.frame = frame;
    } completion:^(BOOL finished) {
        
    }];
}

- (void)keyboardWillShow:(NSNotification *)note
{
    NSValue *value = [[note userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey];
    CGRect frame = [value CGRectValue];
    [self adjustToKeyboardBounds:frame];
}



- (void)keyboardWillHide:(NSNotification *)note
{
    [self adjustToKeyboardBounds:CGRectZero];
}

- (CGRect)defaultDialogFrame
{
    //CGRect insetFrame = CGRectIntegral(CGRectInset(kApplicationFrame, 20.0f, 20.0f));
    //insetFrame.size.height = 180.0f;
    CGRect insetFrame = CGRectIntegral(CGRectInset(CGRectMake(0.0f, 0.0f, 320.0f, 180.0f), 20.0f, 20.0f));
    return insetFrame;
}

- (void)setProgress:(CGFloat)progress
{
    UIProgressView *view = (id)self.accessoryView;
    if([view isKindOfClass:[UIProgressView class]]){
        [view setProgress:progress];
    }
}

- (CGFloat)progress
{
    UIProgressView *view = (id)self.accessoryView;
    if([view isKindOfClass:[UIProgressView class]]){
        return view.progress;
    }
    return 0.0f;
}

- (UIView *)makeAccessoryView{
    
    if(self.dialogStyle == XDDialogStyleIndeterminate){
        
        UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        [activityView startAnimating];
        return activityView;
        
    } else if (self.dialogStyle == XDDialogStyleDeterminate) {
        
        UIProgressView *progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
        progressView.frame = CGRectMake(0.0f, 0.0f, 200.0f, progressView.bounds.size.height);
        return progressView;
        
    } else if (self.dialogStyle == XDDialogStyleSuccess || self.dialogStyle == XDDialogStyleError) {
        
        CGSize iconSize = CGSizeMake(64.0f, 64.0f);
        UIGraphicsBeginImageContextWithOptions(iconSize, NO, 0.0);
        
        [self drawSymbolInRect:(CGRect){CGPointZero, iconSize}];
        
        UIImageView *imageView = [[UIImageView alloc] initWithImage:UIGraphicsGetImageFromCurrentImageContext()];
        UIGraphicsEndImageContext();
        return imageView;
        
    } else if (self.dialogStyle == XDDialogStyleCustomView) {
        
        return self.customView;
        
    }
    return nil;
}

- (void)layoutComponents {
    
    [self setNeedsDisplay];
    
    // Computes frames of components
    CGFloat layoutFrameInset = kXDDialogFrameInset + kXDDialogPadding;
    CGRect layoutFrame = CGRectInset(self.bounds, layoutFrameInset, layoutFrameInset);
    CGFloat layoutWidth = CGRectGetWidth(layoutFrame);
    
    // Title frame
    CGFloat titleHeight = 0.0f;
    CGFloat minY = CGRectGetMinY(layoutFrame);
    if(self.title.length > 0){
        titleHeight = [self.title sizeWithFont:self.titleFont
                             constrainedToSize:CGSizeMake(layoutWidth, MAXFLOAT)
                                 lineBreakMode:UILineBreakModeWordWrap].height;
        minY += kXDDialogPadding;
    }
    layout.titleRect = CGRectMake(CGRectGetMinX(layoutFrame), minY, layoutWidth, titleHeight);
#if LogTitleRectSwitcher
    NSLog(@"layout.titleRect: %f %f %f %f", CGRectGetMinX(layoutFrame), minY, layoutWidth, titleHeight);
#endif
    
    // Subtitle frame
    CGFloat subtitleHeight = 0.0f;
    minY = CGRectGetMaxY(layout.titleRect);
    if(self.subtitle.length > 0){
        subtitleHeight = [self.subtitle sizeWithFont:self.subtitleFont
                                   constrainedToSize:CGSizeMake(layoutWidth, MAXFLOAT)
                                       lineBreakMode:UILineBreakModeWordWrap].height;
        minY += kXDDialogPadding;
    }
    layout.subtitleRect = CGRectMake(CGRectGetMinX(layoutFrame), minY, layoutWidth, subtitleHeight);
#if LogSubtitleRectSwitcher
    NSLog(@"layout.subtitleRect: %f %f %f %f", CGRectGetMinX(layoutFrame), minY, layoutWidth, subtitleHeight);
#endif
    
    // Accessory frame !Note: views are in the content view coordinate system
    self.accessoryView = [self makeAccessoryView];
    self.accessoryView.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin;
#if LogAccessoryViewRectSwitcher
    NSLog(@"accessory View frame: %f %f %f %f", self.accessoryView.frame.origin.x,self.accessoryView.frame.origin.y,self.accessoryView.frame.size.width,self.accessoryView.frame.size.height);
#endif
    CGFloat accessoryHeight = 0.0f;
    CGFloat accessoryWidth = CGRectGetWidth(layoutFrame);
    CGFloat accessoryLeft = 0.0f;
    
    minY = CGRectGetMaxY(layout.subtitleRect) - layoutFrameInset;
    
    if(self.accessoryView != nil){
        accessoryHeight = CGRectGetHeight(self.accessoryView.frame);
        accessoryWidth = CGRectGetWidth(self.accessoryView.frame);
        accessoryLeft = (CGRectGetWidth(layoutFrame)-accessoryWidth) / 2.0f;
        minY += kXDDialogPadding;
    }
    layout.accessoryRect = CGRectMake(accessoryLeft, minY, accessoryWidth, accessoryHeight);
#if LogAccessoryViewSwitcher
    NSLog(@"layout.accessoryRect: %f %f %f %f", accessoryLeft, minY, accessoryWidth, accessoryHeight);
#endif
    
    
    // Text Fields frame !NOTE: views are in the content view coordinate system
    CGFloat textFieldsHeight = 0;
    NSUInteger numTextFields = self.textFields.count;
    
    minY = CGRectGetMaxY(layout.accessoryRect);
    if(numTextFields > 0)
    {
        textFieldsHeight = kXDDialogTextFieldHeight * (CGFloat)numTextFields + kXDDialogPadding * ((CGFloat)numTextFields - 1.0);
        minY += kXDDialogPadding;
    }
    layout.textFieldRect = CGRectMake(CGRectGetMinX(layoutFrame), minY, layoutWidth, textFieldsHeight);
#if LogTextFieldsRectSwitcher
    NSLog(@"layout.textFieldRect: %f %f %f %f", CGRectGetMinX(layoutFrame), minY, layoutWidth, textFieldsHeight);
#endif
    
    
    // Buttons frame !NOTE: views are in the content view coordinate system
    CGFloat buttonsHeight = 0.0f;
    minY = CGRectGetMaxY(layout.textFieldRect);
    if(self.buttons.count > 0){
        buttonsHeight = kXDDialogButtonHeight;
        minY += kXDDialogPadding;
    }
    layout.buttonRect = CGRectMake(CGRectGetMinX(layoutFrame), minY, layoutWidth, buttonsHeight);
#if LogButtonsRectSwitcher
    NSLog(@"layout.buttonRect: %f %f %f %f", CGRectGetMinX(layoutFrame), minY, layoutWidth, buttonsHeight);
#endif
    
    
    // Adjust layout frame
    layoutFrame.size.height = CGRectGetMaxY(layout.buttonRect);
    
    // Create new content view
    UIView *newContentView = [[UIView alloc] initWithFrame:layoutFrame];
    newContentView.contentMode = UIViewContentModeRedraw;
    
    // Layout accessory view
    self.accessoryView.frame = layout.accessoryRect;
    [newContentView addSubview:self.accessoryView];
    
    // Layout text fields
    if(numTextFields > 0){
        for(int i = 0; i < numTextFields; i++){
            CGFloat offsetY = (kXDDialogTextFieldHeight + kXDDialogPadding) * (CGFloat)i;
            CGRect fieldFrame = CGRectMake(0,
                                           CGRectGetMinY(layout.textFieldRect)+offsetY,
                                           layoutWidth,
                                           kXDDialogTextFieldHeight);
            
            
            UITextField *field = [self.textFields objectAtIndex:i];
            field.frame = fieldFrame;
            field.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin;
            [field.layer setCornerRadius:10.0f];
            [newContentView addSubview:field];
        }
    }
    
    // Layout buttons
    NSUInteger count = self.buttons.count;
    if(count > 0){
        CGFloat buttonWidth = (CGRectGetWidth(layout.buttonRect)-kXDDialogPadding *((CGFloat)count - 1.0)) / (CGFloat)count;
        for(int i = 0; i < count; i++){
            CGFloat left = (kXDDialogPadding + buttonWidth) * (CGFloat)i;
            CGRect buttonFrame = CGRectIntegral(CGRectMake(left, CGRectGetMinY(layout.buttonRect), buttonWidth, CGRectGetHeight(layout.buttonRect)));
            UIButton *button = [self.buttons objectAtIndex:i];
            button.frame = buttonFrame;
            button.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin;
            
            BOOL highlighted = (self.highlightedIndex == i);
            NSString *title = [button titleForState:UIControlStateNormal];
            
            // set default image
            UIGraphicsBeginImageContextWithOptions(buttonFrame.size, NO, 0);
            [self drawButtonInRect:(CGRect){CGPointZero, buttonFrame.size} title:title highlighted:highlighted down:NO];
            
            [button setImage:UIGraphicsGetImageFromCurrentImageContext() forState:UIControlStateNormal];
            
            UIGraphicsEndImageContext();
            
            // Set alternate image
            UIGraphicsBeginImageContextWithOptions(buttonFrame.size, NO, 0);
            
            [self drawButtonInRect:(CGRect){CGPointZero, buttonFrame.size} title:title highlighted:NO down:YES];
            [button setImage:UIGraphicsGetImageFromCurrentImageContext() forState:UIControlStateHighlighted];
            
            UIGraphicsEndImageContext();
            
            [newContentView addSubview:button];
        }
    }
    
    // Fade content views
    CGFloat animationDuration = kXDDialogAnimationDuration;
    if (self.contentView.superview != nil) {
        [UIView transitionFromView:self.contentView
                            toView:newContentView
                          duration:animationDuration
                           options:UIViewAnimationOptionTransitionNone //UIViewAnimationOptionTransitionCrossDissolve
                        completion:^(BOOL finished) {
                            self.contentView = newContentView;
                        }];
    } else {
        self.contentView = newContentView;
        [self addSubview:newContentView];
        
        // Don't animate frame adjust if there was no content before
        animationDuration = 0;
    }
    
    // Adjust frame size
    [UIView animateWithDuration:animationDuration delay:0 options:UIViewAnimationOptionLayoutSubviews animations:^{
        CGRect dialogFrame = CGRectInset(layoutFrame,
                                         -kXDDialogFrameInset - kXDDialogPadding,
                                         -kXDDialogFrameInset - kXDDialogPadding);
        dialogFrame.origin.x = (CGRectGetWidth(self.hostWindow.bounds) - CGRectGetWidth(dialogFrame)) / 2.0;
        dialogFrame.origin.y = (CGRectGetHeight(self.hostWindow.bounds) - CGRectGetHeight(dialogFrame)) / 2.0;
        
        self.frame = CGRectIntegral(dialogFrame);
    } completion:^(BOOL finished) {
        [self setNeedsDisplay];
    }];
    
}



- (void)resetLayout {
    self.title = nil;
    self.subtitle = nil;
    self.dialogStyle = XDDialogStyleDefault;
    self.progress = 0;
    self.customView = nil;
    
    [self removeAllControls];
}

- (void)removeAllControls {
    [self removeAllTextFields];
    [self removeAllButtons];
}

- (void)removeAllTextFields {
    [self.textFields removeAllObjects];
}

- (void)removeAllButtons {
    [self.buttons removeAllObjects];
    self.highlightedIndex = -1;
}

- (void)addTextFieldWithPlaceholder:(NSString *)placeholder secure:(BOOL)secure {
    for (UITextField *field in self.textFields) {
        field.returnKeyType = UIReturnKeyNext;
    }
    
    XDDialogTextField *field = [[XDDialogTextField alloc] initWithFrame:CGRectMake(0, 0, 200, kXDDialogTextFieldHeight)];
    field.dialog = self;
    field.returnKeyType = UIReturnKeyDone;
    field.placeholder = placeholder;
    field.secureTextEntry = secure;
    field.font = [UIFont systemFontOfSize:20.0f];
    field.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    field.textColor = [UIColor blackColor];
    field.keyboardAppearance = UIKeyboardAppearanceDefault;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.delegate = (id)self;
    
    [self.textFields addObject:field];
}

- (void)addButtonWithTitle:(NSString *)title target:(id)target selector:(SEL)sel {
    [self addButtonWithTitle:title target:target selector:sel highlighted:NO];
}

- (void)addButtonWithTitle:(NSString *)title target:(id)target selector:(SEL)sel highlighted:(BOOL)flag {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    
    [button setTitle:title forState:UIControlStateNormal];
    [button addTarget:target action:sel forControlEvents:UIControlEventTouchUpInside];
    
    if (flag) {
        self.highlightedIndex = self.buttons.count;
    }
    
    [self.buttons addObject:button];
}

- (NSString *)textForTextFieldAtIndex:(NSUInteger)index {
    UITextField *field = [self.textFields objectAtIndex:index];
    return [field text];
}

- (void)showOrUpdateAnimatedInternal:(BOOL)flag {
    isShowing_ = TRUE;
    if (self.delegate) {
        if([self.delegate respondsToSelector:@selector(willPresentDialog:)]){
            [self.delegate willPresentDialog:self];
        }
    }
    
    XDDialogAssertMQ();
    
    XDDialogWindowOverlay *overlay = self.overlay;
    BOOL show = (overlay == nil);
    
    // Create overlay
    if (show) {
        self.overlay = overlay = [[XDDialogWindowOverlay alloc] init];
        overlay.opaque = NO;
        overlay.windowLevel = UIWindowLevelStatusBar + 1;
        overlay.frame = self.hostWindow.bounds;
        overlay.alpha = 0.0;
    }
    
    // Layout components
    [self layoutComponents];
    
    if (show) {
        // Scale down ourselves for pop animation
        self.transform = CGAffineTransformMakeScale(kXDDialogPopScale, kXDDialogPopScale);
        
        // Animate
        NSTimeInterval animationDuration = (flag ? kXDDialogAnimationDuration : 0.0);
        [UIView animateWithDuration:animationDuration delay:0 options:UIViewAnimationOptionLayoutSubviews animations:^{
            overlay.alpha = 1.0;
            self.transform = CGAffineTransformIdentity;
        } completion:^(BOOL finished) {
            // stub
        }];
        
        [overlay addSubview:self];
        [overlay makeKeyAndVisible];
    }
    
    if(self.delegate){
        if([self.delegate respondsToSelector:@selector(didPresentDialog:)]){
            [self.delegate didPresentDialog:self];
        }
    }
}

- (void)showOrUpdateAnimated:(BOOL)flag {
    XDDialogAssertMQ();
    SEL selector = @selector(showOrUpdateAnimatedInternal:);
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:selector object:nil];
    [self performSelector:selector withObject:[NSNumber numberWithBool:flag] afterDelay:self.batchDelay];
}

- (void)hideAnimated:(BOOL)flag {
    isShowing_ = FALSE;
    XDDialogAssertMQ();
    XDDialogWindowOverlay *overlay = self.overlay;
    
    // Nothing to hide if it is not key window
    if (overlay == nil) {
        return;
    }
    
    NSTimeInterval animationDuration = (flag ? kXDDialogAnimationDuration : 0.0);
    [UIView animateWithDuration:animationDuration delay:0 options:UIViewAnimationOptionLayoutSubviews animations:^{
        overlay.alpha = 0.0;
        self.transform = CGAffineTransformMakeScale(kXDDialogPopScale, kXDDialogPopScale);
    } completion:^(BOOL finished) {
        overlay.hidden = YES;
        self.transform = CGAffineTransformIdentity;
        [self removeFromSuperview];
        self.overlay = nil;
        
        // Rekey host window
        // https://github.com/eaigner/CODialog/issues/6
        //
        [self.hostWindow makeKeyWindow];
    }];
    
    // !Note: 不确定，用于保证弹框确实退出后执行对应的委托方法
    
    if(self.delegate && [self.delegate respondsToSelector:@selector(didDismissDialog:)]){
        double delayInSeconds = 0.5;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self.delegate didDismissDialog:self];
        });
    }
    
}

- (void)hideAnimated:(BOOL)flag afterDelay:(NSTimeInterval)delay {
    XDDialogAssertMQ();
    
    SEL selector = @selector(hideAnimated:);
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:selector object:nil];
    [self performSelector:selector withObject:[NSNumber numberWithBool:flag] afterDelay:delay];
}

- (void)drawDialogBackgroundInRect:(CGRect)rect {
    // General Declarations
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Set alpha
    CGContextSaveGState(context);
    CGContextSetAlpha(context, 0.65);
    
    // Color Declarations
    UIColor *color = [UIColor colorWithRed:0.047 green:0.141 blue:0.329 alpha:1.0];
    
    // Gradient Declarations
    size_t num_locations = 2;
    CGFloat gradientLocations[] = {0, 1};
    CGFloat components[12] = { 1.0, 1.0, 1.0, 0.75,         // Start color
        0.227, 0.310, 0.455, 0.8 };  // End color
    CGGradientRef gradient2 = CGGradientCreateWithColorComponents(colorSpace, components, gradientLocations, num_locations);
    
    
    // Abstracted Graphic Attributes
    CGFloat cornerRadius = 8.0;
    CGFloat strokeWidth = 2.0;
    CGColorRef dialogShadow = [UIColor blackColor].CGColor;
    CGSize shadowOffset = CGSizeMake(0, 4);
    CGFloat shadowBlurRadius = kXDDialogFrameInset - 2.0;
    
    CGRect frame = CGRectInset(CGRectIntegral(self.bounds), kXDDialogFrameInset, kXDDialogFrameInset);
    
    // Rounded Rectangle Drawing
    UIBezierPath *roundedRectanglePath = [UIBezierPath bezierPathWithRoundedRect:frame cornerRadius:cornerRadius];
    
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context, shadowOffset, shadowBlurRadius, dialogShadow);
    
    [color setFill];
    [roundedRectanglePath fill];
    
    CGContextRestoreGState(context);
    
    // Set clip path
    [roundedRectanglePath addClip];
    
    // Bezier Drawing
    CGFloat mx = CGRectGetMinX(frame);
    CGFloat my = CGRectGetMinY(frame);
    CGFloat w = CGRectGetWidth(frame);
    CGFloat w2 = w / 2.0;
    CGFloat w4 = w / 4.0;
    CGFloat h1 = 25;
    CGFloat h2 = 35;
    
    UIBezierPath *bezierPath = [UIBezierPath bezierPath];
    [bezierPath moveToPoint:CGPointMake(mx, h1)];
    [bezierPath addCurveToPoint:CGPointMake(mx + w2, h2)
                  controlPoint1:CGPointMake(mx, h1)
                  controlPoint2:CGPointMake(mx + w4, h2)];
    
    [bezierPath addCurveToPoint:CGPointMake(mx + w, h1)
                  controlPoint1:CGPointMake(mx + w2 + w4, h2)
                  controlPoint2:CGPointMake(mx + w, h1)];
    
    [bezierPath addCurveToPoint:CGPointMake(mx + w, my) controlPoint1:CGPointMake(mx + w, h1) controlPoint2:CGPointMake(mx + w, my)];
    [bezierPath addCurveToPoint:CGPointMake(mx, my) controlPoint1:CGPointMake(mx + w, my) controlPoint2:CGPointMake(mx, my)];
    [bezierPath addLineToPoint:CGPointMake(mx, h1)];
    [bezierPath closePath];
    
    CGContextSaveGState(context);
    
    [bezierPath addClip];
    
    CGContextDrawLinearGradient(context, gradient2, CGPointMake(w2, 0), CGPointMake(w2, h2), 0);
    CGContextRestoreGState(context);
    
    // Stroke
    [[UIColor whiteColor] setStroke];
    UIBezierPath *strokePath = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(frame, strokeWidth / 2.0, strokeWidth / 2.0)
                                                          cornerRadius:cornerRadius - strokeWidth / 2.0];
    strokePath.lineWidth = strokeWidth;
    
    [strokePath stroke];
    
    // Cleanup
    CGGradientRelease(gradient2);
    CGColorSpaceRelease(colorSpace);
    CGContextRestoreGState(context);
}

- (void)drawButtonInRect:(CGRect)rect title:(NSString *)title highlighted:(BOOL)highlighted down:(BOOL)down {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGContextSaveGState(ctx);
    
    CGFloat radius = 6.0f;//4.0;
    CGFloat strokeWidth = 1.0;
    
    CGRect frame = CGRectIntegral(rect);
    CGRect buttonFrame = CGRectInset(frame, 0, 1);
    
    // Gradient declarations
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    size_t num_locations = 3;
    CGFloat gradientLocations[] = {0, 0.5, 0.5, 1};
    CGFloat components[12] = { 1.0, 1.0, 1.0, 0.35,  // Start color
        1.0, 1.0, 1.0, 0.10,  // Mid colors
        1.0, 1.0, 1.0, 0.0 }; // End color
    
    /*
     // Color declarations
     UIColor* whiteTop = [UIColor colorWithWhite:1.0 alpha:0.35];
     UIColor* whiteMiddle = [UIColor colorWithWhite:1.0 alpha:0.10];
     UIColor* whiteBottom = [UIColor colorWithWhite:1.0 alpha:0.0];
     */
    CGGradientRef gradient = CGGradientCreateWithColorComponents(colorSpace, components, gradientLocations, num_locations);
    
    
    
    CGColorSpaceRelease(colorSpace);
    
    // Bottom shadow
    UIBezierPath *fillPath = [UIBezierPath bezierPathWithRoundedRect:buttonFrame cornerRadius:radius];
    
    UIBezierPath *clipPath = [UIBezierPath bezierPathWithRect:frame];
    [clipPath appendPath:fillPath];
    [clipPath setUsesEvenOddFillRule:YES];
    
    CGContextSaveGState(ctx);
    
    [clipPath addClip];
    [[UIColor blackColor] setFill];
    
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 0, [UIColor colorWithWhite:1.0 alpha:0.25].CGColor);
    
    [fillPath fill];
    
    CGContextRestoreGState(ctx);
    
    // Top shadow
    CGContextSaveGState(ctx);
    
    [fillPath addClip];
    [[UIColor blackColor] setFill];
    
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 2), 0, [UIColor colorWithWhite:1.0 alpha:0.25].CGColor);
    
    [clipPath fill];
    
    CGContextRestoreGState(ctx);
    
    // Button gradient
    CGContextSaveGState(ctx);
    [fillPath addClip];
    
    CGContextDrawLinearGradient(ctx,
                                gradient,
                                CGPointMake(CGRectGetMidX(buttonFrame), CGRectGetMinY(buttonFrame)),
                                CGPointMake(CGRectGetMidX(buttonFrame), CGRectGetMaxY(buttonFrame)), 0);
    CGContextRestoreGState(ctx);
    CGGradientRelease(gradient);
    
    // Draw highlight or down state
    if (highlighted) {
        CGContextSaveGState(ctx);
        
        [[UIColor colorWithWhite:1.0 alpha:0.25] setFill];
        [fillPath fill];
        
        CGContextRestoreGState(ctx);
    } else if (down) {
        CGContextSaveGState(ctx);
        
        [[UIColor colorWithWhite:0.0 alpha:0.25] setFill];
        [fillPath fill];
        
        CGContextRestoreGState(ctx);
    }
    
    // Button stroke
    UIBezierPath *strokePath = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(buttonFrame, strokeWidth / 2.0, strokeWidth / 2.0)
                                                          cornerRadius:radius - strokeWidth / 2.0];
    
    [[UIColor colorWithWhite:0.0 alpha:0.8] setStroke];
    [strokePath stroke];
    
    // Draw title
    CGFloat fontSize = 18.0;
    CGRect textFrame = CGRectIntegral(CGRectMake(0, (CGRectGetHeight(rect) - fontSize) / 2.0 - 1.0, CGRectGetWidth(rect), fontSize));
    
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0.0, -1.0), 0.0, [UIColor blackColor].CGColor);
    
    [[UIColor whiteColor] set];
    [title drawInRect:textFrame withFont:self.titleFont lineBreakMode:UILineBreakModeMiddleTruncation alignment:UITextAlignmentCenter];
    
    CGContextRestoreGState(ctx);
    
    // Restore
    CGContextRestoreGState(ctx);
}

- (void)drawTitleInRect:(CGRect)rect isSubtitle:(BOOL)isSubtitle {
    NSString *title = (isSubtitle ? self.subtitle : self.title);
    if (title.length > 0) {
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextSaveGState(ctx);
        
        CGContextSetShadowWithColor(ctx, CGSizeMake(0.0, -1.0), 0.0, [UIColor blackColor].CGColor);
        
        UIFont *font = (isSubtitle ? self.subtitleFont : self.titleFont);
        
        [[UIColor whiteColor] set];
        
        [title drawInRect:rect withFont:font lineBreakMode:UILineBreakModeWordWrap/*UILineBreakModeMiddleTruncation*/ alignment:UITextAlignmentCenter];
        
        CGContextRestoreGState(ctx);
    }
}

- (void)drawSymbolInRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    
    // Bezier Drawing
    UIBezierPath *bezierPath = [UIBezierPath bezierPath];
    if (self.dialogStyle == XDDialogStyleSuccess) {
        [bezierPath moveToPoint:CGPointMake(16, 23)];
        [bezierPath addLineToPoint:CGPointMake(27, 34)];
        [bezierPath addLineToPoint:CGPointMake(56, 5)];
        [bezierPath addLineToPoint:CGPointMake(63, 12)];
        [bezierPath addLineToPoint:CGPointMake(27, 48)];
        [bezierPath addLineToPoint:CGPointMake(9, 30)];
        [bezierPath addLineToPoint:CGPointMake(16, 23)];
    } else {
        [bezierPath moveToPoint: CGPointMake(11, 17)];
        [bezierPath addLineToPoint: CGPointMake(19, 9)];
        [bezierPath addLineToPoint: CGPointMake(33, 23)];
        [bezierPath addLineToPoint: CGPointMake(47, 9)];
        [bezierPath addLineToPoint: CGPointMake(55, 17)];
        [bezierPath addLineToPoint: CGPointMake(41, 31)];
        [bezierPath addLineToPoint: CGPointMake(55, 45)];
        [bezierPath addLineToPoint: CGPointMake(47, 53)];
        [bezierPath addLineToPoint: CGPointMake(33, 39)];
        [bezierPath addLineToPoint: CGPointMake(19, 53)];
        [bezierPath addLineToPoint: CGPointMake(11, 45)];
        [bezierPath addLineToPoint: CGPointMake(25, 31)];
        [bezierPath addLineToPoint: CGPointMake(11, 17)];
    }
    
    [bezierPath closePath];
    
    // Determine scale (the default side is 64)
    CGPoint offset = CGPointMake((CGRectGetWidth(rect) - 64.0) / 2.0, (CGRectGetHeight(rect) - 64.0) / 2.0);
    
    [bezierPath applyTransform:CGAffineTransformMakeTranslation(offset.x, offset.y)];
    [bezierPath fill];
    [bezierPath addClip];
    
    [[UIColor colorWithWhite:0.95f alpha:1.0f] setFill];
    CGContextAddPath(context, bezierPath.CGPath);
    CGContextFillPath(context);
    CGContextRestoreGState(context);
}

- (void)drawTextFieldInRect:(CGRect)rect {
    // General Declarations
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextSaveGState(context);
    
    // Color Declarations
    UIColor *white10 = [UIColor colorWithWhite:1.0 alpha:0.1];
    UIColor *grey40 = [UIColor colorWithWhite:0.4 alpha:1.0];
    
    // Shadow Declarations
    CGColorRef innerShadow = grey40.CGColor;
    CGSize innerShadowOffset = CGSizeMake(0, 2);
    CGFloat innerShadowBlurRadius = 2;
    CGColorRef outerShadow = white10.CGColor;
    CGSize outerShadowOffset = CGSizeMake(0, 1);
    CGFloat outerShadowBlurRadius = 0;
    
    // Rectangle Drawing
    UIBezierPath *rectanglePath = [UIBezierPath bezierPathWithRect: CGRectIntegral(rect)];
    CGContextSaveGState(context);
    CGContextSetShadowWithColor(context,
                                outerShadowOffset,
                                outerShadowBlurRadius,
                                outerShadow);
    [[UIColor whiteColor] setFill];
    [rectanglePath fill];
    
    // Rectangle Inner Shadow
    CGRect rectangleBorderRect = CGRectInset([rectanglePath bounds],
                                             -innerShadowBlurRadius,
                                             -innerShadowBlurRadius);
    rectangleBorderRect = CGRectOffset(rectangleBorderRect,
                                       -innerShadowOffset.width,
                                       -innerShadowOffset.height);
    rectangleBorderRect = CGRectInset(CGRectUnion(rectangleBorderRect, [rectanglePath bounds]),
                                      -1,
                                      -1);
    
    UIBezierPath* rectangleNegativePath = [UIBezierPath bezierPathWithRect: rectangleBorderRect];
    [rectangleNegativePath appendPath: rectanglePath];
    rectangleNegativePath.usesEvenOddFillRule = YES;
    
    CGContextSaveGState(context);
    {
        CGFloat xOffset = innerShadowOffset.width + round(rectangleBorderRect.size.width);
        CGFloat yOffset = innerShadowOffset.height;
        CGContextSetShadowWithColor(context,
                                    CGSizeMake(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset)),
                                    innerShadowBlurRadius,
                                    innerShadow);
        
        [rectanglePath addClip];
        CGAffineTransform transform = CGAffineTransformMakeTranslation(-round(rectangleBorderRect.size.width), 0);
        [rectangleNegativePath applyTransform: transform];
        [[UIColor grayColor] setFill];
        [rectangleNegativePath fill];
    }
    
    CGContextRestoreGState(context);
    CGContextRestoreGState(context);
    
    [[UIColor blackColor] setStroke];
    rectanglePath.lineWidth = 1;
    [rectanglePath stroke];
    
    CGContextRestoreGState(context);
}



- (void)drawRect:(CGRect)rect {
    [self drawDialogBackgroundInRect:rect];
    [self drawTitleInRect:layout.titleRect isSubtitle:NO];
    [self drawTitleInRect:layout.subtitleRect isSubtitle:YES];
    
#if LogSelfFrameSwitcher
    NSLog(@"\nself.frame: %f %f %f %f\n",self.frame.origin.x,self.frame.origin.y,self.frame.size.width,self.frame.size.height);
#endif
    
}


#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // Cylce through text fields
    NSUInteger index = [self.textFields indexOfObject:textField];
    NSUInteger count = self.textFields.count;
    
    if (index < (count - 1)) {
        UITextField *nextField = [self.textFields objectAtIndex:index + 1];
        [nextField becomeFirstResponder];
    } else {
        [textField resignFirstResponder];
    }
    
    return YES;
}

@end


@implementation XDDialogTextField
XDDialogSynthesize(dialog);

- (CGRect)textRectForBounds:(CGRect)bounds {
    return CGRectInset(bounds, 4.0, 4.0);
}

- (CGRect)editingRectForBounds:(CGRect)bounds {
    return [self textRectForBounds:bounds];
}

- (void)drawRect:(CGRect)rect {
    [self.dialog drawTextFieldInRect:rect];
}

@end

@implementation XDDialogWindowOverlay

- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGRect currentBounds = rect;
    
    CGGradientRef backgroundGradient;
    size_t num_locations = 2;
    
    CGFloat locations[2] = { 0.0, 1.0 };
    CGFloat components[8] = { 0.0, 0.0, 0.0, 0.20,   // Start color
        0.0, 0.0, 0.0, 0.70 }; // End color
    CGColorSpaceRef rgbColorspace = CGColorSpaceCreateDeviceRGB();
    
    backgroundGradient = CGGradientCreateWithColorComponents (rgbColorspace,
                                                              components,
                                                              locations,
                                                              num_locations);
    
    CGPoint centerPoint = CGPointMake(CGRectGetMidX(currentBounds),
                                      CGRectGetMidY(currentBounds));
    
    CGContextDrawRadialGradient (context,
                                 backgroundGradient,
                                 centerPoint,
                                 10.0,
                                 centerPoint,
                                 CGRectGetMidY(rect),
                                 kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    
    CGGradientRelease(backgroundGradient);
    CGColorSpaceRelease(rgbColorspace);
}

@end

