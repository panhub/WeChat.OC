//
//  MNAssetPicker.m
//  MNKit
//
//  Created by Vincent on 2019/8/30.
//  Copyright © 2019 Vincent. All rights reserved.
//

#import "MNAssetPicker.h"
#if __has_include(<Photos/Photos.h>)
#import "MNAsset.h"
#import "MNAssetPickController.h"
#import "MNImageCropController.h"
#import "MNCameraController.h"
#import "MNVideoTailorController.h"

@interface MNAssetPicker ()<MNCameraControllerDelegate, MNAssetPickerDelegate,  MNImageCropDelegate, MNVideoTailorDelegate, UIViewControllerTransitioningDelegate>
@property (nonatomic, getter=isAnimated) BOOL animated;
@property (nonatomic, copy) void (^cancelHandler) (MNAssetPicker *picker);
@property (nonatomic, copy) void (^pickingHandler) (MNAssetPicker *picker, NSArray <MNAsset *>*assets);
@end

@implementation MNAssetPicker
@synthesize configuration = _configuration;

- (instancetype)init {
    return [self initWithType:MNAssetPickerTypeNormal];
}

- (instancetype)initWithType:(MNAssetPickerType)type {
    if (type == MNAssetPickerTypeNormal) return [self initWithRootViewController:[MNAssetPickController new]];
    MNCameraController *vc = [MNCameraController new];
    vc.delegate = self;
    vc.configuration = [MNAssetPickConfiguration new];
    return [self initWithRootViewController:vc];
}

