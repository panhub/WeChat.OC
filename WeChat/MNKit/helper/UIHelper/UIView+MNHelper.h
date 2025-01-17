//
//  UIView+MNHelper.h
//  MNKit
//
//  Created by Vincent on 2017/11/30.
//  Copyright © 2017年 小斯. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIView (MNHelper)
/**
 *调整按钮触发区域
 */
@property (nonatomic) UIEdgeInsets touchInset;
/**
 *设置背景图片
 */
@property (nonatomic, nullable) UIImage *backgroundImage;
/**
 设置锚点<不改变相对位置>
 */
@property (nonatomic) CGPoint anchorsite;

/**相反遮罩图*/
@property (nonatomic, nullable) UIView *subtractMaskView;

/**视图快照 - 实时*/
- (UIView *_Nullable)snapshotView;
- (UIImageView *_Nullable)snapshotImageView;

/**部分视图快照 - 实时*/
- (UIView *_Nullable)snapshotViewWithRect:(CGRect)rect;
- (UIImageView *_Nullable)snapshotImageViewWithRect:(CGRect)rect;

/**视图快照Image*/
- (UIImage *_Nullable)snapshotImage;
- (UIImage *_Nullable)snapshotImageAfterScreenUpdates:(BOOL)afterUpdates;

/**判断视图是否在父视图上*/
- (BOOL)containsView:(UIView *)subview;

/**删除所有子视图*/
- (void)removeAllSubviews;

/**设置圆角*/
UIKIT_EXTERN void UIViewSetCornerRadius (UIView *view, CGFloat radius);

/**设置边框圆角*/
UIKIT_EXTERN void UIViewSetBorderRadius (UIView *view, CGFloat radius, CGFloat width, UIColor *color);

/**
 宫格布局
 @param frame 起始位置
 @param offset 左右间隔
 @param count 数量
 @param rows 列数
 @param handler 布局回调
 */
+ (void)gridLayoutWithInitial:(CGRect)frame
                      offset:(UIOffset)offset
                       count:(NSUInteger)count
                        rows:(NSUInteger)rows
                     handler:(void(^_Nullable)(CGRect rect, NSUInteger idx, BOOL *stop))handler;

/**
 宫格布局
 @param frame 初始位置
 @param offset 左右偏移
 @param count 数量
 @param handler 布局回调
 */
- (void)gridLayoutWithInitial:(CGRect)frame
                             offset:(UIOffset)offset
                              count:(NSUInteger)count
                            handler:(void(^_Nullable)(CGRect rect, NSUInteger idx, BOOL *stop))handler;

/**
 备份控件
 @return 复制后的视图
 */
- (id)viewCopy;

@end



@interface UIView (MNEffect)

/**
 获取毛玻璃视图
 @param rect 大小, 位置
 @param style 类型
 @return 毛玻璃
 */
UIKIT_EXTERN UIVisualEffectView *UIBlurEffectCreate (CGRect rect, UIBlurEffectStyle style);

/**
 获取自身大小的毛玻璃
 @param style 毛玻璃风格
 @return 毛玻璃视图
 */
- (UIVisualEffectView *)blurEffectWithStyle:(UIBlurEffectStyle)style;

/**
 添加毛玻璃效果
 @param view 需要添加的view
 @param style 毛玻璃风格
 */
UIKIT_EXTERN void UIViewAddBlurEffect (UIView *view, UIBlurEffectStyle style);

/**
 重力视觉差效果
 @param horizontal 横向差值
 @param vertical 纵向差值
 @return 视觉差效果实例
 */
UIKIT_EXTERN UIMotionEffect * UIMotionEffectCreate (CGFloat horizontal, CGFloat vertical);

/**
 添加重力视觉差效果
 @param view 需要添加的view
 @param horizontal 横向差值
 @param vertical 纵向差值
 */
UIKIT_EXTERN void UIViewAddMotionEffect (UIView *view, CGFloat horizontal, CGFloat vertical);

@end

NS_ASSUME_NONNULL_END
