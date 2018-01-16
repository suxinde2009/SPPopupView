//
//  SPPopupView.m
//  SPPopupView
//
//  Created by suxinde on 2018/1/15.
//  Copyright © 2018年 com.su. All rights reserved.
//

#import "SPPopupView.h"
#import <Masonry/Masonry.h>

const float kSPDialogPopScale = 0.35f;
const float kDefaultPopupAnimationDuration = 0.15f;

@interface SPPopupView ()

@property (nonatomic, copy) void (^willShow)(void);
@property (nonatomic, copy) void (^didShow)(void);
@property (nonatomic, copy) void (^willDismiss)(void);
@property (nonatomic, copy) void (^didDismiss)(void);

//@property (nonatomic, copy) void (^showAnimation)(void);
//@property (nonatomic, copy) void (^dismissAnimation)(void);

@property (nonatomic, assign) SPPopupViewPosition position;
@property (nonatomic, assign) CGSize contentSize;

@property (nonatomic, strong) UIView *backgroundView;
@property (nonatomic, strong) UIView *contentView;

@end

@implementation SPPopupView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self privateInit];
    }
    return self;
}

+ (instancetype)showInView:(UIView *)view
               contentView:(UIView *)contentView
               contentSize:(CGSize)contentSize
                  position:(SPPopupViewPosition)position
                  willShow:(void (^)(void))willShow
                   didShow:(void (^)(void))didShow
               willDismiss:(void (^)(void))willDismiss
                didDismiss:(void (^)(void))didDismiss
                  animated:(BOOL)animated {
    UIView *parentView = view ? : [[UIApplication sharedApplication].windows firstObject];
    SPPopupView *popupView = [[SPPopupView alloc] initWithFrame:view.bounds];
    popupView.willShow = willShow;
    popupView.didShow = didShow;
    popupView.willDismiss = willDismiss;
    popupView.didDismiss = didDismiss;
    popupView.position = position;
    popupView.contentView = contentView;
//    popupView.showAnimation = showAnimation;
//    popupView.dismissAnimation = dismissAnimation;
    popupView.contentSize = contentSize;
    [popupView showInView:parentView animated:animated];
    return popupView;
}

- (void)dismiss {
    [self dismissWithAnimated:YES];
}

+ (void)dissmissAll {
    UIWindow *keyWindow = [[UIApplication sharedApplication] windows][0];
    [keyWindow.subviews enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:[SPPopupView class]]) {
            SPPopupView *view = (SPPopupView *)obj;
            [view dismissWithAnimated:NO];
        }
    }];
    
    [[[keyWindow.rootViewController view] subviews] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([obj isKindOfClass:[SPPopupView class]]) {
            SPPopupView *view = (SPPopupView *)obj;
            [view dismissWithAnimated:NO];
        }
    }];
}

- (void)dismissWithAnimated:(BOOL)animated {
    
    self.willDismiss ? self.willDismiss() : NULL;
    
    float animationDuration = (animated ? kDefaultPopupAnimationDuration : 0.0f);
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:animationDuration delay:0 options:UIViewAnimationOptionLayoutSubviews animations:^{
        __strong __typeof(self) strongSelf = weakSelf;
        strongSelf.backgroundView.alpha = 0.0;
        strongSelf.contentView.transform = CGAffineTransformMakeScale(kSPDialogPopScale, kSPDialogPopScale);
    } completion:^(BOOL finished) {
        __strong __typeof(self) strongSelf = weakSelf;
        [strongSelf.contentView removeFromSuperview];
        strongSelf.contentView.transform = CGAffineTransformIdentity;
        strongSelf.contentView = nil;
        
        strongSelf.backgroundView.hidden = YES;
        [strongSelf.backgroundView removeFromSuperview];
        strongSelf.backgroundView = nil;
        
        [strongSelf removeFromSuperview];
        
        strongSelf.didDismiss ? strongSelf.didDismiss() : NULL;
    }];
}


#pragma mark - Private

- (void)privateInit {
    self.backgroundColor = [UIColor clearColor];
    self.backgroundView = [[UIView alloc] initWithFrame:CGRectZero];
    [self addSubview:self.backgroundView];
    [self.backgroundView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.mas_equalTo(UIEdgeInsetsZero);
    }];
    self.backgroundView.backgroundColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.5f];
    self.backgroundView.alpha = 0.0f;
    
}

- (void)showInView:(UIView *)view
          animated:(BOOL)animated {
    // 弹窗即将弹出回调
    self.willShow ? self.willShow() : NULL;
    
    [view addSubview:self];
    self.contentView.alpha = 0.0f;
    [self addSubview:self.contentView];
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.mas_equalTo(self.mas_centerX);
        make.centerY.mas_equalTo(self.mas_centerY);
        make.width.mas_equalTo(@(self.contentSize.width));
        make.height.mas_equalTo(@(self.contentSize.height));
    }];
    
    
    // Scale down ourselves for pop animation
    self.contentView.transform = CGAffineTransformMakeScale(kSPDialogPopScale, kSPDialogPopScale);
    float animationDuration = (animated ? kDefaultPopupAnimationDuration : 0.0f);
    
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:animationDuration delay:0 options:UIViewAnimationOptionLayoutSubviews animations:^{
        __strong __typeof(self) strongSelf = weakSelf;
        strongSelf.backgroundView.alpha = 1.0f;
        strongSelf.contentView.alpha = 1.0f;
        strongSelf.contentView.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
        __strong __typeof(self) strongSelf = weakSelf;
        strongSelf.didShow ? strongSelf.didShow() : NULL;
    }];
}


@end
