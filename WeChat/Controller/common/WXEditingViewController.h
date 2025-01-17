//
//  WXEditingViewController.h
//  WeChat
//
//  Created by Vincent on 2019/5/23.
//  Copyright © 2019 Vincent. All rights reserved.
//  编辑信息控制器

#import "MNExtendViewController.h"

@interface WXEditingViewController : MNExtendViewController
/**
 行数
 */
@property (nonatomic) NSUInteger numberOfLines;
/**
 最大字数
 */
@property (nonatomic) NSUInteger numberOfWords;
/**
 最小字数
 */
@property (nonatomic) NSUInteger minOfWordInput;
/**
 键盘
 */
@property (nonatomic) UIKeyboardType keyboardType;
/**
 预设值
 */
@property (nonatomic, copy) NSString *text;
/**
 字体
 */
@property (nonatomic, strong) UIFont *font;
/**
 占位符
 */
@property (nonatomic, copy) NSString *placeholder;
/**
 屏蔽的字符
 */
@property (nonatomic, copy) NSArray <NSString *>*shieldCharacters;
/**
 确定事件回调
 */
@property (nonatomic, copy) void (^completionHandler) (NSString *result, WXEditingViewController *vc);

@end
