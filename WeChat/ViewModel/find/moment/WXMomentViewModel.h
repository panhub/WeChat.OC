//
//  WXMomentViewModel.h
//  WeChat
//
//  Created by Vincent on 2019/4/30.
//  Copyright © 2019 Vincent. All rights reserved.
//  单条朋友圈视图模型

#import <Foundation/Foundation.h>
#import "WXExtendViewModel.h"
#import "WXMomentEventViewModel.h"
#import "WXMoment.h"
#import "WXLocation.h"
@class WXUser, WXMomentReplyViewModel, WXComment, WXMomentCommentViewModel;

@interface WXMomentViewModel : NSObject
/**
 记录数据模型
 */
@property (nonatomic, readonly, strong) WXMoment *moment;
/**
 点赞/评论模型
 */
@property (nonatomic, readonly, strong) NSMutableArray <WXMomentEventViewModel *>*dataSource;
/**
 头像
 */
@property (nonatomic, strong) WXExtendViewModel *avatarViewModel;
/**
 昵称
 */
@property (nonatomic, strong) WXExtendViewModel *nicknameViewModel;
/**
 正文
 */
@property (nonatomic, strong) WXExtendViewModel *contentViewModel;
/**
 全文/收起
 */
@property (nonatomic, strong) WXExtendViewModel *expandViewModel;
/**
 位置
 */
@property (nonatomic, strong) WXExtendViewModel *locationViewModel;
/**
 网页分享
 */
@property (nonatomic) CGRect webViewFrame;
/**
 图片
 */
@property (nonatomic) CGRect pictureViewFrame;
/**
 更多
 */
@property (nonatomic) CGRect moreButtonFrame;
/**
 时间
 */
@property (nonatomic, strong) WXExtendViewModel *timeViewModel;
/**
 来源
 */
@property (nonatomic, strong) WXExtendViewModel *sourceViewModel;
/**
 隐私图标
 */
@property (nonatomic, strong) WXExtendViewModel *privacyViewModel;
/**
 删除
 */
@property (nonatomic, strong) WXExtendViewModel *deleteViewModel;
/**
 箭头
 */
@property (nonatomic) CGRect arrowViewFrame;
/**
 标记是否展开
 */
@property (nonatomic, getter=isExpand) BOOL expand;
/**
 视图高度
 */
@property (nonatomic) CGFloat height;

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
 点赞刷新回调<便于更新提醒信息>
 */
@property (nonatomic, copy) void (^didUpdateLikesEventHandler) (WXMomentViewModel *vm);
/**
 已插入 评论/回复 回调<便于更新提醒信息>
 */
@property (nonatomic, copy) void (^didInsertCommentEventHandler) (WXComment*comment);
/**
 已插删除 评论/回复 回调<便于更新提醒信息>
 */
@property (nonatomic, copy) void (^didDeleteCommentEventHandler) (WXComment*comment);

/**
 实例化方式
 @param moment 朋友圈数据模型
 @return 朋友圈视图模型
 */
- (instancetype)initWithMoment:(WXMoment *)moment;

/**
 评论或回复
 @param replyModel 回复模型
 */
- (void)replyMomentWithModel:(WXMomentReplyViewModel *)replyModel;

/**
 删除评论
 @param viewModel 评论模型
 */
- (void)deleteComment:(WXMomentCommentViewModel *)viewModel;

/**
 更新点赞状态
 */
- (void)updateLike;

/**
 更新点赞好友
 @param users 点赞联系人数组
 */
- (void)reloadLikes:(NSArray <WXUser *>*)users;

/**
 全文/收起事件
 */
- (void)expandContentIfNeeded;

@end
