//
//  MNCameraController.h
//  MNKit
//
//  Created by Vincent on 2019/6/12.
//  Copyright © 2019 Vincent. All rights reserved.
//  资源选择<视频录制/拍照>

#import "MNBaseViewController.h"
@class MNCameraController, MNAssetPickConfiguration;

@protocol MNCameraControllerDelegate <NSObject>
@optional
/**录像控制器取消*/
- (void)cameraControllerDidCancel:(MNCameraController *)cameraController;
/**录像控制器结束拍照*/
- (void)cameraController:(MNCameraController *)cameraController didFinishWithContents:(id)contents;
@end

@interface MNCameraController : MNBaseViewController
/**视频保存路径*/
@property (nonatomic, copy) NSURL *videoURL;
/**事件代理*/
@property (nonatomic, weak) id<MNCameraControllerDelegate> delegate;
/**资源选择配置信息*/
@property (nonatomic, strong) MNAssetPickConfiguration *configuration;

@end