- (instancetype)initWithRootViewController:(UIViewController *)vc {
    if (self == [super initWithRootViewController:vc]) {
        self.transitioningDelegate = self;
        self.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    return self;
}

+ (instancetype)picker {
    return [[self alloc] initWithType:MNAssetPickerTypeNormal];
}

+ (instancetype)camera {
    return [[self alloc] initWithType:MNAssetPickerTypeCapturing];
}

+ (instancetype)imagePicker {
    MNAssetPicker *picker = [self picker];
    picker.configuration.maxPickingCount = 1;
    picker.configuration.allowsPickingVideo = NO;
    picker.configuration.allowsPickingGif = YES;
    picker.configuration.allowsPickingPhoto = YES;
    picker.configuration.allowsPickingLivePhoto = YES;
    picker.configuration.requestGifUseingPhotoPolicy = YES;
    picker.configuration.requestLivePhotoUseingPhotoPolicy = YES;
    picker.configuration.allowsEditing = NO;
    picker.configuration.allowsPreviewing = NO;
    picker.configuration.allowsOptimizeExporting = YES;
    return picker;
}

+ (instancetype)videoPicker {
    MNAssetPicker *picker = [self picker];
    picker.configuration.maxPickingCount = 1;
    picker.configuration.allowsPickingVideo = YES;
    picker.configuration.allowsPickingGif = NO;
    picker.configuration.allowsPickingPhoto = NO;
    picker.configuration.allowsPickingLivePhoto = NO;
    picker.configuration.allowsEditing = NO;
    picker.configuration.allowsPreviewing = NO;
    return picker;
}

- (void)presentWithPickingHandler:(void(^)(MNAssetPicker *picker, NSArray <MNAsset *>*assets))pickingHandler cancelHandler:(void(^)(MNAssetPicker *picker))cancelHandler {
    [self presentInController:nil animated:YES pickingHandler:pickingHandler cancelHandler:cancelHandler];
}

- (void)presentInController:(UIViewController *)parentController
                   animated:(BOOL)animated
             pickingHandler:(void(^)(MNAssetPicker *picker, NSArray <MNAsset *>*assets))pickingHandler
              cancelHandler:(void(^)(MNAssetPicker *picker))cancelHandler {
    if (!parentController) parentController = self.forwardViewController;
    if (!parentController) return;
    self.configuration.delegate = self;
    self.animated = animated;
    self.cancelHandler = cancelHandler;
    self.pickingHandler = pickingHandler;
    [parentController presentViewController:self animated:(animated && UIApplication.sharedApplication.applicationState == UIApplicationStateActive) completion:nil];
}

#pragma mark - MNCameraControllerDelegate
- (void)cameraControllerDidCancel:(MNCameraController *)cameraController {
    if ([self.configuration.delegate respondsToSelector:@selector(assetPickerDidCancel:)]) {
        [self.configuration.delegate assetPickerDidCancel:self];
    } else if (self.presentingViewController) {
        [self dismissViewControllerAnimated:UIApplication.sharedApplication.applicationState == UIApplicationStateActive completion:nil];
    }
}

- (void)cameraController:(MNCameraController *)cameraController didFinishWithContents:(id)content {
    if ([content isKindOfClass:UIImage.class] && self.configuration.isAllowsEditing) {
        // 图片裁剪
        MNImageCropController *vc = [[MNImageCropController alloc] initWithImage:content delegate:self];
        vc.cropScale = self.configuration.cropScale;
        [cameraController.navigationController pushViewController:vc animated:YES];
        return;
    } else if ([content isKindOfClass:NSString.class] && self.configuration.isAllowsEditing && floor([MNAssetExporter exportDurationWithMediaAtPath:content]) > self.configuration.maxExportDuration) {
        // 视频裁剪
        MNVideoTailorController *vc = [[MNVideoTailorController alloc] initWithVideoPath:content];
        vc.delegate = self;
        vc.deleteVideoWhenFinish = YES;
        vc.outputPath = self.configuration.exportURL.path;
        vc.minTailorDuration = self.configuration.minExportDuration;
        vc.maxTailorDuration = self.configuration.maxExportDuration;
        vc.allowsResizeSize = self.configuration.isAllowsResizeVideoSize;
        [cameraController.navigationController pushViewController:vc animated:YES];
        return;
    }
    if ([self.configuration.delegate respondsToSelector:@selector(assetPicker:didFinishPickingAssets:)]) {
        if ([content isKindOfClass:UIImage.class] && !self.configuration.isOriginalExporting && self.configuration.isAllowsOptimizeExporting) {
            content = ((UIImage *)content).compressImage;
        }
        MNAsset *asset = [MNAsset assetWithContent:content configuration:self.configuration];
        if (!asset) {
            [cameraController.view showInfoDialog:@"操作失败"];
            return;
        }
        [self.configuration.delegate assetPicker:self didFinishPickingAssets:@[asset]];
    }
}

#pragma mark - MNImageCropDelegate
- (void)imageCropControllerDidCancel:(MNImageCropController *)controller {
    [controller.navigationController popViewControllerAnimated:YES];
}

- (void)imageCropController:(MNImageCropController *)controller didCroppingImage:(UIImage *)image {
    if ([self.configuration.delegate respondsToSelector:@selector(assetPicker:didFinishPickingAssets:)]) {
        if (!self.configuration.isOriginalExporting && self.configuration.isAllowsOptimizeExporting) image = image.compressImage;
        MNAsset *asset = [MNAsset assetWithContent:image configuration:self.configuration];
        if (!asset) {
            [controller.view showInfoDialog:@"图片裁剪失败"];
            return;
        }
        [self.configuration.delegate assetPicker:self didFinishPickingAssets:@[asset]];
    }
}

#pragma mark - MNVideoTailorDelegate
- (void)videoTailorControllerDidCancel:(MNVideoTailorController *)tailorController {
    [tailorController.navigationController popViewControllerAnimated:YES];
}

- (void)videoTailorController:(MNVideoTailorController *)tailorController didTailoringVideoAtPath:(NSString *)videoPath {
    if ([self.configuration.delegate respondsToSelector:@selector(assetPicker:didFinishPickingAssets:)]) {
        [self.configuration.delegate assetPicker:self didFinishPickingAssets:@[[MNAsset assetWithContent:videoPath configuration:self.configuration]]];
    }
}

#pragma mark - MNAssetPickerDelegate
- (void)assetPickerDidCancel:(MNAssetPicker *)picker {
    __weak typeof(self) weakself = self;
    [self dismissViewControllerAnimated:(self.isAnimated && UIApplication.sharedApplication.applicationState == UIApplicationStateActive) completion:^{
        __strong typeof(self) self = weakself;
        if (self.cancelHandler) {
            self.cancelHandler(self);
        }
    }];
}

- (void)assetPicker:(MNAssetPicker *)picker didFinishPickingAssets:(NSArray<MNAsset *>*)assets {
    __weak typeof(self) weakself = self;
    [self dismissViewControllerAnimated:(self.isAnimated && UIApplication.sharedApplication.applicationState == UIApplicationStateActive) completion:^{
        __strong typeof(self) self = weakself;
        if (self.pickingHandler) {
            self.pickingHandler(self, (assets && assets.count) ? assets : nil);
        }
    }];
}

#pragma mark - UIViewControllerTransitioningDelegate
- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source {
    MNTransitionAnimator *animator = [MNTransitionAnimator animatorWithType:MNControllerTransitionTypeDefaultModal];
    animator.transitionOperation = MNControllerTransitionOperationPush;
    animator.tabBarTransitionType = MNTabBarTransitionTypeNone;
    return animator;
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed {
    MNTransitionAnimator *animator = [MNTransitionAnimator animatorWithType: MNControllerTransitionTypeDefaultModal];
    animator.transitionOperation = MNControllerTransitionOperationPop;
    animator.tabBarTransitionType = MNTabBarTransitionTypeNone;
    return animator;
}

- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForDismissal:(id<UIViewControllerAnimatedTransitioning>)animator{
    return nil;
}

- (id<UIViewControllerInteractiveTransitioning>)interactionControllerForPresentation:(id<UIViewControllerAnimatedTransitioning>)animator{
    return nil;
}

#pragma mark - Getter
- (MNAssetPickConfiguration *)configuration {
    if (!_configuration && self.viewControllers.count > 0) {
        UIViewController *vc = self.viewControllers.firstObject;
        if ([self.viewControllers.firstObject isKindOfClass:MNAssetPickController.class]) {
            _configuration = ((MNAssetPickController *)vc).configuration;
        } else if ([self.viewControllers.firstObject isKindOfClass:MNCameraController.class]) {
            _configuration = ((MNCameraController *)vc).configuration;
        }
    }
    return _configuration;
}

- (UIViewController *)forwardViewController {
    UIViewController *viewController = [[[[UIApplication sharedApplication] delegate] window] rootViewController];
    do {
        if (viewController.presentedViewController) {
            viewController = viewController.presentedViewController;
        } else if ([viewController isKindOfClass:UINavigationController.class]) {
            UINavigationController *nav = (UINavigationController *)viewController;
            viewController = nav.viewControllers.count ? nav.viewControllers.lastObject : nil;
        } else if ([viewController isKindOfClass:UITabBarController.class]) {
            UITabBarController *tab = (UITabBarController *)viewController;
            viewController = tab.viewControllers.count ? tab.selectedViewController : nil;
        } else {
            break;
        }
    } while (viewController != nil);
    return viewController;
}

#pragma mark - Super
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {}

- (MNTransitionAnimator *)pushTransitionAnimator {
    return [MNTransitionAnimator animatorWithType:MNControllerTransitionTypeDefaultModal];
}

- (MNTransitionAnimator *)popTransitionAnimator {
    return [MNTransitionAnimator animatorWithType:MNControllerTransitionTypeDefaultModal];
}

#pragma mark - dealloc
- (void)dealloc {
    NSLog(@"===dealloc===%@", NSStringFromClass(self.class));
}

@end
#endif
