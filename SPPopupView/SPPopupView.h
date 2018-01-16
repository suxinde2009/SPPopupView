//
//  SPPopupView.h
//  SPPopupView
//
//  Created by suxinde on 2018/1/15.
//  Copyright © 2018年 com.su. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SPClosePopupViewProtocol.h"

/**
 弹窗视图位置类型
 
 - SPPopupViewPositionTop: 顶部弹窗
 - SPPopupViewPositionCenter: 居中弹窗
 - SPPopupViewPositionBottom: 底部弹窗
 */
typedef NS_ENUM(NSInteger, SPPopupViewPosition) {
    SPPopupViewPositionTop,
    SPPopupViewPositionCenter,
    SPPopupViewPositionBottom
};

@interface SPPopupView : UIView <SPClosePopupViewProtocol>

+ (instancetype)showInView:(UIView *)view
               contentView:(UIView *)contentView
               contentSize:(CGSize)contentSize
                  position:(SPPopupViewPosition)position
                  willShow:(void (^)(void))willShow
                   didShow:(void (^)(void))didShow
               willDismiss:(void (^)(void))willDismiss
                didDismiss:(void (^)(void))didDismiss
                  animated:(BOOL)animated;

- (void)dismiss;

@end
