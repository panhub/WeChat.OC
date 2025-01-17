//
//  MNNavigationController.m
//  MNKit
//
//  Created by Vincent on 2017/11/9.
//  Copyright © 2017年 小斯. All rights reserved.
//

#import "MNNavigationController.h"
#import "UIView+MNLayout.h"
#import "UIViewController+MNInterface.h"
#import "MNBaseViewController.h"
#import "MNTransitionAnimator.h"
#import "MNConfiguration.h"
#import "UIViewController+MNHelper.h"
#import "MNTransitionAnimator.h"

@interface MNNavigationController ()
/**
 交互转场驱动器
 命名为interactiveTransition会崩溃, 应该是和内部变量冲突导致
 */
@property (nonatomic, strong) UIPercentDrivenInteractiveTransition *interactiveTransitionDriver;
@end

@implementation MNNavigationController
- (instancetype)initWithRootViewController:(UIViewController *)rootViewController {
    if (self = [super initWithRootViewController:rootViewController]) {
        [self layoutExtendAdjustEdges];
        self.delegate = self;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    /*
     要使用的协议
     UIViewControllerInteractiveTransitioning 交互协议，主要在右滑返回时用到
     UIViewControllerAnimatedTransitioning 动画协议，含有动画时间及转场上下文两个必须实现协议
     UIViewControllerContextTransitioning 动画协议里边的协议之一，动画实现的主要部分
     UIPrecentDrivenInteractiveTransition 用在交互协议，百分比控制当前动画进度。
     */
    [self.navigationBar setHidden:YES];
    /**先关闭系统手势创建一个滑动手势作用于系统手势的view上*/
    UIGestureRecognizer *recognizer = self.interactivePopGestureRecognizer;
    UIView *recognizerView = recognizer.view;
    [recognizerView removeGestureRecognizer:recognizer];
    /**创建一个滑动手势*/
    UIScreenEdgePanGestureRecognizer *gestureRecognizer = [UIScreenEdgePanGestureRecognizer new];
    gestureRecognizer.edges = UIRectEdgeLeft;
    gestureRecognizer.delegate = self;
    gestureRecognizer.enabled = YES;
    gestureRecognizer.maximumNumberOfTouches = 1;
    [gestureRecognizer addTarget:self action:@selector(handInteractiveTransition:)];
    [recognizerView addGestureRecognizer:gestureRecognizer];
    self.interactiveGestureRecognizer = gestureRecognizer;
    self.interactiveTransitionEnabled = YES;
}

#pragma mark - 交互转场控制
- (void)handInteractiveTransition:(UIScreenEdgePanGestureRecognizer *)recognizer {
    CGFloat x = [recognizer translationInView:recognizer.view].x;
    CGFloat progress = x/recognizer.view.bounds.size.width;
    progress = MIN(1.f, MAX(.01f, progress));
    UIGestureRecognizerState state = recognizer.state;
    if (state == UIGestureRecognizerStateBegan) {
        [self.viewControllers.lastObject beganInteractivePopTransition];
        _interactiveTransitionDriver = [[UIPercentDrivenInteractiveTransition alloc]init];
        [self popViewControllerAnimated:YES];
    } else if (state == UIGestureRecognizerStateChanged) {
        [_interactiveTransitionDriver updateInteractiveTransition:progress];
    } else if (state == UIGestureRecognizerStateEnded || state == UIGestureRecognizerStateCancelled) {
        if (progress >= .3f) {
            [self.viewControllers.lastObject endInteractivePopTransition];
            [_interactiveTransitionDriver finishInteractiveTransition];
        } else {
            [self.viewControllers.lastObject cancelInteractivePopTransition];
            [_interactiveTransitionDriver cancelInteractiveTransition];
        }
        _interactiveTransitionDriver = nil;
    }
}

#pragma mark - UIGestureRecognizerDelegate
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (self.viewControllers.count <= 1 || [[self valueForKey:@"_isTransitioning"] boolValue] || !self.interactiveTransitionEnabled) return NO;
    return [self.viewControllers.lastObject shouldInteractivePopTransition];
}

#pragma mark - UINavigationControllerDelegate (verson >=7.0 )
//交互动画, 即右滑返回时用到
- (nullable id <UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController
                                   interactionControllerForAnimationController:(id <UIViewControllerAnimatedTransitioning>) animationController {
    return _interactiveTransitionDriver;
}

- (nullable id <UIViewControllerAnimatedTransitioning>)navigationController:(MNNavigationController *)navigationController
                                            animationControllerForOperation:(UINavigationControllerOperation)operation
                                                         fromViewController:(UIViewController *)fromVC
                                                           toViewController:(UIViewController *)toVC {
    if (operation == UINavigationControllerOperationNone) return nil;
    MNControllerTransitionOperation _operation = (operation == UINavigationControllerOperationPush ? MNControllerTransitionOperationPush : MNControllerTransitionOperationPop);
    return [self navigationControllerTransitionForOperation:_operation fromViewController:fromVC toViewController:toVC];
}

#pragma mark - 屏幕旋转相关
- (BOOL)shouldAutorotate {
    if (self.viewControllers.count > 0) return self.viewControllers.lastObject.shouldAutorotate;
    return NO;
}
- (UIInterfaceOrientationMask)navigationControllerSupportedInterfaceOrientations:(UINavigationController *)navigationController {
    if (navigationController.viewControllers.count > 0) return navigationController.viewControllers.lastObject.supportedInterfaceOrientations;
    return UIInterfaceOrientationMaskPortrait;
}
- (UIInterfaceOrientation)navigationControllerPreferredInterfaceOrientationForPresentation:(UINavigationController *)navigationController {
    return UIInterfaceOrientationPortrait;
}

#pragma mark - 转场控制
- (MNTransitionAnimator *_Nullable)navigationControllerTransitionForOperation:(MNControllerTransitionOperation)operation fromViewController:(__kindof UIViewController *)fromVC toViewController:(__kindof UIViewController *)toVC {
    MNTransitionAnimator *animator = operation == MNControllerTransitionOperationPush ? [toVC pushTransitionAnimator] : [fromVC popTransitionAnimator];
    if (!animator) animator = [MNTransitionAnimator animatorWithType:MNControllerTransitionTypeSlide];
    if (fromVC.tabBarController) animator.tabView = fromVC.tabBarController.tabView;
    animator.interactive = (_interactiveTransitionDriver != nil);
    animator.transitionOperation = operation;
    animator.tabBarTransitionType = MNTabBarTransitionTypeAdsorb;
    return animator;
}

#pragma mark - Getter
- (BOOL)isInteractiveTransition {
    return _interactiveTransitionDriver != nil;
}

@end
