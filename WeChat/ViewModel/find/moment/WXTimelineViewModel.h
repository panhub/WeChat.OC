//
//  WXTimelineViewModel.h
//  WeChat
//
//  Created by Vincent on 2019/5/7.
//  Copyright © 2019 Vincent. All rights reserved.
//  朋友圈控制器视图模型

#import <Foundation/Foundation.h>
#import "WXMomentViewModel.h"
#import "WXNotify.h"

@interface WXTimelineViewModel : NSObject
/**
 数据源
 */
@property (nonatomic, readonly, strong) NSMutableArray <WXMomentViewModel *>*dataSource;
/**
 加载数据结束
 */
@property (nonatomic, copy) void (^didLoadFinishHandler) (BOOL hasMore);
/**
 刷新表
 */
@property (nonatomic, copy) void (^reloadTableHandler) (void);
/**
 滑动到顶部
 */
@property (nonatomic, copy) void (^scrollToTopHandler) (BOOL);
/**
 刷新提醒事项<由表头实现>
 */
@property (nonatomic, copy) void (^reloadNotifyHandler) (void);
/**
 刷新表头事项
 */
@property (nonatomic, copy) void (^reloadProfileHandler) (void);
/**
 提醒事项点击事件
 */
@property (nonatomic, copy) void (^notifyViewEventHandler) (void);
/**
 更多视图按钮事件
 */
@property (nonatomic, copy) void (^moreViewEventHandler) (WXMomentViewModel *viewModel, NSUInteger idx);
/**
 删除按钮事件
 */
@property (nonatomic, copy) void (^deleteButtonEventHandler) (WXMomentViewModel *viewModel);
/**
 刷新朋友圈<评论/回复操作触发>
 */
@property (nonatomic, copy) void (^reloadMomentEventHandler) (WXMomentViewModel *viewModel, BOOL animated);
/**
 头像/昵称点击事件
 */
@property (nonatomic, copy) void (^avatarClickedEventHandler) (WXMomentViewModel *viewModel);
/**
 位置信息点击事件
 */
@property (nonatomic, copy) void (^locationViewEventHandler) (WXMomentViewModel *viewModel);
/**
 分享点击事件
 */
@property (nonatomic, copy) void (^webViewEventHandler) (WXMomentViewModel *viewModel);
/**
 配图点击事件
 */
@property (nonatomic, copy) void (^pictureViewEventHandler) (WXMomentViewModel *viewModel, NSArray <MNAsset *>*assets, NSInteger index);

/**
 更新数据
 */
- (void)reload;

/**加载更多数据*/
- (void)loadMore;

/**
 删除朋友圈视图模型, 同时删除数据模型, 数据库内容
 @param viewModel 视图模型
 */
- (void)deleteMomentViewModel:(WXMomentViewModel *)viewModel;

/**
 删除朋友圈数据模型, 同时删除数据库内容
 @param moment 数据模型
 */
- (void)deleteMoment:(WXMoment *)moment;

@end
